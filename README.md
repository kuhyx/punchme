# punchme

Check in when your workday starts, check out when it ends, and know whether
you are ahead of or behind your contracted hours.

The home screen is one enormous button. Tapping it starts a **three-second
cancellable window** — tap again to abort — after which CHECK IN becomes its
exact visual inverse, CHECK OUT. The time recorded is the moment of the *first*
tap, never the moment the window closes.

Android only. Everything is stored on the device; there is no sync.

## Screens

- **Home** — the button, plus today's times and running total.
- **Statistics** — hours missing or in surplus over the week, month and year.
- **History** — every recorded day; tap one to correct its times, or add a day
  you forgot to record.
- **Settings** — hours per working day, which weekdays you work, a calendar of
  free days, and exports.

## Today's target

Checking in works out how long today should be: the hours still owed this week,
split across the working days you have left (today included), rounded to the
nearest minute. It offers to hand that clock time to the system Clock app as an
alarm, and shows it under the button while the day runs.

So a Tue/Wed/Thu week at 8h owes 24h. Log 8h23m on the Tuesday and Wednesday's
target becomes (24h − 8h23m) ÷ 2 = **7h49m** — check out at 16:49. A long day
early in the week shortens the ones after it.

## Exports

CSV, JSON, and iCalendar (`.ics`), each handed to the Android share sheet.
The `.ics` gives every day a stable UID derived from its date, so re-importing
an export **updates** the existing events instead of duplicating your history.

## How the numbers work

- A day is exactly one check-in / check-out pair, keyed by the **check-in**
  date — an overnight shift (in 22:00, out 02:00) belongs wholly to the day it
  started on and counts in full.
- Expected hours accrue only for **finished** working days. A day you are still
  checked into is excluded from both sides and shown separately as a running
  total, so Monday morning reads 0 rather than a full day behind; once you
  check out, that day's hours count and the day is expected too.
- Expectation also starts no earlier than your **first recorded day**, so a
  fresh install reads "On track" instead of owing every working day since
  1 January.
- A past day with no check-out counts as **zero hours**, never as elapsed time.
  It is flagged in History as "missing check-out" — fix it there.
- Timestamps are stored as local ISO-8601 *with* the UTC offset, and dates are
  stepped with the `DateTime` constructor rather than a 24-hour `Duration`, so
  a 23- or 25-hour DST day stays correct.

## Development

```sh
flutter pub get
bash scripts/ci_mirror.sh     # analyze, format, test, coverage gates, build APK
```

`scripts/ci_mirror.sh` is the whole gate and mirrors CI exactly. It enforces
**100% line coverage** plus a completeness check — a `lib/` file that no test
imports is absent from `lcov.info` rather than reported at 0%, so counting only
the report would fail open. A line that genuinely cannot be executed under
`flutter_test` is opted out at the line with `// coverage:ignore-line` and a
reason; there is exactly one, on `main()`.

Install the hooks with `scripts/install_hooks.sh`.

## Licence

MIT — see [LICENSE](LICENSE).
