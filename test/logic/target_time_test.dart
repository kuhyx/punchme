import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/logic/target_time.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/settings.dart';

import 'target_time_fixtures.dart';

void main() {
  // Plain Mon-Fri at 8h. Week of Mon 2026-09-14; check-in Tue 15th 09:00.
  const settings = Settings();
  final tuesday9am = DateTime(2026, 9, 15, 9);

  group('the first red card wins', () {
    test('a week shortfall lands on today in full', () {
      // kuhy's example: 4 minutes short on Monday => 8h04m on Tuesday.
      final target = targetForToday(
        entries: <DayEntry>[
          logged('2026-09-14', const Duration(hours: 7, minutes: 56)),
        ],
        settings: settings,
        checkIn: tuesday9am,
      )!;
      expect(target.level, DeficitLevel.week);
      expect(target.deficit, const Duration(minutes: 4));
      expect(target.spreadOver, 1);
      expect(target.share, const Duration(hours: 8, minutes: 4));
      expect(target.checkOutAt, DateTime(2026, 9, 15, 17, 4));
      expect(target.isCapped, isFalse);
    });

    test('a month shortfall spreads over the week left', () {
      // Last week 6h a day (10h short), this Monday a full day: the week is
      // green, the month is 10h red, Tue-Fri are 4 days => 2h30m each.
      final target = targetForToday(
        entries: <DayEntry>[
          ...week('2026-09-07', const Duration(hours: 6)),
          logged('2026-09-14', const Duration(hours: 8)),
        ],
        settings: settings,
        checkIn: tuesday9am,
      )!;
      expect(target.level, DeficitLevel.month);
      expect(target.deficit, const Duration(hours: 10));
      expect(target.spreadOver, 4);
      expect(target.share, const Duration(hours: 10, minutes: 30));
      expect(target.checkOutAt, DateTime(2026, 9, 15, 19, 30));
    });

    test('a year shortfall spreads over the month left', () {
      // A short week in August, everything since on target: week and month
      // are green, the year is 10h red, 12 working days left in September.
      final target = targetForToday(
        entries: <DayEntry>[
          ...week('2026-08-24', const Duration(hours: 6)),
          ...week('2026-08-31', const Duration(hours: 8)),
          ...week('2026-09-07', const Duration(hours: 8)),
          logged('2026-09-14', const Duration(hours: 8)),
        ],
        settings: settings,
        checkIn: tuesday9am,
      )!;
      expect(target.level, DeficitLevel.year);
      expect(target.deficit, const Duration(hours: 10));
      expect(target.spreadOver, 12);
      expect(target.share, const Duration(hours: 8, minutes: 50));
      expect(target.checkOutAt, DateTime(2026, 9, 15, 17, 50));
    });

    test('a red week is not double-billed by the red month behind it', () {
      // Both cards red; only the week's 4m is added, not the month's 10h04m.
      final target = targetForToday(
        entries: <DayEntry>[
          ...week('2026-09-07', const Duration(hours: 6)),
          logged('2026-09-14', const Duration(hours: 7, minutes: 56)),
        ],
        settings: settings,
        checkIn: tuesday9am,
      )!;
      expect(target.level, DeficitLevel.week);
      expect(target.share, const Duration(hours: 8, minutes: 4));
    });
  });

  group('never shorter than the required day', () {
    test('a plain week gives a plain day', () {
      final target = targetForToday(
        entries: const <DayEntry>[],
        settings: settings,
        checkIn: DateTime(2026, 9, 14, 9), // Monday, nothing recorded
      )!;
      expect(target.level, DeficitLevel.none);
      expect(target.deficit, Duration.zero);
      expect(target.share, const Duration(hours: 8));
      expect(target.checkOutAt, DateTime(2026, 9, 14, 17));
    });

    test('being ahead does not buy a short day', () {
      final target = targetForToday(
        entries: <DayEntry>[logged('2026-09-14', const Duration(hours: 9))],
        settings: settings,
        checkIn: tuesday9am,
      )!;
      expect(target.level, DeficitLevel.none);
      expect(target.share, const Duration(hours: 8));
    });

    test("today's own open session is not a shortfall", () {
      final target = targetForToday(
        entries: <DayEntry>[
          DayEntry(dateKey: '2026-09-15', checkIn: tuesday9am),
        ],
        settings: settings,
        checkIn: tuesday9am,
      )!;
      expect(target.level, DeficitLevel.none);
      expect(target.share, const Duration(hours: 8));
    });
  });

  test('no target on a non-working day', () {
    expect(
      targetForToday(
        entries: const <DayEntry>[],
        settings: settings,
        checkIn: DateTime(2026, 9, 19, 9), // Saturday
      ),
      isNull,
    );
  });

  test('rounds the slice to the nearest minute, not down', () {
    // 10m short over 4 days is 2m30s a day: 3m, never 2m.
    final target = targetForToday(
      entries: <DayEntry>[
        ...week('2026-09-07', const Duration(hours: 7, minutes: 58)),
        logged('2026-09-14', const Duration(hours: 8)),
      ],
      settings: settings,
      checkIn: tuesday9am,
    )!;
    expect(target.level, DeficitLevel.month);
    expect(target.share, const Duration(hours: 8, minutes: 3));
  });

  group('the midnight cap', () {
    test('stops at 23:59 and reports what did not fit', () {
      // A forgotten Monday check-out banks zero: 8h short, so Tuesday would
      // be 16h — 09:00 + 16h is 01:00, a time the Clock alarm cannot carry.
      final target = targetForToday(
        entries: <DayEntry>[
          DayEntry(dateKey: '2026-09-14', checkIn: DateTime(2026, 9, 14, 9)),
        ],
        settings: settings,
        checkIn: tuesday9am,
      )!;
      expect(target.deficit, const Duration(hours: 8));
      expect(target.isCapped, isTrue);
      expect(target.checkOutAt, DateTime(2026, 9, 15, 23, 59));
      expect(target.share, const Duration(hours: 14, minutes: 59));
      expect(target.uncovered, const Duration(hours: 1, minutes: 1));
    });

    test('leaves a check-out that lands before midnight alone', () {
      final target = targetForToday(
        entries: const <DayEntry>[],
        settings: settings,
        checkIn: DateTime(2026, 9, 15, 15, 59),
      )!;
      expect(target.isCapped, isFalse);
      expect(target.checkOutAt, DateTime(2026, 9, 15, 23, 59));
      expect(target.uncovered, Duration.zero);
    });
  });
}
