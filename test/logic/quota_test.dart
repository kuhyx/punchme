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

  group('quota is the whole period, not just the elapsed part', () {
    // The reported case: Tue/Wed/Thu at 8h, on the Tuesday, must read
    // "Worked 8h 23m of 24h 00m" -- not "of 8h 00m".
    final tueWedThu = const Settings().copyWith(
      workingWeekdays: const <int>{
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
      },
    );
    final checkIn = DateTime(2026, 8, 25, 9); // a Tuesday
    final closedTuesday = DayEntry(
      dateKey: '2026-08-25',
      checkIn: checkIn,
      checkOut: checkIn.add(const Duration(hours: 8, minutes: 23)),
    );

    test('Tuesday of a Tue/Wed/Thu week reads 8h 23m of 24h', () {
      final balance = computeBalance(
        entries: <DayEntry>[closedTuesday],
        settings: tueWedThu,
        from: DateTime(2026, 8, 24),
        to: DateTime(2026, 8, 31),
        now: DateTime(2026, 8, 25, 18),
      );
      expect(balance.worked, const Duration(hours: 8, minutes: 23));
      expect(balance.quota, const Duration(hours: 24));
      // The chip still compares against elapsed days, so it reads +23m
      // rather than turning into a 15h 37m deficit.
      expect(balance.expected, const Duration(hours: 8));
      expect(balance.difference, const Duration(minutes: 23));
      expect(balance.isPositive, isTrue);
    });

    test('the quota holds steady as the week elapses', () {
      // Same week, now the Thursday: `expected` has grown to 24h but the
      // denominator has not moved.
      final balance = computeBalance(
        entries: <DayEntry>[closedTuesday],
        settings: tueWedThu,
        from: DateTime(2026, 8, 24),
        to: DateTime(2026, 8, 31),
        now: DateTime(2026, 8, 27, 18), // Thursday
      );
      expect(balance.quota, const Duration(hours: 24));
      expect(balance.expected, const Duration(hours: 16)); // Tue + Wed
    });

    test('a full Mon-Fri week quotes 40h from Monday morning', () {
      final balance = computeBalance(
        entries: <DayEntry>[
          DayEntry(
            dateKey: '2026-08-24',
            checkIn: DateTime(2026, 8, 24, 9),
          ),
        ],
        settings: settings,
        from: DateTime(2026, 8, 24),
        to: DateTime(2026, 8, 31),
        now: DateTime(2026, 8, 24, 9, 30),
      );
      expect(balance.quota, const Duration(hours: 40));
      expect(balance.expected, Duration.zero);
    });

    test('a free day still ahead of you shrinks the quota now', () {
      // Thursday 27th booked off: the week quotes 32h, not 40h, on Monday.
      final withLeave = settings.copyWith(
        freeDays: const <String>{'2026-08-27'},
      );
      final balance = computeBalance(
        entries: <DayEntry>[
          DayEntry(
            dateKey: '2026-08-24',
            checkIn: DateTime(2026, 8, 24, 9),
          ),
        ],
        settings: withLeave,
        from: DateTime(2026, 8, 24),
        to: DateTime(2026, 8, 31),
        now: DateTime(2026, 8, 24, 9, 30),
      );
      expect(balance.quota, const Duration(hours: 32));
    });

    test('the quota starts at the first record, not the period start', () {
      // First ever record is Wednesday, so the week quotes Wed-Fri = 24h.
      // Without the clamp this would bill 40h, including the two days
      // before the app was ever installed.
      final balance = computeBalance(
        entries: <DayEntry>[worked(DateTime(2026, 8, 26))],
        settings: settings,
        from: DateTime(2026, 8, 24), // Monday
        to: DateTime(2026, 8, 31),
        now: DateTime(2026, 8, 26, 18),
      );
      expect(balance.quota, const Duration(hours: 24)); // Wed, Thu, Fri
    });

    test('an empty history quotes zero rather than the whole period', () {
      final balance = computeBalance(
        entries: const <DayEntry>[],
        settings: settings,
        from: DateTime(2026, 8, 24),
        to: DateTime(2026, 8, 31),
        now: DateTime(2026, 8, 25, 9),
      );
      expect(balance.quota, Duration.zero);
      expect(balance.expected, Duration.zero);
    });
  });

  group('a past period stops at its own end', () {
    test('a later week is neither worked nor quoted against it', () {
      // Asking about the week of 17 August while standing in the week of
      // the 24th: the 24th's hours belong to that week, not this one.
      final balance = computeBalance(
        entries: <DayEntry>[
          worked(DateTime(2026, 8, 18)),
          worked(DateTime(2026, 8, 24)),
        ],
        settings: settings,
        from: DateTime(2026, 8, 17),
        to: DateTime(2026, 8, 24),
        now: DateTime(2026, 8, 25, 12),
      );
      expect(balance.worked, const Duration(hours: 8));
      expect(balance.quota, const Duration(hours: 32)); // Tue-Fri 18-21
    });
  });
}
