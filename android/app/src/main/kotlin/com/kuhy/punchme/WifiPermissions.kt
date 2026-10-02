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
 * Asks for what auto-punch via Wi-Fi needs, one step at a time, and only when
 * Dart says so.
 *
 * Dart shows its own explanation first and then calls [ask]; nothing here
 * ever raises a system prompt on its own, so the user never meets a location
 * request they were not told about.
 *
 * Android 11+ rejects asking for `ACCESS_BACKGROUND_LOCATION` in the same
 * request as `ACCESS_FINE_LOCATION` -- it has to follow, once foreground
 * location is already granted. [onResult] chains that second step.
 */
class WifiPermissionAsker(private val activity: Activity) {
    /** Answers the Dart call that is waiting on the foreground step. */
    private var pending: ((Boolean) -> Unit)? = null

    /** Asks for foreground location, then reports whether it was granted. */
    fun ask(done: (Boolean) -> Unit) {
        if (granted(activity, Manifest.permission.ACCESS_FINE_LOCATION)) {
            done(true)
            return
        }
        // A second ask before the first resolved: answer the first now, so
        // every Dart call gets exactly one reply.
        pending?.invoke(false)
        pending = done
        val perms = mutableListOf(Manifest.permission.ACCESS_FINE_LOCATION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            perms += Manifest.permission.POST_NOTIFICATIONS
        }
        ActivityCompat.requestPermissions(activity, perms.toTypedArray(), REQUEST_LOCATION)
    }

    /** Reports the foreground step and follows it up with the background one. */
    fun onResult(requestCode: Int) {
        if (requestCode != REQUEST_LOCATION) {
            return
        }
        val fine = granted(activity, Manifest.permission.ACCESS_FINE_LOCATION)
        pending?.invoke(fine)
        pending = null
        if (fine &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            !granted(activity, Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        ) {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
                REQUEST_BACKGROUND_LOCATION,
            )
        }
    }
}

private fun granted(activity: Activity, permission: String): Boolean =
    ContextCompat.checkSelfPermission(activity, permission) == PackageManager.PERMISSION_GRANTED
