package com.kuhy.punchme

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** The channel name. Mirrors `kExportChannelName` on the Dart side. */
private const val EXPORT_CHANNEL = "kuhy.punchme/export"

/**
 * Renders an export by running the Dart entry point headlessly.
 *
 * Kotlin does no rendering of its own -- it asks Dart for the bytes, via
 * [HeadlessDartRunner], and writes them, so there is exactly one
 * implementation of what an export contains.
 */
class ExportRunner(private val context: Context) {

    /** Renders [format] and writes it to [out]. */
    fun run(format: String, out: String) = start(format, out)

    /** Writes this device's Firebase session to [out]. See the action doc. */
    fun dumpSession(out: String) = start("", out, "dumpSession")

    /** Verifies this device really syncs, writing the report to [out]. */
    fun syncCheck(out: String) = start("", out, "runSyncCheck")

    /** Restores the export in [contents], replacing the days it names. */
    fun restore(contents: String) = start(contents, null, "runImport")

    private fun start(format: String, out: String?, method: String = "runExport") {
        HeadlessDartRunner.run(
            context = context,
            channelName = EXPORT_CHANNEL,
            method = method,
            argument = format,
            onResult = object : MethodChannel.Result {
                override fun success(result: Any?) {
                    if (out == null) {
                        Log.i(EXPORT_TAG, "restore: ${result as? String}")
                    } else {
                        write(result as? String, out)
                    }
                }

                override fun error(code: String, message: String?, details: Any?) {
                    Log.e(EXPORT_TAG, "export failed: $code $message")
                }

                override fun notImplemented() {
                    Log.e(EXPORT_TAG, "Dart never registered the export handler")
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
}
