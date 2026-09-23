package com.kuhy.punchme

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.wifi.WifiManager
import androidx.core.content.ContextCompat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Resolves the SSID of the currently connected Wi-Fi network, or null when
 * there is none -- or the permission it needs is not granted.
 *
 * Shared by [WifiChannel] (Dart asking directly) and [WifiObserverService]
 * (reporting on a connectivity change), so the one "how do we read an SSID"
 * quirk exists once.
 */
fun currentSsid(context: Context): String? {
    if (ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) != PackageManager.PERMISSION_GRANTED
    ) {
        return null
    }
    val manager =
        context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            ?: return null
    val raw = manager.connectionInfo?.ssid ?: return null
    // WifiInfo.getSSID() wraps a UTF-8 SSID in literal double quotes.
    val unquoted = raw.removeSurrounding("\"")
    return if (unquoted.isEmpty() || unquoted == WifiManager.UNKNOWN_SSID) null else unquoted
}

/**
 * The current instant as local ISO-8601 with a numeric UTC offset.
 *
 * Matches the spelling `isoWithOffset`/`parseLocal` write and read on the
 * Dart side; Dart's `DateTime.parse` accepts an offset with or without a
 * colon, so the plain 4-digit form here round-trips.
 */
fun nowIso(): String = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSZ", Locale.US).format(Date())
