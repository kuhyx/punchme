/// The headless export path: producing a file with no UI involved.
library;

import 'package:flutter/services.dart';
import 'package:punchme/data/day_repository.dart';
import 'package:punchme/export/csv_export.dart';
import 'package:punchme/export/ics_export.dart';
import 'package:punchme/export/json_export.dart';
import 'package:punchme/export/json_import.dart';

/// The channel the export broadcast receiver talks over.
const String kExportChannelName = 'kuhy.punchme/export';

/// The method the host calls to ask for an export.
const String kRunExportMethod = 'runExport';

/// The method the host calls to restore a JSON export.
const String kRunImportMethod = 'runImport';

/// The formats a headless export can produce.
///
/// Deliberately the same three the Settings buttons offer, rendered by the
/// same pure functions: an automated backup that diverged from the one a
/// human can take would be worse than no automation at all.
enum ExportFormat {
  /// Pretty-printed JSON. The shape the app stores, so it round-trips.
  json,

  /// One row per recorded day.
  csv,

  /// An iCalendar feed of the recorded sessions.
  ics;

  /// The format named [value], or null when it names none of them.
  static ExportFormat? parse(String? value) {
    for (final format in ExportFormat.values) {
      if (format.name == value) {
        return format;
      }
    }
    return null;
  }
}

/// Renders every recorded day in [format].
///
/// Kept separate from the channel plumbing so the rendering is testable
/// without a platform message, and so the Settings buttons and the headless
/// path cannot drift apart.
Future<String> renderExport({
  required DayRepository repository,
  required ExportFormat format,
  required DateTime now,
}) async {
  final days = await repository.loadDays();
  switch (format) {
    case ExportFormat.json:
      final settings = await repository.loadSettings();
      return toJsonExport(days: days, settings: settings);
    case ExportFormat.csv:
      return toCsv(days);
    case ExportFormat.ics:
      return toIcs(days, generatedAt: now);
  }
}

/// Answers headless export requests from the host.
///
/// The host owns *where* the bytes land -- it holds the MediaStore handle and
/// the caller's requested path -- so this side only ever renders and returns
/// them. That keeps the Dart end free of storage permissions entirely.
class ExportChannel {
  /// Creates a channel over [repository].
  ExportChannel({
    required this.repository,
    MethodChannel? channel,
    this.now = DateTime.now,
  }) : _channel = channel ?? const MethodChannel(kExportChannelName);

  /// Where days and settings are read from.
  final DayRepository repository;

  /// The clock, used for the iCalendar DTSTAMP.
  final DateTime Function() now;

  final MethodChannel _channel;

  /// Starts answering export requests.
  void listen() {
    _channel.setMethodCallHandler((call) async {
      if (call.method != kRunExportMethod && call.method != kRunImportMethod) {
        return null;
      }
      if (call.method == kRunImportMethod) {
        final restored = await importJson(
          repository: repository,
          source: call.arguments! as String,
        );
        return 'restored ${restored.days} days, '
            'settings: ${restored.settingsRestored}';
      }
      final format = ExportFormat.parse(call.arguments as String?);
      if (format == null) {
        throw PlatformException(
          code: 'unknown-format',
          message: 'expected one of: ${ExportFormat.values.map((f) => f.name)}',
        );
      }
      return renderExport(
        repository: repository,
        format: format,
        now: now(),
      );
    });
  }

  /// Stops answering, so a disposed app cannot be called back into.
  void stop() => _channel.setMethodCallHandler(null);
}
