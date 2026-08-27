package com.kuhy.punchme

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import java.io.File

/** The action that asks the app to write an export file. */
const val EXPORT_ACTION = "com.kuhy.punchme.EXPORT"

/**
 * The action that restores a previously exported JSON file.
 *
 * Reads from the same fixed directory the export writes to, so a restore
 * cannot be pointed at a file the caller supplies from elsewhere.
 */
const val IMPORT_ACTION = "com.kuhy.punchme.IMPORT"

/** Extra naming the format: `json`, `csv` or `ics`. Defaults to `json`. */
const val EXTRA_FORMAT = "format"

/** Log tag; `adb logcat -s PunchmeExport` follows a headless run. */
const val EXPORT_TAG = "PunchmeExport"

/**
 * Runs an export with no UI, for backups and for automated verification.
 *
 * Deliberately unprotected, because the point is to be reachable from
 * `adb shell am broadcast`: adb runs as the shell UID, which is not signed
 * with the app's key and so could never satisfy a signature-level permission.
 *
 * What stands in for that permission is the destination. The file is always
 * written inside the app's own external directory, whose path is fixed here
 * and never taken from the intent. On API 30+ that directory is not readable
 * by other apps, so a hostile caller can make the phone write a file it
 * cannot then read, and cannot redirect it somewhere world-readable. An
 * arbitrary output path was considered and dropped for exactly that reason.
 *
 * Rendering goes through the same functions the Settings buttons use, so an
 * automated backup cannot drift from a hand-taken one.
 */
class ExportReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val runner = ExportRunner(context)
        when (intent.action) {
            EXPORT_ACTION -> {
                val format = intent.getStringExtra(EXTRA_FORMAT) ?: "json"
                val out = File(context.getExternalFilesDir(null), "punchme.$format")
                // The engine owns the data, so the work is handed to it and
                // the result written from its callback; a receiver may not
                // block.
                runner.run(format = format, out = out.absolutePath)
            }
            IMPORT_ACTION -> {
                val src = File(context.getExternalFilesDir(null), "punchme.json")
                if (!src.exists()) {
                    Log.e(EXPORT_TAG, "no punchme.json to restore at $src")
                    return
                }
                runner.restore(src.readText())
            }
        }
    }
}
