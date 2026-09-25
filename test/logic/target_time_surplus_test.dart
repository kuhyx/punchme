import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/logic/surplus.dart';
import 'package:punchme/logic/target_time.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/settings.dart';

import 'target_time_fixtures.dart';

void main() {
  // Plain Mon-Fri at 8h. Week of Mon 2026-09-14; check-in Tue 15th 09:00.
  const settings = Settings();
  final tuesday9am = DateTime(2026, 9, 15, 9);

  group('an all-green surplus shortens today', () {
    test('spreads over the week left when that keeps the cut small', () {
      // History starts Monday, so all three cards are +1h. Tue-Fri is 4 days
      // => 15m off today.
      final target = targetForToday(
        entries: <DayEntry>[logged('2026-09-14', const Duration(hours: 9))],
        settings: settings,
        checkIn: tuesday9am,
      )!;
      expect(target.level, DeficitLevel.none);
      expect(target.surplus, const Duration(hours: 1));
      expect(target.tightest, Horizon.week);
      expect(target.surplusSpread, Horizon.week);
      expect(target.spreadOver, 4);
      expect(target.surplusCapped, isFalse);
      expect(target.share, const Duration(hours: 7, minutes: 45));
      expect(target.checkOutAt, DateTime(2026, 9, 15, 16, 45));
    });

    test('moves to the month when the week would cut over 1h30m', () {
      // +7h over 4 days is 1h45m a day: too much. 12 working days left in
      // September => 35m.
      final target = targetForToday(
        entries: <DayEntry>[logged('2026-09-14', const Duration(hours: 15))],
        settings: settings,
        checkIn: tuesday9am,
      )!;
      expect(target.surplusSpread, Horizon.month);
      expect(target.spreadOver, 12);
      expect(target.share, const Duration(hours: 7, minutes: 25));
    });

    test('moves to the year when the month would too', () {
      // Mon-Thu at 13h: +20h on every card by Friday. Week (1 day) and month
      // (9 days) both cut over 1h30m; 75 working days left in 2026 => 16m.
      final target = targetForToday(
        entries: <DayEntry>[
          for (final key in [
            '2026-09-14',
            '2026-09-15',
            '2026-09-16',
            '2026-09-17',
          ])
            logged(key, const Duration(hours: 13)),
        ],
        settings: settings,
        checkIn: DateTime(2026, 9, 18, 9),
      )!;
      expect(target.surplus, const Duration(hours: 20));
      expect(target.surplusSpread, Horizon.year);
      expect(target.spreadOver, 75);
      expect(target.share, const Duration(hours: 7, minutes: 44));
    });

    test('caps the cut at 1h30m when even the year is too short', () {
      // Mon-Wed 28-30 Dec at 10h: +6h, and 31 Dec is the year's last day.
      final target = targetForToday(
        entries: <DayEntry>[
          logged('2026-12-28', const Duration(hours: 10)),
          logged('2026-12-29', const Duration(hours: 10)),
          logged('2026-12-30', const Duration(hours: 10)),
        ],
        settings: settings,
        checkIn: DateTime(2026, 12, 31, 9),
      )!;
      expect(target.surplusSpread, Horizon.year);
      expect(target.spreadOver, 1);
      expect(target.surplusCapped, isTrue);
      expect(target.share, const Duration(hours: 6, minutes: 30));
      expect(target.checkOutAt, DateTime(2026, 12, 31, 15, 30));
    });

    test('spends only the smallest surplus, so no card goes red', () {
      // Last week +5h (month), this Monday +1h (week): the week is tightest.
      final target = targetForToday(
        entries: <DayEntry>[
          ...week('2026-09-07', const Duration(hours: 9)),
          logged('2026-09-14', const Duration(hours: 9)),
        ],
        settings: settings,
        checkIn: tuesday9am,
      )!;
      expect(target.surplus, const Duration(hours: 1));
      expect(target.tightest, Horizon.week);
      expect(target.share, const Duration(hours: 7, minutes: 45));
    });

    test('rounds the cut down, never up', () {
      // 10m over 4 days is 2m30s: 2m off, so the card stays at +2m, not -2m.
      final target = targetForToday(
        entries: <DayEntry>[
          logged('2026-09-14', const Duration(hours: 8, minutes: 10)),
        ],
        settings: settings,
        checkIn: tuesday9am,
      )!;
      expect(target.share, const Duration(hours: 7, minutes: 58));
    });

    test('never goes below zero on a short required day', () {
      final short = settings.copyWith(requiredPerDay: const Duration(hours: 1));
      final checkIn = DateTime(2026, 12, 31, 9);
      final target = targetForToday(
        entries: <DayEntry>[
          logged('2026-12-28', const Duration(hours: 3)),
          logged('2026-12-29', const Duration(hours: 3)),
          logged('2026-12-30', const Duration(hours: 3)),
        ],
        settings: short,
        checkIn: checkIn,
      )!;
      expect(target.surplusCapped, isTrue);
      expect(target.share, Duration.zero);
      expect(target.checkOutAt, checkIn);
    });
  });

  group('no surplus to spend', () {
    test('a red card still wins over green ones', () {
      // Last week 10h short, this Monday +1h: week green, month 9h red.
      final target = targetForToday(
        entries: <DayEntry>[
          ...week('2026-09-07', const Duration(hours: 6)),
          logged('2026-09-14', const Duration(hours: 9)),
        ],
        settings: settings,
        checkIn: tuesday9am,
      )!;
      expect(target.level, DeficitLevel.month);
      expect(target.surplus, Duration.zero);
      expect(target.tightest, isNull);
      expect(target.share, const Duration(hours: 10, minutes: 15));
    });

    test('a fresh week at zero keeps the day plain', () {
      // Every card but the week is ahead; the week starts at 0 on Monday.
      final target = targetForToday(
        entries: week('2026-09-14', const Duration(hours: 9)),
        settings: settings,
        checkIn: DateTime(2026, 9, 21, 9),
      )!;
      expect(target.level, DeficitLevel.none);
      expect(target.surplus, Duration.zero);
      expect(target.share, const Duration(hours: 8));
    });
  });
}
