/// Local calendar-date keys.
///
/// Every date in this app is a `String` key, never a `DateTime`: `DateTime`
/// equality compares exact instants, so a value that carries a time component
/// silently misses a `Set`/`Map` lookup that "obviously" should have hit.
library;

/// Returns [moment]'s local calendar date as `YYYY-MM-DD`.
///
/// Local, not UTC: a session started late in the evening must not roll into
/// tomorrow's key.
String localDateKey(DateTime moment) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${moment.year.toString().padLeft(4, '0')}-'
      '${two(moment.month)}-${two(moment.day)}';
}

/// Parses a `YYYY-MM-DD` [key] back into a local midnight `DateTime`.
///
/// Throws [FormatException] when [key] is not a well-formed date key.
DateTime dateFromKey(String key) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
  if (match == null) {
    throw FormatException('not a YYYY-MM-DD date key', key);
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  // DateTime happily normalises 2026-02-31 into March; reject that rather
  // than silently keying a day the caller never meant.
  if (date.year != year || date.month != month || date.day != day) {
    throw FormatException('not a real calendar date', key);
  }
  return date;
}

/// Returns the local calendar date one day after [date].
///
/// Uses the `DateTime` constructor rather than `add(Duration(days: 1))`:
/// across a DST boundary a 24-hour `Duration` lands on 23:00 or 01:00 of the
/// wrong day, and any weekday-counting loop built on it drifts.
DateTime nextDay(DateTime date) =>
    DateTime(date.year, date.month, date.day + 1);

/// Returns the local calendar date one day before [date].
///
/// Constructor-based for the same reason as [nextDay]: a 24-hour `Duration`
/// subtracted across a DST boundary lands on the wrong day.
DateTime previousDay(DateTime date) =>
    DateTime(date.year, date.month, date.day - 1);

/// Formats [moment] as ISO-8601 *with* its UTC offset.
///
/// `DateTime.toIso8601String()` drops the offset for a local value, which
/// would make a stored timestamp mean something different if the machine's
/// timezone ever changed. Writing the offset pins the real instant.
String isoWithOffset(DateTime moment) {
  // A UTC value already carries its own designator: `toIso8601String()` ends
  // it with `Z`, and appending an offset to that produces `...Z+00:00`, which
  // does not parse. Only a local value needs the offset spelling out.
  if (moment.isUtc) {
    return moment.toIso8601String();
  }
  final offset = moment.timeZoneOffset;
  final magnitude = offset.abs();
  final sign = offset.isNegative ? '-' : '+';
  String two(int value) => value.toString().padLeft(2, '0');
  return '${moment.toIso8601String()}$sign'
      '${two(magnitude.inHours)}:${two(magnitude.inMinutes % 60)}';
}

/// Parses a timestamp written by [isoWithOffset] back into local time.
///
/// An offset-bearing string parses as UTC, so this converts back to local:
/// the wall-clock time the user actually saw is what the UI must show.
DateTime parseLocal(String text) => DateTime.parse(text).toLocal();
