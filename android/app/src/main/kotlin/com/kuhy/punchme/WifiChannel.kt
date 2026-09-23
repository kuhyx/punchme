package com.kuhy.punchme

import android.Manifest
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** The channel name. Mirrors `kWifiChannelName` on the Dart side. */
private const val CHANNEL = "kuhy.punchme/wifi"

private const val PREFS_NAME = "punchme_wifi"
private const val PREF_ARMED = "armed"

/**
 * The Dart-facing half of the Wi-Fi auto-punch feature.
 *
 * Answers what Dart asks (current SSID, permission/service status) and
 * records whether Dart wants the watcher armed. Never decides which SSID
 * counts as work -- that stays a Dart-side decision, made from the SSID this
 * reports.
 *
 * [requestPermissions] is called whenever Dart asks for something that needs
 * a permission not yet granted. Checking permission state needs no Activity,
 * but *asking* for one does, so this stays a callback into [MainActivity]
 * rather than something this class can do on its own.
 */
class WifiChannel(private val context: Context, private val requestPermissions: () -> Unit) {
    private var channel: MethodChannel? = null

    /** Starts answering Dart's requests on [engine]. */
    fun attach(engine: FlutterEngine) {
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCurrentSsid" -> {
                        if (!locationGranted(context)) {
                            requestPermissions()
                        }
                        result.success(currentSsid(context))
                    }
                    "setWifiArmed" -> {
                        val armed = call.arguments as? Boolean ?: false
                        setArmed(context, armed)
                        if (armed && !locationGranted(context)) {
                            requestPermissions()
                        }
                        result.success(null)
                    }
                    "getWifiStatus" -> result.success(statusMap(context))
                    else -> result.notImplemented()
                }
            }
        }
    }

    /** Stops answering, so a torn-down engine cannot be called back into. */
    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
    }
}

private fun statusMap(context: Context): Map<String, Boolean> = mapOf(
    "locationGranted" to locationGranted(context),
    "notificationGranted" to notificationGranted(context),
    "serviceRunning" to isArmed(context),
)

private fun locationGranted(context: Context): Boolean =
    ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
        PackageManager.PERMISSION_GRANTED

private fun notificationGranted(context: Context): Boolean {
    // No such permission to grant below Android 13; the notification just
    // shows.
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
        return true
    }
    return ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
        PackageManager.PERMISSION_GRANTED
}

private fun prefs(context: Context): SharedPreferences =
    context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

/** Whether at least one work SSID is configured, per Dart's last report. */
fun isArmed(context: Context): Boolean = prefs(context).getBoolean(PREF_ARMED, false)

/**
 * Records whether Dart wants the watcher armed, and starts or stops the
 * foreground service and the periodic worker to match.
 */
fun setArmed(context: Context, armed: Boolean) {
    prefs(context).edit().putBoolean(PREF_ARMED, armed).apply()
    if (armed) {
        WifiObserverService.start(context)
        WifiCheckWorker.schedule(context)
    } else {
        WifiObserverService.stop(context)
        WifiCheckWorker.cancel(context)
    }
}
