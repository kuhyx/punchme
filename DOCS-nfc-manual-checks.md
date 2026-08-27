# NFC tap-to-clock: on-device checks

The unit suite covers the logic, but nothing in it touches NFC hardware. These
are the checks only a real phone with a real tag can settle, so they are listed
here rather than claimed as done.

Deploy with `scripts/phone_deploy.sh`. You need one blank NTAG215 (or any
writable NDEF tag) and, for check 5, any non-punchme tag — a transit card or a
hotel key works.

## Stage 1 — foreground (implemented)

| # | Check | Expected |
|---|---|---|
| 1 | Open the app, tap the tag | Button flips, `tap again to cancel` shows for 3s, then it commits |
| 2 | Repeat check 1 and tap the button during the 3s window | The punch is cancelled; nothing is written |
| 3 | After a punch lands, read the banner | `Checked IN/OUT HH:MM via desk tag`, with an **Undo** action |
| 4 | Tap **Undo** on the banner | A check-in disappears entirely; a check-out reopens the day |
| 5 | Tap a non-punchme tag (transit card) | Nothing happens at all — no banner, no state change |
| 6 | Tap a blank, unwritten tag | `That tag is not set up yet. Use Settings > Write clock tag.` |
| 7 | Tap the tag twice within 3 minutes | The second is refused: `Ignored: you punched moments ago` |
| 8 | Settings → Write clock tag, label it, hold a blank tag | `Tag written. Tap it to clock in or out.` |
| 9 | Re-run check 8 against an already-written tag | It overwrites cleanly and still reads back |
| 10 | Turn NFC off, then Settings → Write clock tag → Write tag | `Turn NFC on to write a tag.` |
| 11 | Start a write, then pull the tag away mid-write | `The tag moved away too soon. Hold it still and try again.` |
| 12 | With the app open, tap a tag, then tap it again inside 3 minutes | Only the first punch is written (see check 7) |

Checks 1 and 8 were confirmed on hardware on 2026-08-27 alongside Stage 2.

A check-in that raises the check-out alarm dialog deliberately shows **no**
banner: the dialog reports the punch instead, and the banner is cleared so a
failed-alarm message is not queued behind it. Check 3 is easiest to read on a
check-*out*, or on a check-in on a non-working day.

## Stage 2 — background and cold start (VERIFIED on hardware 2026-08-27)

Run on the Pixel 6a (23181JEGR08034) against a written NTAG. Each result below
was read back from the device's own data file via the headless export, not
from the screen.

| # | Check | Expected | Result |
|---|---|---|---|
| 13 | Phone unlocked, app backgrounded, tap the tag | App comes forward and punches | **PASS** — `LAUNCH_SINGLE_TOP`, warm `onNewIntent`, displayed +88ms |
| 14 | Kill the app, tap the tag | App launches and logs the punch | **PASS** — from `app died, no saved state`, displayed +174ms |
| 15 | Lock the phone, tap the tag | See below | **NOT ACHIEVABLE** — Android does not dispatch tags with the screen off |
| 16 | Tap a non-punchme tag with the app closed | Nothing launches | **PASS** — dispatched `TECH_DISCOVERED` to the system Tag viewer; punchme never invoked |

The 88ms/174ms split is the useful part of 13 vs 14: it shows the two
genuinely took different paths (warm `onNewIntent` against cold `onCreate`
buffer plus `getLaunchPunch` drain) rather than both quietly doing the same
thing. Decoded off the air, the record read
`application/vnd.kuhy.punchme` / `{"v":1,"tag":"home"}`.

### Check 15: why a screen-off tap cannot work

With the screen off and locked, the NFC controller senses the field
(`nfa_dm_set_rf_field_info_ntf: val = 0x1`) and then deactivates it without
ever raising `onTagRfDiscovered` or `dispatchTag`. No app receives the tag,
so this is platform policy rather than anything punchme can fix. `Secure NFC`
was off at the time, so that is not the cause either.

In practice the phone is awake by the time it reaches the tag. A tap with the
screen **on** is what Stage 2 actually has to handle, and 13/14 cover it.

A background tap deliberately behaves differently from a foreground one:

* **It commits immediately, with no 3s cancel window.** The phone can relock
  the instant it leaves the tag, which would take an uncommitted punch with
  it. Undo is on the banner instead.
* **It never raises the check-out alarm dialog.** A modal needs a screen the
  user is looking at; a tap against a locked phone has none.
* **Its banner waits for the next resume.** The punch is already written, so
  the report is what is deferred, not the write.

On check 13, a second banner reading `Ignored: you punched moments ago` may
appear a few seconds after the real one if the tag is still against the phone
when the app comes forward: resuming restarts the foreground reader, which
reads the same tag again and is refused by the 3-minute guard. That is the
guard working — no second punch is written.

## Headless export and restore

Both run with no taps, which is what makes destructive testing safe:

```bash
# Export (json | csv | ics). -f 0x01000000 is FLAG_RECEIVER_INCLUDE_BACKGROUND
# and is REQUIRED: without it Android silently drops the broadcast whenever the
# app is not already foregrounded.
adb shell am broadcast -a com.kuhy.punchme.EXPORT --es format json -f 0x01000000
adb pull /sdcard/Android/data/com.kuhy.punchme/files/punchme.json

# Restore: push a previously exported file back, then import it.
adb push backup.json /sdcard/Android/data/com.kuhy.punchme/files/punchme.json
adb shell am broadcast -a com.kuhy.punchme.IMPORT -f 0x01000000
```

Verifying a restore needs care. Re-exporting straight afterwards reads the
file that is already sitting there and will report success whether or not the
import actually landed. Force-stop the app, delete the file, relaunch, and
export again — that is the only version of the check that reads the app's own
store. The first restore attempt on 2026-08-27 silently did nothing and the
naive check called it byte-identical.

## If something fails

Timestamps are written as local ISO-8601 with an offset, so a punch made either
side of a DST change stays correct. If a punch lands on the wrong day, check
that the phone's clock and timezone are right before filing it as a bug — the
day is keyed by the check-in date, and an overnight session belongs wholly to
the day it started.
