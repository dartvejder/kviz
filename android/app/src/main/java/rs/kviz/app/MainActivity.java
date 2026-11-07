package rs.kviz.app;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
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
