import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/ui/home/check_button.dart';
import 'package:punchme/ui/home/home_screen.dart';

import '../../support/fake_day_repository.dart';

void main() {
  /// A controllable clock, so the recorded timestamp is exactly assertable.
  late DateTime clock;
  DateTime now() => clock;

  setUp(() => clock = DateTime(2026, 8, 25, 9, 3, 12));

  Future<void> pumpHome(WidgetTester tester, FakeDayRepository repo) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(repository: repo, now: now),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('initial state', () {
    testWidgets('offers CHECK IN when nothing is recorded', (tester) async {
      await pumpHome(tester, FakeDayRepository());
      expect(find.text('CHECK IN'), findsOneWidget);
      expect(find.text('Not checked in today'), findsOneWidget);
    });

    testWidgets('offers CHECK OUT when today is open', (tester) async {
      await pumpHome(
        tester,
        FakeDayRepository(
          days: <DayEntry>[
            DayEntry(dateKey: '2026-08-25', checkIn: DateTime(2026, 8, 25, 9)),
          ],
        ),
      );
      expect(find.text('CHECK OUT'), findsOneWidget);
      expect(find.textContaining('In 09:00'), findsOneWidget);
    });

    testWidgets('shows a sealed day with an Undo action', (tester) async {
      await pumpHome(
        tester,
        FakeDayRepository(
          days: <DayEntry>[
            DayEntry(
              dateKey: '2026-08-25',
              checkIn: DateTime(2026, 8, 25, 9),
              checkOut: DateTime(2026, 8, 25, 17),
            ),
          ],
        ),
      );
      expect(find.text('CHECKED OUT'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect(find.textContaining('Out 17:00'), findsOneWidget);
    });

    testWidgets("ignores yesterday's entry when deciding today", (
      tester,
    ) async {
      await pumpHome(
        tester,
        FakeDayRepository(
          days: <DayEntry>[
            DayEntry(
              dateKey: '2026-08-24',
              checkIn: DateTime(2026, 8, 24, 9),
              checkOut: DateTime(2026, 8, 24, 17),
            ),
          ],
        ),
      );
      expect(find.text('CHECK IN'), findsOneWidget);
    });
  });

  group('commit window', () {
    testWidgets('a tap does not save immediately', (tester) async {
      final repo = FakeDayRepository();
      await pumpHome(tester, repo);

      await tester.tap(find.byType(CheckButton));
      await tester.pump();

      expect(repo.savedDays, isEmpty);
      expect(find.text('tap again to cancel'), findsOneWidget);

      // Let the pending timer finish so the test ends cleanly.
      await tester.pump(commitWindow);
      await tester.pumpAndSettle();
    });

    testWidgets('a second tap cancels, saving nothing', (tester) async {
      final repo = FakeDayRepository();
      await pumpHome(tester, repo);

      await tester.tap(find.byType(CheckButton));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byType(CheckButton));
      await tester.pumpAndSettle();

      expect(repo.savedDays, isEmpty);
      expect(find.text('CHECK IN'), findsOneWidget);
      expect(find.text('tap again to cancel'), findsNothing);
    });

    testWidgets('records the FIRST tap time, not the commit time', (
      tester,
    ) async {
      final repo = FakeDayRepository();
      await pumpHome(tester, repo);
      final tappedAt = clock;

      await tester.tap(find.byType(CheckButton));
      await tester.pump();

      // The wall clock advances while the window runs...
      clock = clock.add(const Duration(seconds: 3));
      await tester.pump(commitWindow);
      await tester.pumpAndSettle();

      // ...but the stored check-in is the moment of the tap.
      expect(repo.savedDays, hasLength(1));
      expect(repo.savedDays.single.checkIn, tappedAt);
      expect(repo.savedDays.single.checkIn, isNot(clock));
    });

    testWidgets('completing the window checks in', (tester) async {
      final repo = FakeDayRepository();
      await pumpHome(tester, repo);

      await tester.tap(find.byType(CheckButton));
      await tester.pump(commitWindow);
      await tester.pumpAndSettle();

      expect(repo.savedDays.single.dateKey, '2026-08-25');
      expect(repo.savedDays.single.isOpen, isTrue);
      expect(find.text('CHECK OUT'), findsOneWidget);
    });

    testWidgets('completing the window while open checks out', (tester) async {
      final repo = FakeDayRepository(
        days: <DayEntry>[
          DayEntry(dateKey: '2026-08-25', checkIn: DateTime(2026, 8, 25, 9)),
        ],
      );
      await pumpHome(tester, repo);

      await tester.tap(find.byType(CheckButton));
      await tester.pump(commitWindow);
      await tester.pumpAndSettle();

      expect(repo.savedDays.single.checkOut, clock);
      expect(find.text('CHECKED OUT'), findsOneWidget);
    });

    testWidgets('a sealed day ignores taps', (tester) async {
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

      await tester.tap(find.byType(CheckButton));
      await tester.pump(commitWindow);
      await tester.pumpAndSettle();

      expect(repo.savedDays, isEmpty);
      expect(find.text('CHECKED OUT'), findsOneWidget);
    });
  });

  group('undo', () {
    testWidgets('reopens a sealed day back to CHECK OUT', (tester) async {
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

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(repo.savedDays.single.checkOut, isNull);
      expect(find.text('CHECK OUT'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
    });
  });
}
