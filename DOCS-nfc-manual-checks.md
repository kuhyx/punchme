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

A check-in that raises the check-out alarm dialog deliberately shows **no**
banner: the dialog reports the punch instead, and the banner is cleared so a
failed-alarm message is not queued behind it. Check 3 is easiest to read on a
check-*out*, or on a check-in on a non-working day.

## Stage 2 — background and cold start (implemented, UNVERIFIED on hardware)

The code has landed and the Dart side of the platform channel is covered by
the unit suite, driven over a real `MethodChannel` with a mock host. That
proves the contract, not the hardware: nothing in `flutter test` can deliver
an actual `NDEF_DISCOVERED` intent, so **checks 13-16 have not been run on a
phone.** They are the reason this file exists.

| # | Check | Expected |
|---|---|---|
| 13 | Phone unlocked, app backgrounded, tap the tag | App comes forward and punches |
| 14 | Kill the app, tap the tag | App launches and logs the punch |
| 15 | Lock the phone, tap the tag | Punch is recorded; banner appears on next unlock |
| 16 | Tap a non-punchme tag with the app closed | Nothing launches — the MIME filter does not match |

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

## If something fails

Timestamps are written as local ISO-8601 with an offset, so a punch made either
side of a DST change stays correct. If a punch lands on the wrong day, check
that the phone's clock and timezone are right before filing it as a bug — the
day is keyed by the check-in date, and an overnight session belongs wholly to
the day it started.
