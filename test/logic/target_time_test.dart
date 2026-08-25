import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/logic/target_time.dart';
import 'package:punchme/models/day_entry.dart';
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

  DayEntry logged(String key, Duration length, {int startHour = 9}) {
    final checkIn = DateTime.parse(key).add(Duration(hours: startHour));
    return DayEntry(
      dateKey: key,
      checkIn: checkIn,
      checkOut: checkIn.add(length),
    );
  }

  group("kuhy's worked example", () {
    // Logged 8h23m on Tuesday; checking in Wednesday 09:00 leaves 2 working
    // days (Wed, Thu) and 24h - 8h23m = 15h37m, so 7h48m30s -> 7h49m rounded.
    final tuesday = logged(
      '2026-08-25',
      const Duration(hours: 8, minutes: 23),
    );
    final wednesday9am = DateTime(2026, 8, 26, 9);

    test('splits the remaining week across the days left', () {
      final target = targetForToday(
        entries: <DayEntry>[tuesday],
        settings: settings,
        checkIn: wednesday9am,
      )!;
      expect(target.workingDaysLeft, 2);
      expect(target.remainingThisWeek, const Duration(hours: 15, minutes: 37));
      expect(target.share, const Duration(hours: 7, minutes: 49));
    });

    test('turns the share into a check-out time', () {
      final target = targetForToday(
        entries: <DayEntry>[tuesday],
        settings: settings,
        checkIn: wednesday9am,
      )!;
      expect(target.checkOutAt, DateTime(2026, 8, 26, 16, 49));
    });
  });

  group('working days left', () {
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

  group('remaining this week', () {
    test('is the full quota before anything is logged', () {
      expect(
        remainingThisWeek(
          entries: const <DayEntry>[],
          settings: settings,
          now: DateTime(2026, 8, 25, 9),
        ),
        const Duration(hours: 24),
      );
    });

    test('excludes today, which is the day being planned', () {
      final today = logged('2026-08-25', const Duration(hours: 5));
      expect(
        remainingThisWeek(
          entries: <DayEntry>[today],
          settings: settings,
          now: DateTime(2026, 8, 25, 15),
        ),
        const Duration(hours: 24),
      );
    });

    test('never goes negative when the week is over-worked', () {
      final big = logged('2026-08-25', const Duration(hours: 30));
      expect(
        remainingThisWeek(
          entries: <DayEntry>[big],
          settings: settings,
          now: DateTime(2026, 8, 26, 9),
        ),
        Duration.zero,
      );
    });

    test('ignores days from a previous week', () {
      final lastWeek = logged('2026-08-18', const Duration(hours: 8));
      expect(
        remainingThisWeek(
          entries: <DayEntry>[lastWeek],
          settings: settings,
          now: DateTime(2026, 8, 25, 9),
        ),
        const Duration(hours: 24),
      );
    });

    test('a forgotten check-out banks nothing', () {
      final open = DayEntry(
        dateKey: '2026-08-25',
        checkIn: DateTime(2026, 8, 25, 9),
      );
      expect(
        remainingThisWeek(
          entries: <DayEntry>[open],
          settings: settings,
          now: DateTime(2026, 8, 26, 9),
        ),
        const Duration(hours: 24),
      );
    });
  });

  group('no target to show', () {
    test('on a non-working day with none left', () {
      expect(
        targetForToday(
          entries: const <DayEntry>[],
          settings: settings,
          checkIn: DateTime(2026, 8, 28, 9), // Friday
        ),
        isNull,
      );
    });

    test('once the week is fully banked', () {
      final full = <DayEntry>[
        logged('2026-08-25', const Duration(hours: 24)),
      ];
      expect(
        targetForToday(
          entries: full,
          settings: settings,
          checkIn: DateTime(2026, 8, 26, 9),
        ),
        isNull,
      );
    });
  });

  test('a plain 8h Mon-Fri week gives a plain 8h day', () {
    final target = targetForToday(
      entries: const <DayEntry>[],
      settings: const Settings(),
      checkIn: DateTime(2026, 8, 24, 9), // Monday
    )!;
    expect(target.workingDaysLeft, 5);
    expect(target.share, const Duration(hours: 8));
    expect(target.checkOutAt, DateTime(2026, 8, 24, 17));
  });

  test('rounds to the nearest minute, not down', () {
    // 3 days left, 1 second short of a clean split: must not lose a minute.
    final target = targetForToday(
      entries: const <DayEntry>[],
      settings: const Settings().copyWith(
        workingWeekdays: const <int>{
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
        },
        requiredPerDay: const Duration(hours: 8, minutes: 20),
      ),
      checkIn: DateTime(2026, 8, 24, 9),
    )!;
    expect(target.share, const Duration(hours: 8, minutes: 20));
  });
}
