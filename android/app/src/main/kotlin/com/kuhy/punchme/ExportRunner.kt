package com.kuhy.punchme

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** The channel name. Mirrors `kExportChannelName` on the Dart side. */
private const val EXPORT_CHANNEL = "kuhy.punchme/export"

/**
 * Renders an export by running the Dart entry point headlessly.
 *
 * A short-lived engine rather than the UI one: the request may arrive with
 * the app closed, and spinning one up here means an export never depends on
 * the activity being alive. Kotlin does no rendering of its own -- it asks
 * Dart for the bytes and writes them, so there is exactly one implementation
 * of what an export contains.
 */
class ExportRunner(private val context: Context) {

    /** Renders [format] and writes it to [out]. */
    fun run(format: String, out: String) {
        // Engines must be created and torn down on the main thread.
        Handler(Looper.getMainLooper()).post { start(format, out) }
    }

    /** Verifies this device really syncs, writing the report to [out]. */
    fun syncCheck(out: String) {
        Handler(Looper.getMainLooper()).post { start("", out, "runSyncCheck") }
    }

    /** Restores the export in [contents], replacing the days it names. */
    fun restore(contents: String) {
        Handler(Looper.getMainLooper()).post { start(contents, null, "runImport") }
    }

    private fun start(format: String, out: String?, method: String = "runExport") {
        val engine = FlutterEngine(context)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault(),
        )
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, EXPORT_CHANNEL)
        // The entry point has to reach the point where it registers its
        // handler, so the call is retried briefly rather than fired blind.
        invokeWhenReady(channel, engine, format, out, method, attempt = 0)
    }

    private fun invokeWhenReady(
        channel: MethodChannel,
        engine: FlutterEngine,
        format: String,
        out: String?,
        method: String,
        attempt: Int,
    ) {
        channel.invokeMethod(
            method,
            format,
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    if (out == null) {
                        Log.i(EXPORT_TAG, "restore: ${result as? String}")
                    } else {
                        write(result as? String, out)
                    }
                    engine.destroy()
                }

                override fun error(code: String, message: String?, details: Any?) {
                    Log.e(EXPORT_TAG, "export failed: $code $message")
                    engine.destroy()
                }

                override fun notImplemented() {
                    if (attempt >= MAX_ATTEMPTS) {
                        Log.e(EXPORT_TAG, "Dart never registered the export handler")
                        engine.destroy()
                        return
                    }
                    Handler(Looper.getMainLooper()).postDelayed({
                        invokeWhenReady(channel, engine, format, out, method, attempt + 1)
                    }, RETRY_MS)
                }
            },
        )
    }

    private fun write(contents: String?, out: String) {
        if (contents == null) {
            Log.e(EXPORT_TAG, "export produced nothing")
            return
        }
        try {
            val file = File(out)
            file.parentFile?.mkdirs()
            file.writeText(contents)
            Log.i(EXPORT_TAG, "wrote ${contents.length} bytes to $out")
        } catch (e: Exception) {
            Log.e(EXPORT_TAG, "could not write $out: ${e.message}")
        }
    }

    private companion object {
        const val MAX_ATTEMPTS = 40
        const val RETRY_MS = 250L
    }
}
