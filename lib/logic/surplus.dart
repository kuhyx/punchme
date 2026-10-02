/// Spending a surplus: how much earlier today may end while every card
/// stays green.
library;

import 'package:punchme/logic/working_days_left.dart';
import 'package:punchme/models/horizon.dart';
import 'package:punchme/models/settings.dart';

export 'package:punchme/models/horizon.dart';

/// The most a surplus may take off one day.
///
/// A surplus spreads over the week first; when that would cut a day by more
/// than this, it spreads over the month instead, then the year. If even the
/// widest counted card's days cannot absorb it, the cut stops here -- unless
/// that card is the week, see [surplusSlice].
const Duration maxSurplusSlice = Duration(minutes: 90);

/// Today's cut from a [surplus], and the stretch it is spread over.
///
/// Spreads no wider than [widest], the widest card that counts: a stretch
/// whose balance is info only has no business absorbing time. When [widest]
/// is the week, the cut is not capped at all -- a week's surplus is gone on
/// Monday, so holding any of it back only wastes it.
///
/// Rounds down to whole minutes, so spending the cut can never leave a card
/// a few seconds red.
({Duration slice, Horizon spread, int days, bool capped}) surplusSlice({
  required Duration surplus,
  required DateTime now,
  required Settings settings,
  Horizon widest = Horizon.year,
}) {
  final spans = <(Horizon, int)>[
    (Horizon.week, workingDaysLeftInWeek(now: now, settings: settings)),
    if (widest.index >= Horizon.month.index)
      (Horizon.month, workingDaysLeftInMonth(now: now, settings: settings)),
    if (widest == Horizon.year)
      (Horizon.year, workingDaysLeftInYear(now: now, settings: settings)),
  ];
  for (final (spread, days) in spans) {
    final slice = Duration(minutes: surplus.inSeconds ~/ days ~/ 60);
    if (slice <= maxSurplusSlice || widest == Horizon.week) {
      return (slice: slice, spread: spread, days: days, capped: false);
    }
  }
  final (spread, days) = spans.last;
  return (slice: maxSurplusSlice, spread: spread, days: days, capped: true);
}
