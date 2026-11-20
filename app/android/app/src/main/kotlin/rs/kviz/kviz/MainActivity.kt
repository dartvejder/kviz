package rs.kviz.kviz

import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rs.kviz/uredjaj").setMethodCallHandler { poziv, rezultat ->
            when (poziv.method) {
                // Google-ovi test uređaji (Firebase Test Lab, pre-launch izveštaj na Play-u) imaju ovu oznaku.
                "testLab" -> rezultat.success(
                    try {
                        Settings.System.getString(contentResolver, "firebase.test.lab") == "true"
                    } catch (e: Exception) {
                        false
                    }
                )
                else -> rezultat.notImplemented()
            }
        }
    }
}
