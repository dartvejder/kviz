package rs.kviz.app;

import android.Manifest;
import android.app.Activity;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.webkit.JavascriptInterface;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

/** Omotač oko web kviza: otvara sajt u WebView-u i šalje broj verzije aplikacije sajtu. */
public class MainActivity extends Activity {
    private static final String HOME = "https://dartvejder.github.io/kviz/";
    private WebView web;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().setStatusBarColor(Color.parseColor("#1a2f9e"));
        web = new WebView(this);
        web.setBackgroundColor(Color.parseColor("#0f1e6e"));
        setContentView(web);

        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setMediaPlaybackRequiresUserGesture(true);
        // Sajt po ovome zna da je otvoren u aplikaciji i koju verziju ima.
        s.setUserAgentString(s.getUserAgentString() + " KvizAndroid/" + BuildConfigInfo.code(this));

        web.addJavascriptInterface(new Bridge(), "KvizApp");

        web.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest req) {
                Uri u = req.getUrl();
                if ("dartvejder.github.io".equals(u.getHost()) && u.getPath() != null && u.getPath().startsWith("/kviz")
                        && !u.getPath().endsWith(".apk")) {
                    return false; // ostaje u aplikaciji
                }
                // Sve ostalo (npr. preuzimanje nove verzije) otvara pregledač.
                try { startActivity(new Intent(Intent.ACTION_VIEW, u)); } catch (Exception ignored) {}
                return true;
            }
        });

        if (state != null) {
            web.restoreState(state);
        } else {
            Uri data = getIntent() != null ? getIntent().getData() : null;
            web.loadUrl(data != null ? data.toString() : HOME);
        }
    }

    /** Deljenje pozivnice preko Vibera, WhatsAppa, Signala ili bilo koje aplikacije. */
    class Bridge {
        /** Traži dozvolu za obaveštenja (Android 13+). */
        @JavascriptInterface
        public void askNotify() {
            runOnUiThread(() -> {
                if (Build.VERSION.SDK_INT >= 33
                        && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                    requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 7);
                }
            });
        }

        /** Obaveštenje domaćinu, npr. kad novi igrač uđe u čekaonicu. */
        @JavascriptInterface
        public void notify(String title, String body) {
            runOnUiThread(() -> showNotification(title, body));
        }

        @JavascriptInterface
        public void share(String text, String pkg) {
            runOnUiThread(() -> {
                Intent send = new Intent(Intent.ACTION_SEND);
                send.setType("text/plain");
                send.putExtra(Intent.EXTRA_TEXT, text);
                if (pkg != null && !pkg.isEmpty()) {
                    Intent direct = new Intent(send).setPackage(pkg);
                    try { startActivity(direct); return; } catch (Exception ignored) {}
                }
                try { startActivity(Intent.createChooser(send, "Pošalji pozivnicu")); } catch (Exception ignored) {}
            });
        }
    }

    private void showNotification(String title, String body) {
        if (Build.VERSION.SDK_INT >= 33
                && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return;
        NotificationManager nm = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        if (nm == null) return;
        Notification.Builder b;
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(new NotificationChannel("igraci", "Novi igrači", NotificationManager.IMPORTANCE_HIGH));
            b = new Notification.Builder(this, "igraci");
        } else {
            b = new Notification.Builder(this).setPriority(Notification.PRIORITY_HIGH).setDefaults(Notification.DEFAULT_ALL);
        }
        Intent open = new Intent(this, MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
        PendingIntent pi = PendingIntent.getActivity(this, 0, open, PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
        b.setSmallIcon(R.mipmap.ic_launcher).setContentTitle(title).setContentText(body)
                .setAutoCancel(true).setContentIntent(pi);
        nm.notify((int) (System.currentTimeMillis() & 0xfffffff), b.build());
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        if (intent != null && intent.getData() != null) web.loadUrl(intent.getData().toString());
    }

    @Override
    protected void onSaveInstanceState(Bundle out) {
        super.onSaveInstanceState(out);
        web.saveState(out);
    }

    @Override
    public void onBackPressed() {
        if (web.canGoBack()) web.goBack(); else super.onBackPressed();
    }
}
