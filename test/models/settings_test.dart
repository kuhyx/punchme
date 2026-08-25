import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/models/settings.dart';

void main() {
  group('defaults', () {
    test('are 8h, Monday to Friday, no free days', () {
      const settings = Settings();
      expect(settings.requiredPerDay, const Duration(hours: 8));
      expect(settings.workingWeekdays, Settings.defaultWorkingWeekdays);
      expect(settings.workingWeekdays, hasLength(5));
      expect(settings.freeDays, isEmpty);
    });
  });

  group('copyWith', () {
    const settings = Settings();

    test('replaces only what it is given', () {
      final changed = settings.copyWith(
        requiredPerDay: const Duration(hours: 6),
      );
      expect(changed.requiredPerDay, const Duration(hours: 6));
      expect(changed.workingWeekdays, settings.workingWeekdays);
      expect(changed.freeDays, settings.freeDays);
    });

    test('replaces the weekday set', () {
      final changed = settings.copyWith(
        workingWeekdays: const <int>{DateTime.saturday},
      );
      expect(changed.workingWeekdays, const <int>{DateTime.saturday});
    });

    test('replaces the free-day set', () {
      final changed = settings.copyWith(freeDays: const <String>{'2026-12-25'});
      expect(changed.freeDays, const <String>{'2026-12-25'});
    });

    test('with no arguments keeps every field', () {
      final same = settings.copyWith();
      expect(same.requiredPerDay, settings.requiredPerDay);
      expect(same.workingWeekdays, settings.workingWeekdays);
      expect(same.freeDays, settings.freeDays);
    });
  });

  group('json', () {
    test('round-trips a customised settings object', () {
      final original = const Settings().copyWith(
        requiredPerDay: const Duration(hours: 7, minutes: 30),
        workingWeekdays: const <int>{DateTime.monday, DateTime.saturday},
        freeDays: const <String>{'2026-12-25', '2026-01-01'},
      );
      final restored = Settings.fromJson(original.toJson());
      expect(restored.requiredPerDay, original.requiredPerDay);
      expect(restored.workingWeekdays, original.workingWeekdays);
      expect(restored.freeDays, original.freeDays);
    });

    test('writes sorted lists so the file is stable across writes', () {
      final json = const Settings()
          .copyWith(
            workingWeekdays: const <int>{DateTime.friday, DateTime.monday},
            freeDays: const <String>{'2026-12-25', '2026-01-01'},
          )
          .toJson();
      expect(json['workingWeekdays'], <int>[DateTime.monday, DateTime.friday]);
      expect(json['freeDays'], <String>['2026-01-01', '2026-12-25']);
    });

    test('falls back to defaults for missing fields', () {
      final restored = Settings.fromJson(<String, dynamic>{});
      expect(restored.requiredPerDay, const Duration(hours: 8));
      expect(restored.workingWeekdays, Settings.defaultWorkingWeekdays);
      expect(restored.freeDays, isEmpty);
    });

    test('falls back to defaults for wrongly-typed fields', () {
      final restored = Settings.fromJson(<String, dynamic>{
        'requiredMinutesPerDay': 'eight hours',
        'workingWeekdays': 'weekdays',
        'freeDays': 42,
      });
      expect(restored.requiredPerDay, const Duration(hours: 8));
      expect(restored.workingWeekdays, Settings.defaultWorkingWeekdays);
      expect(restored.freeDays, isEmpty);
    });

    test('drops wrongly-typed members inside the lists', () {
      final restored = Settings.fromJson(<String, dynamic>{
        'workingWeekdays': <dynamic>[1, 'two', 3],
        'freeDays': <dynamic>['2026-12-25', 7],
      });
      expect(restored.workingWeekdays, <int>{1, 3});
      expect(restored.freeDays, <String>{'2026-12-25'});
    });
  });
}
