package com.kuhy.punchme

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Spins a short-lived headless engine, calls one method on it, and tears it
 * down -- the shape every headless entry point here needs, so it exists
 * once. [ExportRunner] and the Wi-Fi auto-punch transport both use this.
 *
 * The entry point has to reach the point where it registers its handler
 * before the call can land, so a `notImplemented` reply is retried briefly
 * rather than treated as a final answer.
 */
object HeadlessDartRunner {
    private const val MAX_ATTEMPTS = 40
    private const val RETRY_MS = 250L

    /**
     * Runs [method] with [argument] against a fresh headless engine on
     * [channelName], reporting the outcome to [onResult].
     */
    fun run(
        context: Context,
        channelName: String,
        method: String,
        argument: Any?,
        onResult: MethodChannel.Result,
    ) {
        // Engines must be created and torn down on the main thread.
        Handler(Looper.getMainLooper()).post {
            val engine = FlutterEngine(context)
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault(),
            )
            val channel = MethodChannel(engine.dartExecutor.binaryMessenger, channelName)
            invokeWhenReady(engine, channel, method, argument, onResult, attempt = 0)
        }
    }

    private fun invokeWhenReady(
        engine: FlutterEngine,
        channel: MethodChannel,
        method: String,
        argument: Any?,
        onResult: MethodChannel.Result,
        attempt: Int,
    ) {
        channel.invokeMethod(
            method,
            argument,
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    onResult.success(result)
                    engine.destroy()
                }

                override fun error(code: String, message: String?, details: Any?) {
                    onResult.error(code, message, details)
                    engine.destroy()
                }

                override fun notImplemented() {
                    if (attempt >= MAX_ATTEMPTS) {
                        onResult.notImplemented()
                        engine.destroy()
                        return
                    }
                    Handler(Looper.getMainLooper()).postDelayed({
                        invokeWhenReady(engine, channel, method, argument, onResult, attempt + 1)
                    }, RETRY_MS)
                }
            },
        )
    }
}
