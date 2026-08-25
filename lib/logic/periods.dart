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

/// The Monday *after* [now]'s week, at local midnight — the exclusive end.
///
/// Built with the `DateTime` constructor rather than `add(Duration(days: 7))`:
/// across a DST boundary a 168-hour `Duration` lands on the wrong day, and a
/// weekday-counting loop built on it drifts.
DateTime endOfWeek(DateTime now) {
  final monday = startOfWeek(now);
  return DateTime(monday.year, monday.month, monday.day + 7);
}

/// The first of the month *after* [now]'s, at local midnight.
///
/// `DateTime(2026, 13)` normalises to January 2027, so December needs no
/// special case.
DateTime endOfMonth(DateTime now) => DateTime(now.year, now.month + 1);

/// The first of January *after* [now]'s year, at local midnight.
DateTime endOfYear(DateTime now) => DateTime(now.year + 1);
