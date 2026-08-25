/// Period start dates for the statistics screen.
library;

/// The Monday of [now]'s week, at local midnight.
DateTime startOfWeek(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return DateTime(today.year, today.month, today.day - (today.weekday - 1));
}

/// The first of [now]'s month, at local midnight.
DateTime startOfMonth(DateTime now) => DateTime(now.year, now.month);

/// The first of January of [now]'s year, at local midnight.
DateTime startOfYear(DateTime now) => DateTime(now.year);
