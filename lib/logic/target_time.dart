/// Working out when to check out, so the week lands on its target.
library;

import 'package:punchme/logic/balance.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/local_date.dart';
import 'package:punchme/models/settings.dart';

/// How long today should last, and when that means checking out.
class TargetToday {
  /// Creates a target.
  const TargetToday({
    required this.share,
    required this.checkOutAt,
    required this.remainingThisWeek,
    required this.workingDaysLeft,
  });

  /// How long to work today: the week's remaining hours split evenly across
  /// the working days left, today included.
  final Duration share;

  /// The clock time that [share] works out to, given today's check-in.
  final DateTime checkOutAt;

  /// Hours still owed this week before today is counted.
  final Duration remainingThisWeek;

  /// Working days left in the week, today included.
  final int workingDaysLeft;
}

/// Counts working days from [now]'s date to the end of its week, inclusive.
///
/// Today counts when it is a working day, because the point of the split is
/// to decide how long *today* should be.
int workingDaysLeftInWeek({
  required DateTime now,
  required Settings settings,
}) {
  var count = 0;
  var cursor = DateTime(now.year, now.month, now.day);
  // Monday is weekday 1, so a week has `7 - weekday + 1` days left from here.
  final daysToSunday = DateTime.sunday - cursor.weekday;
  for (var offset = 0; offset <= daysToSunday; offset++) {
    if (isWorkingDay(localDateKey(cursor), settings)) {
      count++;
    }
    cursor = nextDay(cursor);
  }
  return count;
}

/// Hours still owed across the whole week, minus what is already banked.
///
/// The week's quota counts only the days that are actually working days, so
/// a Tue/Wed/Thu week at 8h owes 24h, not 40.
Duration remainingThisWeek({
  required Iterable<DayEntry> entries,
  required Settings settings,
  required DateTime now,
}) {
  final weekStart = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  var workingDays = 0;
  var cursor = weekStart;
  for (var offset = 0; offset < DateTime.daysPerWeek; offset++) {
    if (isWorkingDay(localDateKey(cursor), settings)) {
      workingDays++;
    }
    cursor = nextDay(cursor);
  }

  final todayKey = localDateKey(now);
  final weekStartKey = localDateKey(weekStart);
  var banked = Duration.zero;
  for (final entry in entries) {
    if (entry.dateKey.compareTo(weekStartKey) < 0) {
      continue;
    }
    // Today's own session is deliberately excluded: it is the day being
    // planned, not a day already banked.
    if (entry.dateKey.compareTo(todayKey) >= 0) {
      continue;
    }
    banked += entry.worked ?? Duration.zero;
  }

  final quota = settings.requiredPerDay * workingDays;
  final left = quota - banked;
  return left.isNegative ? Duration.zero : left;
}

/// Works out how long today should be, given a check-in at [checkIn].
///
/// Splits the week's remaining hours evenly across the working days left
/// (today included) and rounds to the nearest whole minute. Returns null when
/// today is not a working day, or the week is already fully banked — there is
/// no meaningful target to show.
TargetToday? targetForToday({
  required Iterable<DayEntry> entries,
  required Settings settings,
  required DateTime checkIn,
}) {
  final daysLeft = workingDaysLeftInWeek(now: checkIn, settings: settings);
  if (daysLeft == 0) {
    return null;
  }
  final remaining = remainingThisWeek(
    entries: entries,
    settings: settings,
    now: checkIn,
  );
  if (remaining == Duration.zero) {
    return null;
  }
  // Round to the nearest minute rather than truncating, so three days of an
  // odd remainder do not quietly lose up to three minutes.
  final seconds = remaining.inSeconds / daysLeft;
  final share = Duration(minutes: (seconds / 60).round());
  return TargetToday(
    share: share,
    checkOutAt: checkIn.add(share),
    remainingThisWeek: remaining,
    workingDaysLeft: daysLeft,
  );
}
