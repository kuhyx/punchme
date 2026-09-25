/// Spending a surplus: how much earlier today may end while every card
/// stays green.
library;

import 'package:punchme/logic/working_days_left.dart';
import 'package:punchme/models/settings.dart';

/// A statistics card, or the stretch of days a surplus is spread over.
enum Horizon {
  /// This week.
  week,

  /// This month.
  month,

  /// This year.
  year,
}

/// The most a surplus may take off one day.
///
/// A surplus spreads over the week first; when that would cut a day by more
/// than this, it spreads over the month instead, then the year. If even the
/// year's days cannot absorb it, the cut stops here.
const Duration maxSurplusSlice = Duration(minutes: 90);

/// Today's cut from a [surplus], and the stretch it is spread over.
///
/// Rounds down to whole minutes, so spending the cut can never leave a card
/// a few seconds red.
({Duration slice, Horizon spread, int days, bool capped}) surplusSlice({
  required Duration surplus,
  required DateTime now,
  required Settings settings,
}) {
  final spans = <(Horizon, int)>[
    (Horizon.week, workingDaysLeftInWeek(now: now, settings: settings)),
    (Horizon.month, workingDaysLeftInMonth(now: now, settings: settings)),
    (Horizon.year, workingDaysLeftInYear(now: now, settings: settings)),
  ];
  for (final (spread, days) in spans) {
    final slice = Duration(minutes: surplus.inSeconds ~/ days ~/ 60);
    if (slice <= maxSurplusSlice) {
      return (slice: slice, spread: spread, days: days, capped: false);
    }
  }
  final (spread, days) = spans.last;
  return (slice: maxSurplusSlice, spread: spread, days: days, capped: true);
}
