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

  group('the guard', () {
    testWidgets('refuses a tap moments after a punch, and says so', (
      tester,
    ) async {
      final repo = FakeDayRepository(
        days: <DayEntry>[
          DayEntry(dateKey: localDateKey(clock), checkIn: clock),
        ],
      );
      clock = clock.add(const Duration(seconds: 8));
      final handlers = await pumpHome(tester, repo);

      await handlers.onPunch(const PunchTag(label: 'desk'));
      await tester.pump(commitWindow);
      await tester.pumpAndSettle();

      expect(repo.savedDays, isEmpty);
      expect(find.text('Ignored: you punched moments ago'), findsOneWidget);
      expect(find.text('CHECK OUT'), findsOneWidget);
    });

    testWidgets('says so when the day is already sealed', (tester) async {
      final start = clock;
      final repo = FakeDayRepository(
        days: <DayEntry>[
          DayEntry(
            dateKey: localDateKey(start),
            checkIn: start,
            checkOut: start.add(const Duration(hours: 8)),
          ),
        ],
      );
      clock = start.add(const Duration(hours: 9));
      final handlers = await pumpHome(tester, repo);

      await handlers.onPunch(const PunchTag(label: 'desk'));
      await tester.pump(commitWindow);
      await tester.pumpAndSettle();

      expect(find.text('Today is already checked out'), findsOneWidget);
      expect(repo.savedDays, isEmpty);
    });
  });

  group('collisions and odd tags', () {
    testWidgets('a tap during a pending window is dropped', (tester) async {
      final repo = FakeDayRepository();
      final handlers = await pumpHome(tester, repo);

      await tester.tap(find.byType(CheckButton));
      await tester.pump();
      // The tag arrives mid-window and must not cancel or double-commit.
      await handlers.onPunch(const PunchTag(label: 'desk'));
      await tester.pump(commitWindow);
      await tester.pumpAndSettle();

      expect(repo.savedDays, hasLength(1));
      // Committed as a press, so it carries no tag label.
      expect(find.textContaining('via desk tag'), findsNothing);
    });

    testWidgets('a blank tag points at the write-tag screen', (tester) async {
      final repo = FakeDayRepository();
      final handlers = await pumpHome(tester, repo);

      handlers.onBlankTag();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text(kBlankTagMessage), findsOneWidget);
      expect(repo.savedDays, isEmpty);
    });

    testWidgets('a blank tag mid-window does not interrupt a punch', (
      tester,
    ) async {
      final repo = FakeDayRepository();
      final handlers = await pumpHome(tester, repo);

      await tester.tap(find.byType(CheckButton));
      await tester.pump();
      handlers.onBlankTag();
      await tester.pump();

      expect(find.text(kBlankTagMessage), findsNothing);

      await tester.pump(commitWindow);
      await tester.pumpAndSettle();
      expect(repo.savedDays, hasLength(1));
    });

    testWidgets('an unknown schema still punches, warning once', (
      tester,
    ) async {
      final repo = FakeDayRepository();
      final handlers = await pumpHome(tester, repo);

      await handlers.onPunch(const PunchTag(version: 7, label: 'desk'));
      await tester.pump();
      expect(find.text(kUnknownTagVersionMessage), findsOneWidget);

      await tester.pump(commitWindow);
      await tester.pumpAndSettle();
      expect(repo.savedDays, hasLength(1));
    });
  });
}
