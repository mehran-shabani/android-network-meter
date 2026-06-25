package ir.helssa.netmeter

import android.app.AppOpsManager
import android.app.usage.NetworkStats
import android.app.usage.NetworkStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.TrafficStats
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.provider.Settings
import android.telephony.SubscriptionInfo
import android.telephony.SubscriptionManager
import io.flutter.embedding.android.FlutterActivity
import ir.helssa.netmeter.providers.SimInfoProvider
import ir.helssa.netmeter.providers.TrafficStatsProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.max

class MainActivity : FlutterActivity() {
    private val handler = Handler(Looper.getMainLooper())
    private val trafficStatsProvider = TrafficStatsProvider()
    private val simInfoProvider by lazy { SimInfoProvider(this) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasUsageAccess" -> result.success(hasUsageAccess())
                "openUsageAccessSettings" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(null)
                }
                "snapshot" -> async(result) { snapshot() }
                "report" -> async(result) { report(call.args()) }
                "series" -> async(result) { series(call.args()) }
                else -> result.notImplemented()
            }
        }
    }

    private fun async(result: MethodChannel.Result, block: () -> Any?) {
        Thread {
            try {
                val value = block()
                handler.post { result.success(value) }
            } catch (se: SecurityException) {
                handler.post { result.error("PERMISSION_DENIED", se.message, null) }
            } catch (t: Throwable) {
                handler.post { result.error("NATIVE_ERROR", t.message, null) }
            }
        }.start()
    }

    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun requireUsageAccess() {
        if (!hasUsageAccess()) throw SecurityException("Usage Access فعال نیست. از تنظیمات اندروید فعالش کن.")
    }

    private fun snapshot(): Map<String, Any?> {
        return mapOf(
            "rxBytes" to trafficStatsProvider.mobileRxBytes(),
            "txBytes" to trafficStatsProvider.mobileTxBytes(),
            "time" to System.currentTimeMillis(),
            "isCellularActive" to isCellularActive(),
            "activeSim" to simInfoProvider.activeSimMap()
        )
    }

    private fun report(args: Map<String, Any?>): Map<String, Any?> {
        requireUsageAccess()
        val start = args.longArg("start", System.currentTimeMillis() - DAY_MS)
        val end = args.longArg("end", System.currentTimeMillis())
        val nsm = getSystemService(Context.NETWORK_STATS_SERVICE) as NetworkStatsManager
        val total = nsm.querySummaryForDevice(ConnectivityManager.TYPE_MOBILE, null, start, end)
        val perUid = mutableMapOf<Int, LongArray>()
        val stats = nsm.querySummary(ConnectivityManager.TYPE_MOBILE, null, start, end)
        val bucket = NetworkStats.Bucket()
        try {
            while (stats.hasNextBucket()) {
                stats.getNextBucket(bucket)
                if (skipUid(bucket.uid) || bucket.tag != NetworkStats.Bucket.TAG_NONE) continue
                val row = perUid.getOrPut(bucket.uid) { longArrayOf(0L, 0L) }
                row[0] += max(0L, bucket.rxBytes)
                row[1] += max(0L, bucket.txBytes)
            }
        } finally {
            stats.close()
        }
        val apps = perUid.mapNotNull { appMap(it.key, it.value[0], it.value[1]) }.sortedByDescending { it["totalBytes"] as Long }
        return mapOf(
            "start" to start,
            "end" to end,
            "totalRxBytes" to max(0L, total.rxBytes),
            "totalTxBytes" to max(0L, total.txBytes),
            "apps" to apps,
            "sims" to simInfoProvider.simMaps(),
            "activeSim" to simInfoProvider.activeSimMap()
        )
    }

    private fun series(args: Map<String, Any?>): List<Map<String, Any?>> {
        requireUsageAccess()
        val start = args.longArg("start", System.currentTimeMillis() - DAY_MS)
        val end = args.longArg("end", System.currentTimeMillis())
        val points = args.intArg("points", 24).coerceIn(1, 96)
        val packageName = args["packageName"] as? String
        val uid = if (packageName.isNullOrBlank()) null else uidForPackage(packageName)
        val step = max(60_000L, (end - start) / points)
        val nsm = getSystemService(Context.NETWORK_STATS_SERVICE) as NetworkStatsManager
        val out = mutableListOf<Map<String, Any?>>()
        var cursor = start
        while (cursor < end) {
            val next = minOf(end, cursor + step)
            val pair = if (uid == null) totalPair(nsm, cursor, next) else uidPair(nsm, uid, cursor, next)
            out.add(mapOf("start" to cursor, "end" to next, "rxBytes" to pair.first, "txBytes" to pair.second))
            cursor = next
        }
        return out
    }

    private fun totalPair(nsm: NetworkStatsManager, start: Long, end: Long): Pair<Long, Long> {
        val b = nsm.querySummaryForDevice(ConnectivityManager.TYPE_MOBILE, null, start, end)
        return Pair(max(0L, b.rxBytes), max(0L, b.txBytes))
    }

    private fun uidPair(nsm: NetworkStatsManager, uid: Int, start: Long, end: Long): Pair<Long, Long> {
        val stats = nsm.queryDetailsForUid(ConnectivityManager.TYPE_MOBILE, null, start, end, uid)
        val bucket = NetworkStats.Bucket()
        var rx = 0L
        var tx = 0L
        try {
            while (stats.hasNextBucket()) {
                stats.getNextBucket(bucket)
                if (bucket.tag == NetworkStats.Bucket.TAG_NONE) {
                    rx += max(0L, bucket.rxBytes)
                    tx += max(0L, bucket.txBytes)
                }
            }
        } finally {
            stats.close()
        }
        return Pair(rx, tx)
    }

    private fun appMap(uid: Int, rx: Long, tx: Long): Map<String, Any?>? {
        if (rx + tx <= 0) return null
        val packages = packageManager.getPackagesForUid(uid)?.toList().orEmpty()
        if (packages.isEmpty()) return null
        val primary = packages.first()
        return mapOf(
            "uid" to uid,
            "appName" to label(primary),
            "packageName" to packages.joinToString(","),
            "rxBytes" to rx,
            "txBytes" to tx,
            "totalBytes" to rx + tx
        )
    }

    private fun uidForPackage(packageNameList: String): Int {
        val primary = packageNameList.split(",").first().trim()
        return appInfo(primary).uid
    }

    private fun label(pkg: String): String {
        return try {
            packageManager.getApplicationLabel(appInfo(pkg)).toString()
        } catch (_: Throwable) {
            pkg
        }
    }

    private fun appInfo(pkg: String): ApplicationInfo {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getApplicationInfo(pkg, PackageManager.ApplicationInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION") packageManager.getApplicationInfo(pkg, 0)
        }
    }

    private fun skipUid(uid: Int): Boolean {
        return uid <= 0 || uid == NetworkStats.Bucket.UID_REMOVED || uid == NetworkStats.Bucket.UID_TETHERING || uid == NetworkStats.Bucket.UID_ALL
    }

    private fun isCellularActive(): Boolean {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val net = cm.activeNetwork ?: return false
        val caps = cm.getNetworkCapabilities(net) ?: return false
        return caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)
    }

    private fun simMaps(): List<Map<String, Any?>> {
        val active = activeDataSubId()
        val sm = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
        return try {
            @Suppress("MissingPermission")
            sm.activeSubscriptionInfoList.orEmpty().map { it.toMap(active) }
        } catch (_: Throwable) {
            emptyList()
        }
    }

    private fun activeSimMap(): Map<String, Any?>? {
        val active = activeDataSubId()
        if (active == SubscriptionManager.INVALID_SUBSCRIPTION_ID) return null
        return simMaps().firstOrNull { it["subscriptionId"] == active }
            ?: mapOf("subscriptionId" to active, "slotIndex" to -1, "name" to "Data SIM", "isActiveData" to true)
    }

    private fun activeDataSubId(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) SubscriptionManager.getActiveDataSubscriptionId()
        else @Suppress("DEPRECATION") SubscriptionManager.getDefaultSubscriptionId()
    }

    private fun SubscriptionInfo.toMap(active: Int): Map<String, Any?> {
        return mapOf(
            "subscriptionId" to subscriptionId,
            "slotIndex" to simSlotIndex,
            "name" to ((carrierName ?: displayName)?.toString() ?: "SIM"),
            "isActiveData" to (subscriptionId == active)
        )
    }

    private fun clean(value: Long) = if (value == TrafficStats.UNSUPPORTED.toLong() || value < 0) 0L else value

    private fun MethodCall.args(): Map<String, Any?> {
        @Suppress("UNCHECKED_CAST") return arguments as? Map<String, Any?> ?: emptyMap()
    }

    private fun Map<String, Any?>.longArg(key: String, default: Long): Long = when (val v = this[key]) {
        is Long -> v
        is Int -> v.toLong()
        is Double -> v.toLong()
        is String -> v.toLongOrNull() ?: default
        else -> default
    }

    private fun Map<String, Any?>.intArg(key: String, default: Int): Int = when (val v = this[key]) {
        is Int -> v
        is Long -> v.toInt()
        is Double -> v.toInt()
        is String -> v.toIntOrNull() ?: default
        else -> default
    }

    companion object {
        private const val CHANNEL = "ir.helssa.netmeter/traffic"
        private const val DAY_MS = 24L * 60L * 60L * 1000L
    }
}
