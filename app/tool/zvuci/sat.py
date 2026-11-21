"""Pravi zvuke otkucavanja sata (assets/zvuci/sat_*.wav).

Pokretanje: python3 tool/zvuci/sat.py
sat_tak.wav  - dublji "tak" (naizmenično sa tik), mirni deo pitanja
sat_0.wav    - običan "tik"
sat_1..10    - sve viši i glasniji tik za poslednjih 10 sekundi
"""
import math, os, random, struct, wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'zvuci')


def otkucaj(frek, jacina, trajanje=0.045, seme=1):
    rnd = random.Random(seme)
    n = int(SR * trajanje)
    uzorci = []
    prethodni = 0.0
    for i in range(n):
        t = i / SR
        # Kratak udarac šuma (mehanizam) + rezonantni ton (kućište sata).
        sum_ = rnd.uniform(-1, 1) * math.exp(-t * 900)
        prethodni = 0.6 * prethodni + 0.4 * sum_  # malo prigušen šum
        ton = math.sin(2 * math.pi * frek * t) * math.exp(-t * 110)
        ton2 = 0.35 * math.sin(2 * math.pi * frek * 2.01 * t) * math.exp(-t * 180)
        napad = min(1.0, i / (SR * 0.0008))
        uzorci.append(napad * (0.55 * prethodni + 0.6 * ton + ton2) * jacina)
    return uzorci


def snimi(ime, uzorci):
    with wave.open(os.path.join(OUT, ime), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s)) * 32000)) for s in uzorci))


snimi('sat_tak.wav', otkucaj(1250, 0.35, seme=2))
snimi('sat_0.wav', otkucaj(1650, 0.40))
for k in range(1, 11):
    # Polustepen po polustepen naviše, sve glasnije: drama pred kraj.
    frek = 1650 * 2 ** ((k * 1.5) / 12)
    snimi(f'sat_{k}.wav', otkucaj(frek, 0.45 + 0.05 * k, seme=k + 2))
