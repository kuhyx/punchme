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
| 12 | Background the app, then tap the tag | Nothing happens — Stage 1 does not handle background taps |

A check-in that raises the check-out alarm dialog deliberately shows **no**
banner: the dialog reports the punch instead, and the banner is cleared so a
failed-alarm message is not queued behind it. Check 3 is easiest to read on a
check-*out*, or on a check-in on a non-working day.

## Stage 2 — background and cold start (NOT implemented)

These will fail today. They are listed so the gap is explicit.

| # | Check | Expected once built |
|---|---|---|
| 13 | Phone unlocked, app backgrounded, tap the tag | App comes forward and punches |
| 14 | Kill the app, tap the tag | App launches and logs the punch |
| 15 | Lock the phone, tap the tag | Punch is recorded; banner appears on next unlock |

## If something fails

Timestamps are written as local ISO-8601 with an offset, so a punch made either
side of a DST change stays correct. If a punch lands on the wrong day, check
that the phone's clock and timezone are right before filing it as a bug — the
day is keyed by the check-in date, and an overnight session belongs wholly to
the day it started.
