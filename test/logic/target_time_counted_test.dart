import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/logic/surplus.dart';
import 'package:punchme/logic/target_time.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/settings.dart';

import 'target_time_fixtures.dart';

/// Cards switched off in Settings are info only: they never move the target.
void main() {
  // Plain Mon-Fri at 8h. Week of Mon 2026-09-14; check-in Tue 15th 09:00.
  final tuesday9am = DateTime(2026, 9, 15, 9);

  // A short day earlier in the month leaves the month and year red while
  // Monday's full day keeps the week exactly on track.
  final monthRedWeekGreen = <DayEntry>[
    logged('2026-09-11', const Duration(hours: 4)),
    logged('2026-09-14', const Duration(hours: 8)),
  ];

  TargetToday target(
    List<DayEntry> entries,
    Set<Horizon> counted, {
    DateTime? checkIn,
  }) => targetForToday(
    entries: entries,
    settings: Settings(countedHorizons: counted),
    checkIn: checkIn ?? tuesday9am,
  )!;

  test('with every card counted, a red month lengthens today', () {
    final t = target(monthRedWeekGreen, Settings.allHorizons);
    expect(t.level, DeficitLevel.month);
    expect(t.deficit, const Duration(hours: 4));
  });

  test('an info-only month and year leave a green week a plain day', () {
    final t = target(monthRedWeekGreen, const <Horizon>{Horizon.week});
    expect(t.level, DeficitLevel.none);
    expect(t.deficit, Duration.zero);
    expect(t.surplus, Duration.zero);
    expect(t.share, const Duration(hours: 8));
  });

  test('an info-only week does not hide a counted year', () {
    final t = target(monthRedWeekGreen, const <Horizon>{Horizon.year});
    expect(t.level, DeficitLevel.year);
  });

  test('a red week counts for nothing when it is info only', () {
    final t = target(<DayEntry>[
      logged('2026-09-14', const Duration(hours: 2)),
    ], const <Horizon>{});
    expect(t.level, DeficitLevel.none);
    expect(t.tightest, isNull);
    expect(t.share, const Duration(hours: 8));
  });

  group('a week-only surplus', () {
    // +7h on Monday; Tue-Fri is 4 days => 1h45m, over the usual 1h30m cap.
    final ahead = <DayEntry>[logged('2026-09-14', const Duration(hours: 15))];

    test('is spent within the week, uncapped', () {
      final t = target(ahead, const <Horizon>{Horizon.week});
      expect(t.tightest, Horizon.week);
      expect(t.surplusSpread, Horizon.week);
      expect(t.spreadOver, 4);
      expect(t.surplusCapped, isFalse);
      expect(t.share, const Duration(hours: 6, minutes: 15));
    });

    test('takes today to zero once the week is covered', () {
      // Mon-Thu at 10h: +8h by Friday, and Friday is the last day left.
      final t = target(
        <DayEntry>[
          for (final key in [
            '2026-09-14',
            '2026-09-15',
            '2026-09-16',
            '2026-09-17',
          ])
            logged(key, const Duration(hours: 10)),
        ],
        const <Horizon>{Horizon.week},
        checkIn: DateTime(2026, 9, 18, 9),
      );
      expect(t.share, Duration.zero);
      expect(t.checkOutAt, DateTime(2026, 9, 18, 9));
    });

    test('still spills to the month when the month counts too', () {
      final t = target(ahead, const <Horizon>{Horizon.week, Horizon.month});
      expect(t.surplusSpread, Horizon.month);
      expect(t.spreadOver, 12);
    });
  });

  test('a month-widest surplus caps at the month, never reaching the year', () {
    final cut = surplusSlice(
      surplus: const Duration(hours: 100),
      now: tuesday9am,
      settings: const Settings(),
      widest: Horizon.month,
    );
    expect(cut.spread, Horizon.month);
    expect(cut.capped, isTrue);
    expect(cut.slice, maxSurplusSlice);
  });
}
