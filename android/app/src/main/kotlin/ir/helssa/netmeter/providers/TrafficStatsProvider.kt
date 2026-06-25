package ir.helssa.netmeter.providers

import android.net.TrafficStats

class TrafficStatsProvider {
    fun mobileRxBytes(): Long = clean(TrafficStats.getMobileRxBytes())
    fun mobileTxBytes(): Long = clean(TrafficStats.getMobileTxBytes())
    private fun clean(value: Long) = if (value == TrafficStats.UNSUPPORTED.toLong() || value < 0) 0L else value
}
