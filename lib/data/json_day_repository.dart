/// A [DayRepository] backed by one JSON file in the app-support directory.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:punchme/data/day_repository.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/settings.dart';

/// Stores everything in a single pretty-printed JSON file.
///
/// One file, not a database: this app writes at most twice a day, and a
/// human-readable file is trivially inspectable and trivially exportable.
class JsonDayRepository implements DayRepository {
  /// Creates a repository that reads and writes [file].
  JsonDayRepository(this.file);

  /// Opens the repository at the platform's app-support directory.
  static Future<JsonDayRepository> open() async {
    final dir = await getApplicationSupportDirectory();
    return JsonDayRepository(File(p.join(dir.path, 'punchme.json')));
  }

  /// The backing file. Injected so tests never touch real app data.
  final File file;

  Future<Map<String, dynamic>> _read() async {
    if (!file.existsSync()) {
      return <String, dynamic>{};
    }
    final text = await file.readAsString();
    if (text.trim().isEmpty) {
      return <String, dynamic>{};
    }
    try {
      final decoded = json.decode(text);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on FormatException {
      // A corrupt file must not brick the app: start clean rather than throw
      // on every launch. The next write repairs it.
      return <String, dynamic>{};
    }
  }

  Future<void> _write(Map<String, dynamic> data) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  @override
  Future<List<DayEntry>> loadDays() async {
    final data = await _read();
    final raw = data['days'];
    if (raw is! List) {
      return <DayEntry>[];
    }
    final days = <DayEntry>[];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      try {
        days.add(DayEntry.fromJson(item));
      } on FormatException {
        // Skip an unreadable record rather than losing every other day.
        continue;
      }
    }
    return days..sort((a, b) => a.dateKey.compareTo(b.dateKey));
  }

  @override
  Future<void> saveDay(DayEntry entry) async {
    final days = upsertDay(await loadDays(), entry);
    final data = await _read();
    data['days'] = <Map<String, dynamic>>[
      for (final day in days) day.toJson(),
    ];
    await _write(data);
  }

  @override
  Future<void> deleteDay(String dateKey) async {
    final days = await loadDays();
    final data = await _read();
    data['days'] = <Map<String, dynamic>>[
      for (final day in days)
        if (day.dateKey != dateKey) day.toJson(),
    ];
    await _write(data);
  }

  @override
  Future<Settings> loadSettings() async {
    final data = await _read();
    final raw = data['settings'];
    return raw is Map<String, dynamic>
        ? Settings.fromJson(raw)
        : const Settings();
  }

  @override
  Future<void> saveSettings(Settings settings) async {
    final data = await _read();
    data['settings'] = settings.toJson();
    await _write(data);
  }
}
