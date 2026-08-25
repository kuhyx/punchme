import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/ui/history/history_screen.dart';
import 'package:punchme/ui/home/home_screen.dart';
import 'package:punchme/ui/settings/settings_screen.dart';
import 'package:punchme/ui/stats/stats_screen.dart';

import '../../support/fake_day_repository.dart';

void main() {
  DateTime now() => DateTime(2026, 8, 25, 12);

  Future<void> share({
    required String fileName,
    required String contents,
    required String subject,
  }) async {}

  Future<void> pumpHome(WidgetTester tester, FakeDayRepository repo) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(repository: repo, now: now, share: share),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens Statistics and comes back', (tester) async {
    await pumpHome(tester, FakeDayRepository());

    await tester.tap(find.byTooltip('Statistics'));
    await tester.pumpAndSettle();
    expect(find.byType(StatsScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('CHECK IN'), findsOneWidget);
  });

  testWidgets('opens History and comes back', (tester) async {
    await pumpHome(tester, FakeDayRepository());

    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('CHECK IN'), findsOneWidget);
  });

  testWidgets('opens Settings and comes back', (tester) async {
    await pumpHome(tester, FakeDayRepository());

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('CHECK IN'), findsOneWidget);
  });

  testWidgets('an edit made in History is reflected on return', (tester) async {
    final repo = FakeDayRepository(
      days: <DayEntry>[
        DayEntry(
          dateKey: '2026-08-25',
          checkIn: DateTime(2026, 8, 25, 9),
          checkOut: DateTime(2026, 8, 25, 17),
        ),
      ],
    );
    await pumpHome(tester, repo);
    expect(find.text('CHECKED OUT'), findsOneWidget);

    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026-08-25'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Home reloaded, so the deleted day is gone from the button state too.
    expect(find.text('CHECK IN'), findsOneWidget);
  });
}
