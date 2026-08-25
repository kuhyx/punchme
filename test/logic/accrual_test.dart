import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/logic/balance.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/local_date.dart';
import 'package:punchme/models/settings.dart';

/// A closed day worked from [startHour] for [hours].
DayEntry worked(DateTime day, {int startHour = 9, int hours = 8}) {
  final checkIn = DateTime(day.year, day.month, day.day, startHour);
  return DayEntry(
    dateKey: localDateKey(checkIn),
    checkIn: checkIn,
    checkOut: checkIn.add(Duration(hours: hours)),
  );
}

void main() {
  const settings = Settings();

  group('expectation starts at the first recorded day', () {
    test('an empty history owes nothing, even over a whole year', () {
      final balance = computeBalance(
        entries: const <DayEntry>[],
        settings: settings,
        from: DateTime(2026), // 1 January
        to: DateTime(2027),
        now: DateTime(2026, 8, 25, 12),
      );
      expect(balance.expected, Duration.zero);
      expect(balance.difference, Duration.zero);
    });

    test('nothing is owed for working days before the first record', () {
      // First ever record is Mon 24 Aug; the year before it is not a debt.
      final balance = computeBalance(
        entries: <DayEntry>[worked(DateTime(2026, 8, 24))],
        settings: settings,
        from: DateTime(2026),
        to: DateTime(2027),
        now: DateTime(2026, 8, 25, 12),
      );
      expect(balance.expected, const Duration(hours: 8));
      expect(balance.difference, Duration.zero);
    });

    test('the period start still wins when it is the later of the two', () {
      // Recorded back in July, but asking only about this week.
      final balance = computeBalance(
        entries: <DayEntry>[
          worked(DateTime(2026, 7, 6)),
          worked(DateTime(2026, 8, 24)),
        ],
        settings: settings,
        from: DateTime(2026, 8, 24),
        to: DateTime(2026, 8, 31),
        now: DateTime(2026, 8, 25, 12),
      );
      expect(balance.expected, const Duration(hours: 8));
    });

    test('a history of only today owes nothing yet', () {
      final balance = computeBalance(
        entries: <DayEntry>[
          DayEntry(
            dateKey: '2026-08-25',
            checkIn: DateTime(2026, 8, 25, 9),
          ),
        ],
        settings: settings,
        from: DateTime(2026),
        to: DateTime(2027),
        now: DateTime(2026, 8, 25, 12),
      );
      expect(balance.expected, Duration.zero);
      expect(balance.todaySoFar, const Duration(hours: 3));
    });
  });

  group("today, once checked out, counts as worked and as expected", () {
    // Regression: reported from the phone on 2026-08-25. With Tue/Wed/Thu as
    // working days and a full day logged on the Tuesday, every period read
    // "Worked 0h 00m of 0h 00m" -- a finished day was being parked in
    // todaySoFar and left out of both sides of the sum.
    final settings = const Settings().copyWith(
      workingWeekdays: const <int>{
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
      },
    );
    final checkIn = DateTime(2026, 8, 25, 9); // a Tuesday
    final closedToday = DayEntry(
      dateKey: '2026-08-25',
      checkIn: checkIn,
      checkOut: checkIn.add(const Duration(hours: 8, minutes: 23)),
    );

    test('a checked-out today is counted on both sides', () {
      final balance = computeBalance(
        entries: <DayEntry>[closedToday],
        settings: settings,
        from: DateTime(2026, 8, 24), // Monday
        to: DateTime(2026, 8, 31),
        now: DateTime(2026, 8, 25, 18),
      );
      expect(balance.worked, const Duration(hours: 8, minutes: 23));
      expect(balance.expected, const Duration(hours: 8));
      expect(balance.difference, const Duration(minutes: 23));
    });

    test('a still-open today is not counted on either side', () {
      final balance = computeBalance(
        entries: <DayEntry>[
          DayEntry(dateKey: '2026-08-25', checkIn: checkIn),
        ],
        settings: settings,
        from: DateTime(2026, 8, 24),
        to: DateTime(2026, 8, 31),
        now: DateTime(2026, 8, 25, 18),
      );
      expect(balance.worked, Duration.zero);
      expect(balance.expected, Duration.zero);
      expect(balance.todaySoFar, const Duration(hours: 9));
    });

    test('a non-working today is worked but never expected', () {
      // Monday is not a working day here, so hours on it are pure surplus.
      final monday = DateTime(2026, 8, 24, 9);
      final balance = computeBalance(
        entries: <DayEntry>[
          DayEntry(
            dateKey: '2026-08-24',
            checkIn: monday,
            checkOut: monday.add(const Duration(hours: 3)),
          ),
        ],
        settings: settings,
        from: DateTime(2026, 8, 24),
        to: DateTime(2026, 8, 31),
        now: DateTime(2026, 8, 24, 18),
      );
      expect(balance.worked, const Duration(hours: 3));
      expect(balance.expected, Duration.zero);
      expect(balance.difference, const Duration(hours: 3));
    });
  });
}
