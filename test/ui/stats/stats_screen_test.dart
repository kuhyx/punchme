import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/settings.dart';
import 'package:punchme/ui/stats/balance_card.dart';
import 'package:punchme/ui/stats/stats_screen.dart';

import '../../support/fake_day_repository.dart';

void main() {
  // Tuesday 2026-08-25.
  DateTime now() => DateTime(2026, 8, 25, 12);

  DayEntry closed(String key, {int hours = 8}) {
    final checkIn = DateTime.parse('${key}T09:00:00');
    return DayEntry(
      dateKey: key,
      checkIn: checkIn,
      checkOut: checkIn.add(Duration(hours: hours)),
    );
  }

  Future<void> pump(WidgetTester tester, FakeDayRepository repo) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StatsScreen(repository: repo, now: now),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows a card per period', (tester) async {
    await pump(tester, FakeDayRepository());
    expect(find.byType(BalanceCard), findsNWidgets(3));
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('This year'), findsOneWidget);
  });

  testWidgets('a matching day reads as on track', (tester) async {
    // Monday worked 8h; Tuesday (today) is excluded from the expectation.
    await pump(
      tester,
      FakeDayRepository(days: <DayEntry>[closed('2026-08-24')]),
    );
    expect(find.text('On track'), findsNWidgets(3));
  });

  testWidgets('a short day reads as a shortfall', (tester) async {
    await pump(
      tester,
      FakeDayRepository(days: <DayEntry>[closed('2026-08-24', hours: 6)]),
    );
    expect(find.text('-2h 00m'), findsNWidgets(3));
  });

  testWidgets('a long day reads as a surplus', (tester) async {
    await pump(
      tester,
      FakeDayRepository(days: <DayEntry>[closed('2026-08-24', hours: 10)]),
    );
    expect(find.text('+2h 00m'), findsNWidgets(3));
  });

  testWidgets('an empty history is on track, not deeply negative', (
    tester,
  ) async {
    await pump(tester, FakeDayRepository());
    expect(find.text('On track'), findsNWidgets(3));
  });

  testWidgets("today's open session shows separately", (tester) async {
    await pump(
      tester,
      FakeDayRepository(
        days: <DayEntry>[
          DayEntry(dateKey: '2026-08-25', checkIn: DateTime(2026, 8, 25, 9)),
        ],
      ),
    );
    expect(find.textContaining('Today so far 3h 00m'), findsNWidgets(3));
  });

  testWidgets('reports worked against the whole period quota', (tester) async {
    // Monday worked 8h, viewed on the Tuesday. The denominator is the full
    // period, so the three cards no longer read alike: the week quotes
    // Mon-Fri (40h), the month the rest of August from the first record
    // (48h), and the year the rest of 2026 (752h).
    await pump(
      tester,
      FakeDayRepository(days: <DayEntry>[closed('2026-08-24')]),
    );
    expect(find.textContaining('Worked 8h 00m of 40h 00m'), findsOneWidget);
    expect(find.textContaining('Worked 8h 00m of 48h 00m'), findsOneWidget);
    expect(find.textContaining('Worked 8h 00m of 752h 00m'), findsOneWidget);
  });

  testWidgets('the reported Tue/Wed/Thu week reads 8h 23m of 24h', (
    tester,
  ) async {
    // The case this denominator exists for. Checked out on the Tuesday
    // after 8h 23m: the week is 24h of quota, and the chip still reads the
    // 23 minutes of surplus rather than a 15h 37m deficit.
    await pump(
      tester,
      FakeDayRepository(
        days: <DayEntry>[
          DayEntry(
            dateKey: '2026-08-25',
            checkIn: DateTime(2026, 8, 25, 9),
            checkOut: DateTime(2026, 8, 25, 17, 23),
          ),
        ],
        settings: const Settings().copyWith(
          workingWeekdays: const <int>{
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
          },
        ),
      ),
    );
    // Week and month coincide here: both run Tue 25 - Thu 27 August.
    expect(find.textContaining('Worked 8h 23m of 24h 00m'), findsNWidgets(2));
    expect(find.textContaining('Worked 8h 23m of 456h 00m'), findsOneWidget);
    expect(find.text('+0h 23m'), findsNWidgets(3));
  });

  testWidgets('honours custom settings', (tester) async {
    await pump(
      tester,
      FakeDayRepository(
        days: <DayEntry>[closed('2026-08-24', hours: 6)],
        settings: const Settings().copyWith(
          requiredPerDay: const Duration(hours: 6),
        ),
      ),
    );
    expect(find.text('On track'), findsNWidgets(3));
  });
}
