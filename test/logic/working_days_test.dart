import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/logic/balance.dart';
import 'package:punchme/models/settings.dart';

void main() {
  const settings = Settings();

  group('isWorkingDay', () {
    test('weekdays count, weekends do not', () {
      expect(isWorkingDay('2026-08-24', settings), isTrue); // Monday
      expect(isWorkingDay('2026-08-29', settings), isFalse); // Saturday
      expect(isWorkingDay('2026-08-30', settings), isFalse); // Sunday
    });

    test('an explicit free day overrides the weekday', () {
      final withHoliday = settings.copyWith(
        freeDays: const <String>{'2026-08-24'},
      );
      expect(isWorkingDay('2026-08-24', withHoliday), isFalse);
    });
  });

  group('completedWorkingDays', () {
    test('excludes the end date, so today never counts', () {
      // Mon 24th .. Wed 26th exclusive => Mon + Tue = 2.
      expect(
        completedWorkingDays(
          from: DateTime(2026, 8, 24),
          to: DateTime(2026, 8, 26),
          settings: settings,
        ),
        2,
      );
    });

    test('is zero when the range is empty', () {
      expect(
        completedWorkingDays(
          from: DateTime(2026, 8, 24),
          to: DateTime(2026, 8, 24),
          settings: settings,
        ),
        0,
      );
    });

    test('skips weekends', () {
      // Mon 24th .. Mon 31st exclusive => five weekdays.
      expect(
        completedWorkingDays(
          from: DateTime(2026, 8, 24),
          to: DateTime(2026, 8, 31),
          settings: settings,
        ),
        5,
      );
    });

    test('counts correctly across a DST boundary', () {
      // Europe/Warsaw falls back on 2026-10-25 (a Sunday). Oct 19..Oct 26
      // exclusive is five weekdays; a Duration-based loop would drift here.
      expect(
        completedWorkingDays(
          from: DateTime(2026, 10, 19),
          to: DateTime(2026, 10, 26),
          settings: settings,
        ),
        5,
      );
    });
  });
}
