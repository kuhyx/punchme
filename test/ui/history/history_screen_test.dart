import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/ui/history/history_screen.dart';

import '../../support/fake_day_repository.dart';

void main() {
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
        home: HistoryScreen(repository: repo, now: now),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('listing', () {
    testWidgets('says so when nothing is recorded', (tester) async {
      await pump(tester, FakeDayRepository());
      expect(find.text('No days recorded yet'), findsOneWidget);
    });

    testWidgets('lists a recorded day with its times and total', (
      tester,
    ) async {
      await pump(
        tester,
        FakeDayRepository(days: <DayEntry>[closed('2026-08-24')]),
      );
      expect(find.text('2026-08-24'), findsOneWidget);
      expect(find.text('09:00 – 17:00'), findsOneWidget);
      expect(find.text('8h 00m'), findsOneWidget);
    });

    testWidgets('flags a forgotten check-out instead of guessing', (
      tester,
    ) async {
      await pump(
        tester,
        FakeDayRepository(
          days: <DayEntry>[
            DayEntry(dateKey: '2026-08-24', checkIn: DateTime(2026, 8, 24, 9)),
          ],
        ),
      );
      expect(find.textContaining('missing check-out'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('shows the newest day first', (tester) async {
      await pump(
        tester,
        FakeDayRepository(
          days: <DayEntry>[closed('2026-08-24'), closed('2026-08-25')],
        ),
      );
      final first = tester.getTopLeft(find.text('2026-08-25'));
      final second = tester.getTopLeft(find.text('2026-08-24'));
      expect(first.dy, lessThan(second.dy));
    });
  });

  group('editing', () {
    testWidgets('opens an editor showing the day', (tester) async {
      await pump(
        tester,
        FakeDayRepository(days: <DayEntry>[closed('2026-08-24')]),
      );

      await tester.tap(find.text('2026-08-24'));
      await tester.pumpAndSettle();

      expect(find.text('Check in'), findsOneWidget);
      expect(find.text('Check out'), findsOneWidget);
      expect(find.text('Total 8h 00m'), findsOneWidget);
    });

    testWidgets('cancelling changes nothing', (tester) async {
      final repo = FakeDayRepository(days: <DayEntry>[closed('2026-08-24')]);
      await pump(tester, repo);

      await tester.tap(find.text('2026-08-24'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repo.savedDays, isEmpty);
      expect(repo.deletedKeys, isEmpty);
    });

    testWidgets('saving writes the day back', (tester) async {
      final repo = FakeDayRepository(days: <DayEntry>[closed('2026-08-24')]);
      await pump(tester, repo);

      await tester.tap(find.text('2026-08-24'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repo.savedDays.single.dateKey, '2026-08-24');
    });

    testWidgets('deleting removes the day', (tester) async {
      final repo = FakeDayRepository(days: <DayEntry>[closed('2026-08-24')]);
      await pump(tester, repo);

      await tester.tap(find.text('2026-08-24'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(repo.deletedKeys, <String>['2026-08-24']);
      expect(find.text('No days recorded yet'), findsOneWidget);
    });
  });

  group('adding a missing day', () {
    testWidgets('picks a date then opens the editor', (tester) async {
      final repo = FakeDayRepository();
      await pump(tester, repo);

      await tester.tap(find.byTooltip('Add a missing day'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // The editor opens on the picked day, defaulting to a 09:00 start.
      expect(find.text('2026-08-25'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repo.savedDays.single.dateKey, '2026-08-25');
      expect(repo.savedDays.single.checkIn.hour, 9);
    });

    testWidgets('cancelling the date picker adds nothing', (tester) async {
      final repo = FakeDayRepository();
      await pump(tester, repo);

      await tester.tap(find.byTooltip('Add a missing day'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repo.savedDays, isEmpty);
    });
  });

  group('re-keying a day', () {
    testWidgets('moving the check-in to another day deletes the old key', (
      tester,
    ) async {
      // An overnight day keyed 2026-08-24 that starts at 22:00. Setting the
      // check-in to 01:00 leaves it on the 24th, so to force a re-key we
      // build the editor directly against an entry whose stored key is stale.
      final stale = DayEntry(
        dateKey: '2026-08-23', // deliberately not the check-in's date
        checkIn: DateTime(2026, 8, 24, 9),
        checkOut: DateTime(2026, 8, 24, 17),
      );
      final repo = FakeDayRepository(days: <DayEntry>[stale]);
      await pump(tester, repo);

      await tester.tap(find.text('2026-08-23'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // The editor re-keys to the check-in's real date, and the stale key
      // must be removed rather than left as a duplicate.
      expect(repo.savedDays.single.dateKey, '2026-08-24');
      expect(repo.deletedKeys, <String>['2026-08-23']);
      expect(await repo.loadDays(), hasLength(1));
    });
  });
}
