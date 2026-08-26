package com.kuhy.punchme

import android.content.Intent
import android.nfc.NdefMessage
import android.nfc.NfcAdapter
import android.os.Build

/** The MIME type identifying a punchme clock tag. Mirrors `kPunchMime`. */
const val PUNCH_MIME = "application/vnd.kuhy.punchme"

/**
 * Extracts the punchme record's payload from a tag-launch [intent].
 *
 * Returns null for anything that is not one of our tags, so the Dart side is
 * only ever handed a payload it can act on. This is transport, not state: it
 * decides what to forward, never whether the day toggles.
 */
fun punchPayloadFrom(intent: Intent?): String? {
    if (intent == null || intent.action != NfcAdapter.ACTION_NDEF_DISCOVERED) {
        return null
    }
    val raw = ndefMessages(intent) ?: return null
    for (message in raw) {
        for (record in message.records) {
            if (String(record.type, Charsets.US_ASCII) == PUNCH_MIME) {
                return String(record.payload, Charsets.UTF_8)
            }
        }
    }
    return null
}

/**
 * Reads EXTRA_NDEF_MESSAGES off [intent] across API levels.
 *
 * The typed getter only exists from API 33; below that the untyped array has
 * to be narrowed by hand, and a malformed extra yields null rather than
 * throwing into the activity's lifecycle.
 */
@Suppress("DEPRECATION")
private fun ndefMessages(intent: Intent): List<NdefMessage>? {
    val extra = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        intent.getParcelableArrayExtra(
            NfcAdapter.EXTRA_NDEF_MESSAGES,
            NdefMessage::class.java,
        )
    } else {
        intent.getParcelableArrayExtra(NfcAdapter.EXTRA_NDEF_MESSAGES)
    } ?: return null
    return extra.filterIsInstance<NdefMessage>().ifEmpty { null }
}
