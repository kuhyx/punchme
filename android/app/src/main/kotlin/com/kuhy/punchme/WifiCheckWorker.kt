package com.kuhy.punchme

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlinx.coroutines.suspendCancellableCoroutine

private const val WORK_NAME = "wifi_check"
private const val WIFI_CHANNEL = "kuhy.punchme/wifi"

/**
 * The periodic backstop for the instant [WifiObserverService]: androidx
 * WorkManager guarantees this runs roughly every 15 minutes -- its own
 * enforced minimum for periodic work -- and survives both the service being
 * killed and a reboot, without a boot receiver of its own (WorkManager
 * reschedules itself once a periodic request has been enqueued).
 *
 * Transport only, like every other platform entry point here: it resolves
 * the current SSID and hands it to Dart via [HeadlessDartRunner], which
 * decides what it means.
 */
class WifiCheckWorker(context: Context, params: WorkerParameters) :
    CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val ssid = currentSsid(applicationContext)
        return suspendCancellableCoroutine { continuation ->
            HeadlessDartRunner.run(
                context = applicationContext,
                channelName = WIFI_CHANNEL,
                method = "runWifiCheck",
                argument = mapOf("ssid" to ssid, "at" to nowIso()),
                onResult = object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        if (continuation.isActive) continuation.resume(Result.success())
                    }

                    override fun error(code: String, message: String?, details: Any?) {
                        if (continuation.isActive) continuation.resume(Result.retry())
                    }

                    override fun notImplemented() {
                        if (continuation.isActive) continuation.resume(Result.retry())
                    }
                },
            )
        }
    }

    companion object {
        /** Schedules the periodic check, leaving one already running alone. */
        fun schedule(context: Context) {
            val request =
                PeriodicWorkRequestBuilder<WifiCheckWorker>(15, TimeUnit.MINUTES).build()
            WorkManager.getInstance(context)
                .enqueueUniquePeriodicWork(WORK_NAME, ExistingPeriodicWorkPolicy.KEEP, request)
        }

        /** Cancels the periodic check. */
        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
        }
    }
}
