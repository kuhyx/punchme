import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/logic/target_time.dart';
import 'package:punchme/models/settings.dart';

void main() {
  // Tue/Wed/Thu at 8h => a 24h week.
  final settings = const Settings().copyWith(
    workingWeekdays: const <int>{
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
    },
  );

  group('working days left in the week', () {
    test('counts today when today is a working day', () {
      // Tuesday: Tue, Wed, Thu all still to come.
      expect(
        workingDaysLeftInWeek(now: DateTime(2026, 8, 25), settings: settings),
        3,
      );
    });

    test('shrinks as the week goes on', () {
      expect(
        workingDaysLeftInWeek(now: DateTime(2026, 8, 26), settings: settings),
        2,
      );
      expect(
        workingDaysLeftInWeek(now: DateTime(2026, 8, 27), settings: settings),
        1,
      );
    });

    test('is zero once the working days are behind you', () {
      // Friday, with only Tue/Wed/Thu configured.
      expect(
        workingDaysLeftInWeek(now: DateTime(2026, 8, 28), settings: settings),
        0,
      );
    });

    test('skips a free day', () {
      final withHoliday = settings.copyWith(
        freeDays: const <String>{'2026-08-26'},
      );
      expect(
        workingDaysLeftInWeek(
          now: DateTime(2026, 8, 25),
          settings: withHoliday,
        ),
        2,
      );
    });
  });

  group('working days left in the month', () {
    test('counts today through the last day of the month', () {
      // Tue 15 Sep 2026, Mon-Fri: 15-18, 21-25, 28-30.
      expect(
        workingDaysLeftInMonth(
          now: DateTime(2026, 9, 15),
          settings: const Settings(),
        ),
        12,
      );
    });

    test('skips a free day', () {
      expect(
        workingDaysLeftInMonth(
          now: DateTime(2026, 9, 15),
          settings: const Settings().copyWith(
            freeDays: const <String>{'2026-09-30'},
          ),
        ),
        11,
      );
    });

    test('is one on the last working day of the month', () {
      expect(
        workingDaysLeftInMonth(
          now: DateTime(2026, 9, 30),
          settings: const Settings(),
        ),
        1,
      );
    });
  });
}
