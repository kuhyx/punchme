/// Working out when to check out, so no statistics card stays red.
library;

import 'package:punchme/logic/balance.dart';
import 'package:punchme/logic/periods.dart';
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
  });

  /// How long to work today: the required day plus today's slice of the
  /// deficit at [level]. Never shorter than the required day — being ahead
  /// does not buy a short day, only being behind buys a long one.
  final Duration share;

  /// The clock time that [share] works out to, given today's check-in.
  final DateTime checkOutAt;

  /// The first red card, or [DeficitLevel.none] when all are green.
  final DeficitLevel level;

  /// How far behind the [level] card is (positive), zero when on track.
  final Duration deficit;

  /// Working days the deficit is split across, today included.
  final int spreadOver;

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

/// Counts working days from [now]'s date up to (excluding) [until].
///
/// Today counts when it is a working day, because the point of the split is
/// to decide how long *today* should be.
int workingDaysLeft({
  required DateTime now,
  required DateTime until,
  required Settings settings,
}) {
  var count = 0;
  var cursor = DateTime(now.year, now.month, now.day);
  while (cursor.isBefore(until)) {
    if (isWorkingDay(localDateKey(cursor), settings)) {
      count++;
    }
    cursor = nextDay(cursor);
  }
  return count;
}

/// Working days from [now]'s date to the end of its week, today included.
int workingDaysLeftInWeek({
  required DateTime now,
  required Settings settings,
}) => workingDaysLeft(now: now, until: endOfWeek(now), settings: settings);

/// Working days from [now]'s date to the end of its month, today included.
int workingDaysLeftInMonth({
  required DateTime now,
  required Settings settings,
}) => workingDaysLeft(now: now, until: endOfMonth(now), settings: settings);

/// Works out how long today should be, given a check-in at [checkIn].
///
/// Starts from the required day and adds a slice of the first red statistics
/// card, in the same numbers the cards themselves show (today's open session
/// excluded): the week's shortfall lands on today in full, the month's is
/// spread over the working days left in the week, the year's over the working
/// days left in the month. Rounds to the nearest whole minute and caps the
/// check-out at 23:59 of the check-in day. Returns null when today is not a
/// working day — there is no meaningful target to show.
TargetToday? targetForToday({
  required Iterable<DayEntry> entries,
  required Settings settings,
  required DateTime checkIn,
}) {
  if (!isWorkingDay(localDateKey(checkIn), settings)) {
    return null;
  }
  Duration behind(DateTime from, DateTime to) {
    final difference = computeBalance(
      entries: entries,
      settings: settings,
      from: from,
      to: to,
      now: checkIn,
    ).difference;
    return difference.isNegative ? -difference : Duration.zero;
  }

  var level = DeficitLevel.none;
  var deficit = Duration.zero;
  var spreadOver = 1;
  final week = behind(startOfWeek(checkIn), endOfWeek(checkIn));
  final month = behind(startOfMonth(checkIn), endOfMonth(checkIn));
  final year = behind(startOfYear(checkIn), endOfYear(checkIn));
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
  final slice = Duration(minutes: (sliceSeconds / 60).round());
  var share = settings.requiredPerDay + slice;
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
  );
}
