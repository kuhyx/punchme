/// Restoring recorded days and settings from a JSON export.
library;

import 'dart:convert';

import 'package:punchme/data/day_repository.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/settings.dart';

/// What a restore put back.
class ImportResult {
  /// Creates a summary.
  const ImportResult({required this.days, required this.settingsRestored});

  /// How many days were written.
  final int days;

  /// Whether the settings block was present and restored.
  final bool settingsRestored;
}

/// Parses [source] and writes it into [repository], replacing what is there.
///
/// The exact inverse of `toJsonExport`, so a backup round-trips losslessly --
/// including the sub-second precision the day editor's time picker cannot
/// express. That is the whole point: a restore that silently rounds is not a
/// restore.
///
/// Days present in the file overwrite same-day records; days absent from it
/// are left alone, so a restore cannot quietly delete history the backup
/// predates.
///
/// Throws [FormatException] when the payload is not a punchme export.
Future<ImportResult> importJson({
  required DayRepository repository,
  required String source,
}) async {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException {
    throw const FormatException('not valid JSON');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('export is not a JSON object');
  }

  final rawDays = decoded['days'];
  if (rawDays is! List) {
    throw const FormatException('export has no "days" list');
  }

  var written = 0;
  for (final entry in rawDays) {
    if (entry is! Map<String, dynamic>) {
      throw const FormatException('a day entry is not a JSON object');
    }
    await repository.saveDay(DayEntry.fromJson(entry));
    written++;
  }

  final rawSettings = decoded['settings'];
  final hasSettings = rawSettings is Map<String, dynamic>;
  if (hasSettings) {
    await repository.saveSettings(Settings.fromJson(rawSettings));
  }
  return ImportResult(days: written, settingsRestored: hasSettings);
}
