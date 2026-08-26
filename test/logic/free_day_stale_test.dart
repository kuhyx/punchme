import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/logic/balance.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/settings.dart';

void main() {
  // Mon-Thu at 8h. 2026-08-03 is a Monday, so the week runs 03..09.
  const monday = '2026-08-03';
  const workingMonToThu = <int>{
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
  };

  const withMondayFree = Settings(
    workingWeekdays: workingMonToThu,
    freeDays: <String>{monday},
  );

  // The same settings with Monday dropped from the working week. The free day
  // is deliberately left in place: that is the state under test.
  const mondayNotWorked = Settings(
    workingWeekdays: <int>{
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
    },
    freeDays: <String>{monday},
  );

  const noFreeDays = Settings(
    workingWeekdays: <int>{
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
    },
  );

  Duration expectedOver(DateTime from, DateTime to, Settings settings) =>
      settings.requiredPerDay *
      completedWorkingDays(from: from, to: to, settings: settings);

  group('a free day whose weekday stops being worked', () {
    test('survives the working-day change', () {
      expect(mondayNotWorked.freeDays, contains(monday));
    });

    test('counts for nothing once its weekday is dropped', () {
      // Week, month and year: the stale day must not shrink any of them.
      final periods = <List<DateTime>>[
        <DateTime>[DateTime(2026, 8, 3), DateTime(2026, 8, 10)],
        <DateTime>[DateTime(2026, 8), DateTime(2026, 9)],
        <DateTime>[DateTime(2026), DateTime(2027)],
      ];
      for (final period in periods) {
        expect(
          expectedOver(period[0], period[1], mondayNotWorked),
          expectedOver(period[0], period[1], noFreeDays),
          reason: 'a stale free day must not change ${period[0]}..${period[1]}',
        );
      }
    });

    test('counts again when its weekday comes back', () {
      final from = DateTime(2026, 8, 3);
      final to = DateTime(2026, 8, 10);
      const mondayWorkedNoneFree = Settings(workingWeekdays: workingMonToThu);
      // Mon-Thu is four working days; re-enabling Monday makes the still-stored
      // free day bite again, taking the week back to three.
      expect(
        expectedOver(from, to, withMondayFree),
        expectedOver(from, to, mondayWorkedNoneFree) - const Duration(hours: 8),
      );
    });

    test('is not a working day in either configuration', () {
      expect(isWorkingDay(monday, withMondayFree), isFalse);
      expect(isWorkingDay(monday, mondayNotWorked), isFalse);
    });

    test('leaves the balance identical to never having existed', () {
      final entries = <DayEntry>[
        DayEntry(
          dateKey: '2026-08-04',
          checkIn: DateTime(2026, 8, 4, 9),
          checkOut: DateTime(2026, 8, 4, 17),
        ),
      ];
      Balance balanceWith(Settings settings) => computeBalance(
        entries: entries,
        settings: settings,
        from: DateTime(2026, 8, 3),
        to: DateTime(2026, 8, 10),
        now: DateTime(2026, 8, 10, 12),
      );

      expect(
        balanceWith(mondayNotWorked).difference,
        balanceWith(noFreeDays).difference,
      );
    });
  });
}
