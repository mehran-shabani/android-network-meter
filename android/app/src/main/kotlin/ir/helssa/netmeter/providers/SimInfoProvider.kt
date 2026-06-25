package ir.helssa.netmeter.providers

import android.content.Context
import android.os.Build
import android.telephony.SubscriptionInfo
import android.telephony.SubscriptionManager

class SimInfoProvider(private val context: Context) {
    fun activeDataSubId(): Int = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
        SubscriptionManager.getActiveDataSubscriptionId()
    } else {
        @Suppress("DEPRECATION")
        SubscriptionManager.getDefaultSubscriptionId()
    }

    fun simMaps(): List<Map<String, Any?>> {
        val active = activeDataSubId()
        val manager = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
        return try {
            @Suppress("MissingPermission")
            manager.activeSubscriptionInfoList.orEmpty().map { it.toMap(active) }
        } catch (_: Throwable) {
            emptyList()
        }
    }

    fun activeSimMap(): Map<String, Any?>? {
        val active = activeDataSubId()
        if (active == SubscriptionManager.INVALID_SUBSCRIPTION_ID) return null
        return simMaps().firstOrNull { it["subscriptionId"] == active }
            ?: mapOf("subscriptionId" to active, "slotIndex" to -1, "name" to "Data SIM", "isActiveData" to true)
    }

    private fun SubscriptionInfo.toMap(active: Int): Map<String, Any?> = mapOf(
        "subscriptionId" to subscriptionId,
        "slotIndex" to simSlotIndex,
        "name" to ((carrierName ?: displayName)?.toString() ?: "SIM"),
        "isActiveData" to (subscriptionId == active),
    )
}
