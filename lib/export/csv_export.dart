/// CSV export of recorded days.
library;

import 'package:punchme/models/day_entry.dart';

/// The column order written by [toCsv].
const List<String> csvHeader = <String>[
  'date',
  'check_in',
  'check_out',
  'hours',
];

String _escape(String value) {
  if (value.contains(RegExp('[",\n]'))) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

String _clock(DateTime moment) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(moment.hour)}:${two(moment.minute)}';
}

/// Formats [duration] as decimal hours to two places, e.g. `7.50`.
String decimalHours(Duration duration) =>
    (duration.inMinutes / 60).toStringAsFixed(2);

/// Renders [days] as CSV, one row per day, newest last.
///
/// An open day writes an empty check-out and empty hours rather than guessing
/// at an end time — the gap is real, and the file should say so.
String toCsv(Iterable<DayEntry> days) {
  final sorted = days.toList()..sort((a, b) => a.dateKey.compareTo(b.dateKey));
  final rows = <String>[csvHeader.join(',')];
  for (final day in sorted) {
    final worked = day.worked;
    final checkOut = day.checkOut;
    final cells = <String>[
      day.dateKey,
      _clock(day.checkIn),
      if (checkOut == null) '' else _clock(checkOut),
      if (worked == null) '' else decimalHours(worked),
    ];
    rows.add(cells.map(_escape).join(','));
  }
  // Trailing newline: POSIX text files end with one, and spreadsheet
  // importers are happier for it.
  return '${rows.join('\n')}\n';
}
