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

  group('computeBalance', () {
    test('Monday morning reads zero, not a full day behind', () {
      final monday9am = DateTime(2026, 8, 24, 9, 30);
      final balance = computeBalance(
        entries: const <DayEntry>[],
        settings: settings,
        from: DateTime(2026, 8, 24),
        to: DateTime(2026, 8, 31),
        now: monday9am,
      );
      expect(balance.expected, Duration.zero);
      expect(balance.worked, Duration.zero);
      expect(balance.difference, Duration.zero);
      expect(balance.isPositive, isTrue);
    });

    test('a full completed day nets out to zero', () {
      final balance = computeBalance(
        entries: <DayEntry>[worked(DateTime(2026, 8, 24))],
        settings: settings,
        from: DateTime(2026, 8, 24),
        to: DateTime(2026, 8, 31),
        now: DateTime(2026, 8, 25, 9),
      );
      expect(balance.worked, const Duration(hours: 8));
      expect(balance.expected, const Duration(hours: 8));
      expect(balance.difference, Duration.zero);
    });

    test('a short day is a shortfall', () {
      final balance = computeBalance(
        entries: <DayEntry>[worked(DateTime(2026, 8, 24), hours: 6)],
        settings: settings,
        from: DateTime(2026, 8, 24),
        to: DateTime(2026, 8, 31),
        now: DateTime(2026, 8, 25, 9),
      );
      expect(balance.difference, const Duration(hours: -2));
      expect(balance.isPositive, isFalse);
    });

    test('a long day is a surplus', () {
      final balance = computeBalance(
        entries: <DayEntry>[worked(DateTime(2026, 8, 24), hours: 10)],
        settings: settings,
        from: DateTime(2026, 8, 24),
        to: DateTime(2026, 8, 31),
        now: DateTime(2026, 8, 25, 9),
      );
      expect(balance.difference, const Duration(hours: 2));
      expect(balance.isPositive, isTrue);
    });

    test('a forgotten check-out on a PAST day counts as zero, not elapsed', () {
      // The whole point: without this rule an open Monday read from Friday
      // would report roughly +96h of surplus.
      final open = DayEntry(
        dateKey: '2026-08-24',
        checkIn: DateTime(2026, 8, 24, 9),
      );
      final balance = computeBalance(
        entries: <DayEntry>[open],
        settings: settings,
        from: DateTime(2026, 8, 24),
        to: DateTime(2026, 8, 31),
        now: DateTime(2026, 8, 28, 9),
      );
      expect(balance.worked, Duration.zero);
      expect(balance.expected, const Duration(hours: 32)); // Mon-Thu
      expect(balance.difference, const Duration(hours: -32));
    });

    test("today's open session is reported separately, not as worked", () {
      final now = DateTime(2026, 8, 25, 13);
      final today = DayEntry(
        dateKey: '2026-08-25',
        checkIn: DateTime(2026, 8, 25, 9),
      );
      final balance = computeBalance(
        entries: <DayEntry>[today],
        settings: settings,
        from: DateTime(2026, 8, 25),
        to: DateTime(2026, 8, 31),
        now: now,
      );
      expect(balance.todaySoFar, const Duration(hours: 4));
      expect(balance.worked, Duration.zero);
      expect(balance.expected, Duration.zero);
    });

    test("today's closed session counts as worked, not just as today", () {
      // Once checked out the day is over, so its hours are banked and the
      // day is expected too. (Before 2026-08-25 `worked` stayed at zero
      // here, which made a finished day read as "0h 00m of 0h 00m".)
      final balance = computeBalance(
        entries: <DayEntry>[worked(DateTime(2026, 8, 25), hours: 7)],
        settings: settings,
        from: DateTime(2026, 8, 25),
        to: DateTime(2026, 8, 31),
        now: DateTime(2026, 8, 25, 18),
      );
      expect(balance.todaySoFar, const Duration(hours: 7));
      expect(balance.worked, const Duration(hours: 7));
      expect(balance.expected, const Duration(hours: 8));
      expect(balance.difference, const Duration(hours: -1));
    });

    test('an overnight session counts in full against its check-in day', () {
      // In 22:00 Monday, out 02:00 Tuesday => 4h, filed under Monday.
      final checkIn = DateTime(2026, 8, 24, 22);
      final overnight = DayEntry(
        dateKey: localDateKey(checkIn),
        checkIn: checkIn,
        checkOut: DateTime(2026, 8, 25, 2),
      );
      final balance = computeBalance(
        entries: <DayEntry>[overnight],
        settings: settings,
        from: DateTime(2026, 8, 24),
        to: DateTime(2026, 8, 31),
        now: DateTime(2026, 8, 25, 9),
      );
      expect(overnight.dateKey, '2026-08-24');
      expect(balance.worked, const Duration(hours: 4));
    });

    test('entries outside the period are ignored', () {
      final balance = computeBalance(
        entries: <DayEntry>[
          worked(DateTime(2026, 8, 17)), // before `from`
          worked(DateTime(2026, 8, 24)),
          worked(DateTime(2026, 9, 7)), // after `now`
        ],
        settings: settings,
        from: DateTime(2026, 8, 24),
        to: DateTime(2026, 8, 31),
        now: DateTime(2026, 8, 25, 9),
      );
      expect(balance.worked, const Duration(hours: 8));
    });

    test('free days reduce what is expected', () {
      final withHoliday = settings.copyWith(
        freeDays: const <String>{'2026-08-24'},
      );
      final balance = computeBalance(
        entries: const <DayEntry>[],
        settings: withHoliday,
        from: DateTime(2026, 8, 24),
        to: DateTime(2026, 8, 31),
        now: DateTime(2026, 8, 25, 9),
      );
      expect(balance.expected, Duration.zero);
    });
  });
}
