package com.kuhy.punchme

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

private const val REQUEST_LOCATION = 4301
private const val REQUEST_BACKGROUND_LOCATION = 4302

/**
 * Asks for what auto-punch via Wi-Fi needs, one step at a time.
 *
 * Android 11+ rejects asking for `ACCESS_BACKGROUND_LOCATION` in the same
 * request as `ACCESS_FINE_LOCATION` -- it has to follow, once foreground
 * location is already granted. [MainActivity] calls this both directly (from
 * [WifiChannel], when Dart asks for something that needs a permission not yet
 * granted) and again from [onWifiPermissionResult] once the foreground step
 * resolves.
 */
fun requestWifiPermissions(activity: Activity) {
    if (!granted(activity, Manifest.permission.ACCESS_FINE_LOCATION)) {
        val perms = mutableListOf(Manifest.permission.ACCESS_FINE_LOCATION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            perms += Manifest.permission.POST_NOTIFICATIONS
        }
        ActivityCompat.requestPermissions(activity, perms.toTypedArray(), REQUEST_LOCATION)
        return
    }
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
        !granted(activity, Manifest.permission.ACCESS_BACKGROUND_LOCATION)
    ) {
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
            REQUEST_BACKGROUND_LOCATION,
        )
    }
}

/** Follows up the foreground step with the background one, once it resolves. */
fun onWifiPermissionResult(activity: Activity, requestCode: Int) {
    if (requestCode == REQUEST_LOCATION) {
        requestWifiPermissions(activity)
    }
}

private fun granted(activity: Activity, permission: String): Boolean =
    ContextCompat.checkSelfPermission(activity, permission) == PackageManager.PERMISSION_GRANTED
