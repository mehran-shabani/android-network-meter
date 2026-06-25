package ir.helssa.netmeter.providers

import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build

class PackageInfoProvider(private val packageManager: PackageManager) {
    fun appInfo(pkg: String): ApplicationInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        packageManager.getApplicationInfo(pkg, PackageManager.ApplicationInfoFlags.of(0))
    } else {
        @Suppress("DEPRECATION")
        packageManager.getApplicationInfo(pkg, 0)
    }

    fun label(pkg: String): String = try {
        packageManager.getApplicationLabel(appInfo(pkg)).toString()
    } catch (_: Throwable) {
        pkg
    }
}
