import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/ui/history/day_editor.dart';
import 'package:punchme/ui/home/home_screen.dart';

import '../../support/fake_day_repository.dart';

/// "Edit today's times", directly under the big button.
void main() {
  DateTime now() => DateTime(2026, 8, 25, 12);

  FakeDayRepository openToday() => FakeDayRepository(
    days: <DayEntry>[
      DayEntry(dateKey: '2026-08-25', checkIn: DateTime(2026, 8, 25, 9)),
    ],
  );

  Future<void> pumpHome(WidgetTester tester, FakeDayRepository repo) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(repository: repo, now: now),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openEditor(WidgetTester tester) async {
    await tester.tap(find.text("Edit today's times"));
    await tester.pumpAndSettle();
  }

  testWidgets('is hidden before the first punch of the day', (tester) async {
    await pumpHome(tester, FakeDayRepository());
    expect(find.text("Edit today's times"), findsNothing);
  });

  testWidgets('opens the day editor on today', (tester) async {
    await pumpHome(tester, openToday());
    await openEditor(tester);
    expect(find.byType(DayEditor), findsOneWidget);
    expect(find.text('2026-08-25'), findsOneWidget);
  });

  testWidgets('Cancel writes nothing', (tester) async {
    final repo = openToday();
    await pumpHome(tester, repo);
    await openEditor(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.savedDays, isEmpty);
    expect(repo.deletedKeys, isEmpty);
  });

  testWidgets('Save writes today back', (tester) async {
    final repo = openToday();
    await pumpHome(tester, repo);
    await openEditor(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.savedDays.single.dateKey, '2026-08-25');
  });

  testWidgets('Delete clears today and hides the button again', (tester) async {
    final repo = openToday();
    await pumpHome(tester, repo);
    await openEditor(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repo.deletedKeys, <String>['2026-08-25']);
    expect(find.text('CHECK IN'), findsOneWidget);
    expect(find.text("Edit today's times"), findsNothing);
  });
}
