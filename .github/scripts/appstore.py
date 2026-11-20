#!/usr/bin/env python3
"""Talks to App Store Connect for the iPhone builds, so no Mac is needed.

Commands:
  create-certificate OUT_DIR   Creates an Apple Distribution certificate and
                               writes it, with its private key, as a .p12.
  prepare-signing P12 PASSWORD OUT_DIR
                               Makes sure the app ID exists with push
                               notifications, and writes a fresh App Store
                               provisioning profile for the certificate.
  distribute BUILD_NUMBER GROUP
                               Waits until Apple has processed the upload,
                               then gives the build to a TestFlight group
                               and asks for beta review when needed.

The App Store Connect API key comes from the environment:
ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY (the contents of the .p8 file).
Needs the PyJWT and cryptography packages.
"""

import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt
from cryptography import x509
from cryptography.hazmat.primitives.serialization import pkcs12

API = "https://api.appstoreconnect.apple.com/v1"
BUNDLE_ID = "rs.kviz.app"
APP_NAME = "Kviz"
PROFILE_NAME = "Kviz App Store (GitHub)"


def log(text):
    print(text, flush=True)


def token():
    now = int(time.time())
    return jwt.encode(
        {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1000,
         "aud": "appstoreconnect-v1"},
        os.environ["ASC_KEY"],
        algorithm="ES256",
        headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"},
    )


def call(method, path, body=None, query=None):
    url = path if path.startswith("http") else API + path
    if query:
        url += "?" + urllib.parse.urlencode(query)
    request = urllib.request.Request(
        url,
        method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization": f"Bearer {token()}",
                 "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as reply:
            raw = reply.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors="replace")
        raise SystemExit(f"App Store Connect answered {error.code} for {method} {path}: {detail}")


