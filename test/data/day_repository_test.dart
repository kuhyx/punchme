import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/data/day_repository.dart';
import 'package:punchme/models/day_entry.dart';

DayEntry entry(String key) =>
    DayEntry(dateKey: key, checkIn: DateTime.parse('${key}T09:00:00'));

void main() {
  group('upsertDay', () {
    test('appends a new day', () {
      final days = upsertDay(<DayEntry>[
        entry('2026-08-24'),
      ], entry('2026-08-25'));
      expect(days.map((d) => d.dateKey), <String>['2026-08-24', '2026-08-25']);
    });

    test('replaces the same day rather than duplicating it', () {
      final original = entry('2026-08-25');
      final closed = original.closedAt(DateTime(2026, 8, 25, 17));
      final days = upsertDay(<DayEntry>[original], closed);
      expect(days, hasLength(1));
      expect(days.single.checkOut, isNotNull);
    });

    test('keeps the list sorted by date key', () {
      var days = <DayEntry>[];
      for (final key in <String>['2026-08-26', '2026-08-24', '2026-08-25']) {
        days = upsertDay(days, entry(key));
      }
      expect(
        days.map((d) => d.dateKey),
        <String>['2026-08-24', '2026-08-25', '2026-08-26'],
      );
    });

    test('into an empty list yields just that day', () {
      expect(upsertDay(<DayEntry>[], entry('2026-08-25')), hasLength(1));
    });
  });
}
