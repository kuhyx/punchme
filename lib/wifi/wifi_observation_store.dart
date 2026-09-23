/// Persisting the last time each day a work Wi-Fi network was seen.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:punchme/models/local_date.dart';

/// One file mapping a date key to the last instant that day a work Wi-Fi
/// network was confirmed still connected.
///
/// A date is removed once end-of-day processing has finalized it (see
/// `runWifiCheck`), so this file never holds more than a day or two of rows.
class WifiObservationStore {
  /// Creates a store backed by [file].
  WifiObservationStore(this.file);

  /// Opens the store at the platform's app-support directory.
  static Future<WifiObservationStore> open() async {
    final dir = await getApplicationSupportDirectory();
    return WifiObservationStore(
      File(p.join(dir.path, 'wifi_observations.json')),
    );
  }

  /// The backing file. Injected so tests never touch real app data.
  final File file;

  /// Every stored date key, mapped to its last-seen instant.
  Future<Map<String, DateTime>> load() async {
    if (!file.existsSync()) {
      return <String, DateTime>{};
    }
    final text = await file.readAsString();
    if (text.trim().isEmpty) {
      return <String, DateTime>{};
    }
    try {
      final decoded = json.decode(text);
      if (decoded is! Map<String, dynamic>) {
        return <String, DateTime>{};
      }
      final result = <String, DateTime>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is! String) {
          continue;
        }
        try {
          result[entry.key] = parseLocal(value);
        } on FormatException {
          // Skip an unreadable row rather than losing every other one.
        }
      }
      return result;
    } on FormatException {
      // A corrupt file must not brick the app: start clean rather than throw
      // on every launch. The next write repairs it.
      return <String, DateTime>{};
    }
  }

  /// Replaces the whole file with [observations].
  Future<void> save(Map<String, DateTime> observations) async {
    await file.parent.create(recursive: true);
    final encoded = <String, String>{
      for (final entry in observations.entries)
        entry.key: isoWithOffset(entry.value),
    };
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(encoded),
    );
  }
}
