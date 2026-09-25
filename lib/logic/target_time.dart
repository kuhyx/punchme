/// Working out when to check out, so no statistics card stays red.
library;

import 'package:punchme/logic/balance.dart';
import 'package:punchme/logic/periods.dart';
import 'package:punchme/logic/surplus.dart';
import 'package:punchme/logic/working_days_left.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/local_date.dart';
import 'package:punchme/models/settings.dart';

/// Which statistics card today's extra time is repaying.
///
/// Ordered by precedence: the first red card wins, because a month's deficit
/// already contains its weeks' and a year's contains its months'. Summing
/// them would bill the same missing minutes twice.
enum DeficitLevel {
  /// Every card is green — a plain day.
  none,

  /// Behind this week: the whole shortfall is added to today.
  week,

  /// Behind this month: the shortfall is spread over the week's days left.
  month,

  /// Behind this year: the shortfall is spread over the month's days left.
  year,
}

/// How long today should last, and when that means checking out.
class TargetToday {
  /// Creates a target.
  const TargetToday({
    required this.share,
    required this.checkOutAt,
    required this.level,
    required this.deficit,
    required this.spreadOver,
    required this.uncovered,
    this.surplus = Duration.zero,
    this.tightest,
    this.surplusSpread,
    this.surplusCapped = false,
  });

  /// How long to work today: the required day plus today's slice of the
  /// deficit at [level] or, when every card is green, minus today's slice of
  /// the [surplus]. Never negative.
  final Duration share;

  /// The clock time that [share] works out to, given today's check-in.
  final DateTime checkOutAt;

  /// The first red card, or [DeficitLevel.none] when all are green.
  final DeficitLevel level;

  /// How far behind the [level] card is (positive), zero when on track.
  final Duration deficit;

  /// Working days the deficit or surplus is split across, today included.
  final int spreadOver;

  /// How far ahead the least-ahead card is: the most today can be shortened
  /// by without turning any card red. Zero whenever [level] is not
  /// [DeficitLevel.none].
  final Duration surplus;

  /// The card that set [surplus], or null when there is no surplus.
  final Horizon? tightest;

  /// The stretch [surplus] is spread over, or null when there is none.
  final Horizon? surplusSpread;

  /// Whether today's cut hit [maxSurplusSlice] even spread over the year.
  final bool surplusCapped;

  /// The part of today's slice that the midnight cap cut off.
  ///
  /// The Clock intent carries only an hour and a minute, so a check-out past
  /// midnight would be set for a time already gone *today*. Rather than fire
  /// an alarm at the wrong moment, the target stops at 23:59 and reports
  /// what is left over.
  final Duration uncovered;

  /// Whether the midnight cap shortened today's slice.
  bool get isCapped => uncovered > Duration.zero;
}

/// Works out how long today should be, given a check-in at [checkIn].
///
/// Starts from the required day and adds a slice of the first red statistics
/// card, in the same numbers the cards themselves show (today's open session
/// excluded): the week's shortfall lands on today in full, the month's is
/// spread over the working days left in the week, the year's over the working
/// days left in the month. Rounds to the nearest whole minute.
///
/// When every card is green, today is shortened instead, by a slice of the
/// smallest surplus (so the tightest card is spent down to zero and none goes
/// red): spread over the week's days left, or the month's, or the year's --
/// the first that keeps the cut within [maxSurplusSlice].
///
/// Caps the check-out at 23:59 of the check-in day. Returns null when today
/// is not a working day — there is no meaningful target to show.
TargetToday? targetForToday({
  required Iterable<DayEntry> entries,
  required Settings settings,
  required DateTime checkIn,
}) {
  if (!isWorkingDay(localDateKey(checkIn), settings)) {
    return null;
  }
  // Positive when ahead, negative when behind.
  Duration difference(DateTime from, DateTime to) => computeBalance(
    entries: entries,
    settings: settings,
    from: from,
    to: to,
    now: checkIn,
  ).difference;
  Duration behind(Duration difference) =>
      difference.isNegative ? -difference : Duration.zero;

  var level = DeficitLevel.none;
  var deficit = Duration.zero;
  var spreadOver = 1;
  final differences = <Horizon, Duration>{
    Horizon.week: difference(startOfWeek(checkIn), endOfWeek(checkIn)),
    Horizon.month: difference(startOfMonth(checkIn), endOfMonth(checkIn)),
    Horizon.year: difference(startOfYear(checkIn), endOfYear(checkIn)),
  };
  final week = behind(differences[Horizon.week]!);
  final month = behind(differences[Horizon.month]!);
  final year = behind(differences[Horizon.year]!);
  if (week > Duration.zero) {
    level = DeficitLevel.week;
    deficit = week;
  } else if (month > Duration.zero) {
    level = DeficitLevel.month;
    deficit = month;
    spreadOver = workingDaysLeftInWeek(now: checkIn, settings: settings);
  } else if (year > Duration.zero) {
    level = DeficitLevel.year;
    deficit = year;
    spreadOver = workingDaysLeftInMonth(now: checkIn, settings: settings);
  }

  // Round to the nearest minute rather than truncating, so several days of an
  // odd remainder do not quietly lose a minute each.
  final sliceSeconds = deficit.inSeconds / spreadOver;
  var slice = Duration(minutes: (sliceSeconds / 60).round());

  var surplus = Duration.zero;
  Horizon? tightest;
  Horizon? surplusSpread;
  var surplusCapped = false;
  if (level == DeficitLevel.none) {
    // All green here, so every difference is >= 0 and the smallest is how
    // much can come off before the first card turns red.
    final least = differences.entries.reduce(
      (a, b) => b.value < a.value ? b : a,
    );
    if (least.value > Duration.zero) {
      surplus = least.value;
      tightest = least.key;
      final cut = surplusSlice(
        surplus: surplus,
        now: checkIn,
        settings: settings,
      );
      slice = -cut.slice;
      surplusSpread = cut.spread;
      spreadOver = cut.days;
      surplusCapped = cut.capped;
    }
  }

  var share = settings.requiredPerDay + slice;
  if (share.isNegative) {
    share = Duration.zero;
  }
  var checkOutAt = checkIn.add(share);
  var uncovered = Duration.zero;
  final lastMinute = DateTime(checkIn.year, checkIn.month, checkIn.day, 23, 59);
  if (checkOutAt.isAfter(lastMinute)) {
    final fits = lastMinute.difference(checkIn);
    uncovered = share - fits;
    share = fits;
    checkOutAt = lastMinute;
  }
  return TargetToday(
    share: share,
    checkOutAt: checkOutAt,
    level: level,
    deficit: deficit,
    spreadOver: spreadOver,
    uncovered: uncovered,
    surplus: surplus,
    tightest: tightest,
    surplusSpread: surplusSpread,
    surplusCapped: surplusCapped,
  );
}
