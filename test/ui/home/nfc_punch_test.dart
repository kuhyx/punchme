import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/local_date.dart';
import 'package:punchme/models/settings.dart';
import 'package:punchme/nfc/punch_tag.dart';
import 'package:punchme/ui/home/check_button.dart';
import 'package:punchme/ui/home/home_punch_handlers.dart';
import 'package:punchme/ui/home/home_screen.dart';
import 'package:punchme/ui/home/punch_banner.dart';

import '../../support/fake_day_repository.dart';

void main() {
  late DateTime clock;
  DateTime now() => clock;

  setUp(() => clock = DateTime(2026, 8, 25, 9, 3, 12));

  /// Pumps the screen and hands back the tap entry point the NFC layer uses.
  Future<HomePunchHandlers> pumpHome(
    WidgetTester tester,
    FakeDayRepository repo,
  ) async {
    late HomePunchHandlers handlers;
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          repository: repo,
          now: now,
          onReady: (ready) => handlers = ready,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return handlers;
  }

  group('a foreground tap', () {
    testWidgets('checks in through the same path as the button', (
      tester,
    ) async {
      final repo = FakeDayRepository();
      final handlers = await pumpHome(tester, repo);

      await handlers.onPunch(const PunchTag(label: 'desk'));
      await tester.pump();
      // The cancel window applies to a tap exactly as it does to a press.
      expect(repo.savedDays, isEmpty);
      expect(find.text('tap again to cancel'), findsOneWidget);

      await tester.pump(commitWindow);
      await tester.pumpAndSettle();

      expect(repo.savedDays.single.checkIn, clock);
      expect(find.text('CHECK OUT'), findsOneWidget);
    });

    testWidgets('records the tap time, not the commit time', (tester) async {
      final repo = FakeDayRepository();
      final handlers = await pumpHome(tester, repo);
      final tapped = clock;

      await handlers.onPunch(const PunchTag(label: 'desk'));
      await tester.pump();
      clock = clock.add(const Duration(minutes: 5));
      await tester.pump(commitWindow);
      await tester.pumpAndSettle();

      expect(repo.savedDays.single.checkIn, tapped);
    });

    testWidgets('banners the check-out with the tag label and Undo', (
      tester,
    ) async {
      final repo = FakeDayRepository(
        days: <DayEntry>[
          DayEntry(dateKey: localDateKey(clock), checkIn: clock),
        ],
      );
      clock = clock.add(const Duration(hours: 8));
      final handlers = await pumpHome(tester, repo);

      await handlers.onPunch(const PunchTag(label: 'desk'));
      await tester.pump(commitWindow);
      await tester.pumpAndSettle();

      expect(find.text('Checked OUT 17:03 via desk tag'), findsOneWidget);
      // The summary shows its own Undo once the day is sealed, so scope the
      // search to the banner's action rather than counting them globally.
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text('Undo'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('banners a check-in when no alarm is offered', (tester) async {
      // A non-working day has no target, so no dialog is raised and the
      // banner is the only thing that reports the punch.
      final repo = FakeDayRepository(
        settings: const Settings(workingWeekdays: <int>{}),
      );
      final handlers = await pumpHome(tester, repo);

      await handlers.onPunch(const PunchTag(label: 'desk'));
      await tester.pump(commitWindow);
      await tester.pumpAndSettle();

      expect(find.text('Checked IN 09:03 via desk tag'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text('Undo'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Undo on a check-in banner removes the day entirely', (
      tester,
    ) async {
      final repo = FakeDayRepository(
        settings: const Settings(workingWeekdays: <int>{}),
      );
      final handlers = await pumpHome(tester, repo);

      await handlers.onPunch(const PunchTag(label: 'desk'));
      await tester.pump(commitWindow);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text('Undo'),
        ),
      );
      await tester.pumpAndSettle();

      expect(repo.deletedKeys, hasLength(1));
      expect(find.text('CHECK IN'), findsOneWidget);
    });

    testWidgets('Undo reopens the day the tap sealed', (tester) async {
      final repo = FakeDayRepository(
        days: <DayEntry>[
          DayEntry(dateKey: localDateKey(clock), checkIn: clock),
        ],
      );
      clock = clock.add(const Duration(hours: 8));
      final handlers = await pumpHome(tester, repo);

      await handlers.onPunch(const PunchTag(label: 'desk'));
      await tester.pump(commitWindow);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text('Undo'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CHECK OUT'), findsOneWidget);
      expect(repo.savedDays.last.checkOut, isNull);
    });
  });
}
