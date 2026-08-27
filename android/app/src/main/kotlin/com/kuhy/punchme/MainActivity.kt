package com.kuhy.punchme

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** The channel name. Mirrors `kNfcChannelName` on the Dart side. */
private const val CHANNEL = "kuhy.punchme/nfc"

/**
 * Hosts the Flutter engine and forwards NFC tag launches to it.
 *
 * Kotlin here is a pipe and nothing more. It never decides whether a tap
 * counts, never toggles the day, and holds no state beyond the one buffered
 * payload it is waiting to hand over — the Dart coordinator owns all of that.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    /** The cold-start payload, held until Dart asks for it. */
    private var launchPayload: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Buffered, not pushed: on a cold start the Dart handler does not
        // exist yet, so an invokeMethod from here would be dropped silently.
        launchPayload = punchPayloadFrom(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getLaunchPunch" -> {
                        // Drained once: a relaunch must not replay an old tap.
                        result.success(launchPayload)
                        launchPayload = null
                    }
                    // Dart writes tags, so it needs the flavor's MIME too.
                    // Asked for rather than duplicated, so there is exactly
                    // one definition of it per build.
                    "getPunchMime" -> result.success(PUNCH_MIME)
                    else -> result.notImplemented()
                }
            }
        }
    }

    // singleTop, so a tap against an already-running app arrives here rather
    // than starting a second activity on top of the first.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val payload = punchPayloadFrom(intent) ?: return
        val live = channel
        if (live == null) {
            // The engine is not attached yet, so buffer for the drain instead.
            launchPayload = payload
            return
        }
        live.invokeMethod("onBackgroundPunch", payload)
    }

    override fun onDestroy() {
        channel?.setMethodCallHandler(null)
        channel = null
        super.onDestroy()
    }
}
