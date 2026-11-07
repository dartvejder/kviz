package rs.kviz.app;

import android.content.Context;
import android.content.pm.PackageInfo;

final class BuildConfigInfo {
    static String code(Context c) {
        try {
            PackageInfo p = c.getPackageManager().getPackageInfo(c.getPackageName(), 0);
            return p.versionCode + "/" + p.versionName;
        } catch (Exception e) {
            return "0/0";
        }
    }
}
