/// JSON export of recorded days.
library;

import 'dart:convert';

import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/settings.dart';

/// Renders [days] and [settings] as pretty-printed JSON.
///
/// The same shape the app stores on disk, so an export doubles as a backup.
String toJsonExport({
  required Iterable<DayEntry> days,
  required Settings settings,
}) {
  final sorted = days.toList()..sort((a, b) => a.dateKey.compareTo(b.dateKey));
  return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
    'settings': settings.toJson(),
    'days': <Map<String, dynamic>>[for (final day in sorted) day.toJson()],
  });
}
