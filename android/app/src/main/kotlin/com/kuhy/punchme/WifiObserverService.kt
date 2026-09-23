package com.kuhy.punchme

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel

private const val NOTIFICATION_CHANNEL_ID = "wifi_watch"
private const val NOTIFICATION_ID = 4201
private const val WIFI_CHANNEL = "kuhy.punchme/wifi"
private const val WIFI_TAG = "PunchmeWifi"

/**
 * A foreground service that reports Wi-Fi connect/lose events the instant
 * they happen.
 *
 * Transport only, exactly like [MainActivity]: it never decides which SSID
 * is "work" -- it resolves the SSID and hands the observation to Dart via
 * [HeadlessDartRunner], the same way [WifiCheckWorker]'s periodic backstop
 * does. `START_STICKY` covers a process the OS killed under memory pressure;
 * the periodic worker is the backstop for the gap while it restarts, not a
 * replacement for restarting at all.
 */
class WifiObserverService : Service() {
    private var callback: ConnectivityManager.NetworkCallback? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        startForeground(NOTIFICATION_ID, buildNotification())
        registerCallback()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onDestroy() {
        callback?.let { cb ->
            val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            manager.unregisterNetworkCallback(cb)
        }
        callback = null
        super.onDestroy()
    }

    private fun registerCallback() {
        val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .build()
        val cb = object : ConnectivityManager.NetworkCallback(callbackFlags()) {
            override fun onAvailable(network: Network) = reportObservation(currentSsid(this@WifiObserverService))

            override fun onCapabilitiesChanged(
                network: Network,
                capabilities: NetworkCapabilities,
            ) = reportObservation(currentSsid(this@WifiObserverService))

            override fun onLost(network: Network) = reportObservation(null)
        }
        callback = cb
        manager.registerNetworkCallback(request, cb)
    }

    // API 31+ only exposes the SSID in a network callback when it is
    // registered with this flag; below that, there is no such flag to pass.
    private fun callbackFlags(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ConnectivityManager.NetworkCallback.FLAG_INCLUDE_LOCATION_INFO
        } else {
            0
        }

    private fun reportObservation(ssid: String?) {
        HeadlessDartRunner.run(
            context = applicationContext,
            channelName = WIFI_CHANNEL,
            method = "runWifiCheck",
            argument = mapOf("ssid" to ssid, "at" to nowIso()),
            onResult = SilentResult,
        )
    }

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(
                NotificationChannel(
                    NOTIFICATION_CHANNEL_ID,
                    "Work Wi-Fi watcher",
                    NotificationManager.IMPORTANCE_MIN,
                ),
            )
        }
        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Watching for work Wi-Fi")
            .setSmallIcon(android.R.drawable.stat_notify_sync)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .build()
    }

    companion object {
        /** Starts the service, arming the instant-detection half. */
        fun start(context: Context) {
            val intent = Intent(context, WifiObserverService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /** Stops the service. */
        fun stop(context: Context) {
            context.stopService(Intent(context, WifiObserverService::class.java))
        }
    }
}

/** A [MethodChannel.Result] that logs and otherwise does nothing. */
private object SilentResult : MethodChannel.Result {
    override fun success(result: Any?) {}

    override fun error(code: String, message: String?, details: Any?) {
        android.util.Log.e(WIFI_TAG, "wifi observation failed: $code $message")
    }

    override fun notImplemented() {
        android.util.Log.e(WIFI_TAG, "Dart never registered the wifi handler")
    }
}
