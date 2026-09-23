package com.kuhy.punchme

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Restarts [WifiObserverService] after a reboot, if it was armed.
 *
 * The periodic [WifiCheckWorker] needs no equivalent here -- WorkManager
 * persists an enqueued periodic request and reschedules itself. A plain
 * (non-foreground) service does not restart itself, so this covers the
 * instant-detection half only.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) {
            return
        }
        if (isArmed(context)) {
            WifiObserverService.start(context)
        }
    }
}
