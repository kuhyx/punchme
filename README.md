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

Checking in works out how long today should be so that no statistics card
stays red: the required day, plus a slice of the first card that is behind.
It offers to hand that clock time to the system Clock app as an alarm, and
shows it under the button while the day runs.

- **Week** behind → the whole shortfall is added to today. 7h56m on Monday
  makes Tuesday's target **8h04m** — check in at 09:00, out at 17:04.
- Week fine, **month** behind → the month's shortfall is spread over the
  working days left in the week, today included.
- Week and month fine, **year** behind → the year's shortfall is spread over
  the working days left in the month, today included.

The numbers are the ones the statistics cards show, so the alarm and the red
chip never disagree. Being ahead never shortens a day — the target is always
at least the required day. The check-out is capped at 23:59: the Clock alarm
carries only an hour and a minute, so a time past midnight would fire at the
wrong moment today; the dialog says how much is still uncovered.

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
