import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/export/json_export.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/settings.dart';

DayEntry closed(String key) {
  final checkIn = DateTime.parse('${key}T09:00:00');
  return DayEntry(
    dateKey: key,
    checkIn: checkIn,
    checkOut: checkIn.add(const Duration(hours: 8)),
  );
}

void main() {
  test('carries both settings and days', () {
    final text = toJsonExport(
      days: <DayEntry>[closed('2026-08-25')],
      settings: const Settings(),
    );
    final decoded = json.decode(text) as Map<String, dynamic>;
    expect(decoded.keys, containsAll(<String>['settings', 'days']));
    expect(decoded['days'], hasLength(1));
  });

  test('days come back as DayEntry, so an export is a usable backup', () {
    final original = closed('2026-08-25');
    final decoded =
        json.decode(
              toJsonExport(
                days: <DayEntry>[original],
                settings: const Settings(),
              ),
            )
            as Map<String, dynamic>;
    final days = (decoded['days']! as List).cast<Map<String, dynamic>>();
    expect(DayEntry.fromJson(days.single), original);
  });

  test('sorts days by date', () {
    final decoded =
        json.decode(
              toJsonExport(
                days: <DayEntry>[closed('2026-08-26'), closed('2026-08-24')],
                settings: const Settings(),
              ),
            )
            as Map<String, dynamic>;
    final days = (decoded['days']! as List).cast<Map<String, dynamic>>();
    expect(days.first['dateKey'], '2026-08-24');
  });

  test('preserves customised settings', () {
    final settings = const Settings().copyWith(
      requiredPerDay: const Duration(hours: 6),
      freeDays: const <String>{'2026-12-25'},
    );
    final decoded =
        json.decode(
              toJsonExport(days: const <DayEntry>[], settings: settings),
            )
            as Map<String, dynamic>;
    final restored = Settings.fromJson(
      decoded['settings']! as Map<String, dynamic>,
    );
    expect(restored.requiredPerDay, const Duration(hours: 6));
    expect(restored.freeDays, const <String>{'2026-12-25'});
  });

  test('is pretty-printed, so the file is human-readable', () {
    final text = toJsonExport(
      days: <DayEntry>[closed('2026-08-25')],
      settings: const Settings(),
    );
    expect(text, contains('\n  '));
  });

  test('an empty history still produces a valid document', () {
    final decoded =
        json.decode(
              toJsonExport(
                days: const <DayEntry>[],
                settings: const Settings(),
              ),
            )
            as Map<String, dynamic>;
    expect(decoded['days'], isEmpty);
  });
}