def create_certificate(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    key = os.path.join(out_dir, "key.pem")
    csr = subprocess.run(
        ["openssl", "req", "-new", "-newkey", "rsa:2048", "-nodes", "-keyout", key,
         "-subj", "/CN=Kviz/O=Kviz", "-outform", "PEM"],
        check=True, capture_output=True, text=True,
    ).stdout
    created = call("POST", "/certificates", {"data": {
        "type": "certificates",
        "attributes": {"certificateType": "DISTRIBUTION", "csrContent": csr},
    }})
    der = base64.b64decode(created["data"]["attributes"]["certificateContent"])
    cert = os.path.join(out_dir, "cert.der")
    with open(cert, "wb") as handle:
        handle.write(der)
    password = subprocess.run(["openssl", "rand", "-hex", "24"], check=True,
                              capture_output=True, text=True).stdout.strip()
    print(f"::add-mask::{password}", flush=True)
    pem = subprocess.run(["openssl", "x509", "-inform", "DER", "-in", cert],
                         check=True, capture_output=True, text=True).stdout
    p12 = os.path.join(out_dir, "certificate.p12")
    # Older, widely readable encryption so the Mac keychain accepts the file.
    subprocess.run(
        ["openssl", "pkcs12", "-export", "-inkey", key, "-out", p12,
         "-name", "Kviz distribution", "-passout", f"pass:{password}",
         "-certpbe", "PBE-SHA1-3DES", "-keypbe", "PBE-SHA1-3DES", "-macalg", "sha1"],
        input=pem, text=True, check=True,
    )
    os.remove(key)
    os.remove(cert)
    with open(p12, "rb") as handle:
        encoded = base64.b64encode(handle.read()).decode()
    with open(os.path.join(out_dir, "IOS_CERTIFICATE_P12_BASE64.txt"), "w") as handle:
        handle.write(encoded)
    with open(os.path.join(out_dir, "IOS_CERTIFICATE_PASSWORD.txt"), "w") as handle:
        handle.write(password)
    os.remove(p12)
    log(f"Created certificate {created['data']['id']}, valid until "
        f"{created['data']['attributes'].get('expirationDate')}")


def find_bundle_id(identifier=BUNDLE_ID, name=APP_NAME):
    found = call("GET", "/bundleIds", query={"filter[identifier]": identifier})
    for item in found["data"]:
        if item["attributes"]["identifier"] == identifier:
            return item["id"]
    created = call("POST", "/bundleIds", {"data": {"type": "bundleIds", "attributes": {
        "identifier": identifier, "name": name, "platform": "IOS"}}})
    log(f"Registered the app ID {identifier}")
    return created["data"]["id"]


def ensure_capability(bundle_id, kind):
    capabilities = call("GET", f"/bundleIds/{bundle_id}/bundleIdCapabilities")
    kinds = {item["attributes"]["capabilityType"] for item in capabilities["data"]}
    if kind in kinds:
        return
    call("POST", "/bundleIdCapabilities", {"data": {
        "type": "bundleIdCapabilities",
        "attributes": {"capabilityType": kind},
        "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bundle_id}}},
    }})
    log(f"Turned on {kind} for the app ID")


def ensure_push(bundle_id):
    ensure_capability(bundle_id, "PUSH_NOTIFICATIONS")


def make_profile(name, bundle_id, cert_id, out_dir):
    # A fresh profile every time: it always matches the current certificate
    # and capabilities, and it never expires between builds.
    existing = call("GET", "/profiles", query={"filter[name]": name})
    for item in existing["data"]:
        call("DELETE", f"/profiles/{item['id']}")
    profile = call("POST", "/profiles", {"data": {
        "type": "profiles",
        "attributes": {"name": name, "profileType": "IOS_APP_STORE"},
        "relationships": {
            "bundleId": {"data": {"type": "bundleIds", "id": bundle_id}},
            "certificates": {"data": [{"type": "certificates", "id": cert_id}]},
        },
    }})["data"]["attributes"]
    with open(os.path.join(out_dir, f"{profile['uuid']}.mobileprovision"), "wb") as handle:
        handle.write(base64.b64decode(profile["profileContent"]))


def prepare_signing(p12_path, password, out_dir):
    with open(p12_path, "rb") as handle:
        _, cert, _ = pkcs12.load_key_and_certificates(handle.read(), password.encode())
    serial = format(cert.serial_number, "X")
    team = cert.subject.get_attributes_for_oid(x509.NameOID.ORGANIZATIONAL_UNIT_NAME)[0].value
    certificates = call("GET", "/certificates", query={"limit": 200})
    cert_id = next((item["id"] for item in certificates["data"]
                    if item["attributes"]["serialNumber"].upper().lstrip("0") == serial.lstrip("0")),
                   None)
    if not cert_id:
        raise SystemExit("Apple no longer knows the certificate in the secrets. "
                         "Run the 'Create iPhone certificate' workflow again.")
    # Push (FCM) comes later; then call ensure_push(bundle_id) here.
    bundle_id = find_bundle_id()
    # Invite links https://kviz.dartchat.trade/i/CODE open the app.
    ensure_capability(bundle_id, "ASSOCIATED_DOMAINS")
    os.makedirs(out_dir, exist_ok=True)
    make_profile(PROFILE_NAME, bundle_id, cert_id, out_dir)
    with open(os.environ.get("GITHUB_OUTPUT", "/dev/stdout"), "a") as out:
        out.write(f"team={team}\nprofile={PROFILE_NAME}\n")
    log(f"Profile ready for team {team}")


def distribute(build_number, group_name):
    apps = call("GET", "/apps", query={"filter[bundleId]": BUNDLE_ID})
    if not apps["data"]:
        raise SystemExit(f"No app with bundle ID {BUNDLE_ID} in App Store Connect.")
    app_id = apps["data"][0]["id"]
    build = None
    for _ in range(90):  # Apple usually needs 5 to 30 minutes.
        found = call("GET", "/builds", query={
            "filter[app]": app_id, "filter[version]": str(build_number), "limit": 1})
        if found["data"]:
            build = found["data"][0]
            state = build["attributes"]["processingState"]
            if state == "VALID":
                break
            if state in ("FAILED", "INVALID"):
                raise SystemExit(f"Apple could not process build {build_number}: {state}")
        time.sleep(30)
    else:
        raise SystemExit(f"Build {build_number} was not processed in time.")
    if build["attributes"].get("usesNonExemptEncryption") is None:
        log("Build waits for the encryption answer in App Store Connect "
            "(ITSAppUsesNonExemptEncryption is not set in Info.plist).")
        return
    groups = call("GET", "/betaGroups", query={"filter[app]": app_id, "filter[name]": group_name})
    if not groups["data"]:
        log(f"No TestFlight group named '{group_name}' yet. The build is uploaded, "
            "but nobody was given it.")
        return
    group = groups["data"][0]
    call("POST", f"/betaGroups/{group['id']}/relationships/builds",
         {"data": [{"type": "builds", "id": build["id"]}]})
    log(f"Build {build_number} given to the TestFlight group '{group_name}'")
    if group["attributes"].get("isInternalGroup"):
        return
    detail = call("GET", f"/builds/{build['id']}/buildBetaDetail")["data"]["attributes"]
    if detail.get("externalBuildState") in ("READY_FOR_BETA_SUBMISSION", None):
        call("POST", "/betaAppReviewSubmissions", {"data": {
            "type": "betaAppReviewSubmissions",
            "relationships": {"build": {"data": {"type": "builds", "id": build["id"]}}},
        }})
        log("Sent the build to Apple's beta review")


def main():
    command, *args = sys.argv[1:] or ["help"]
    if command == "create-certificate" and len(args) == 1:
        create_certificate(*args)
    elif command == "prepare-signing" and len(args) == 3:
        prepare_signing(*args)
    elif command == "distribute" and len(args) == 2:
        distribute(*args)
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
