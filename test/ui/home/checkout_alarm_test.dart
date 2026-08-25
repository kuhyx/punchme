import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/settings.dart';
import 'package:punchme/ui/home/check_button.dart';
import 'package:punchme/ui/home/home_screen.dart';

import '../../support/fake_day_repository.dart';

/// A recorded alarm request.
class Alarm {
  Alarm(this.at, this.message);
  final DateTime at;
  final String message;
}

void main() {
  late DateTime clock;
  late List<Alarm> alarms;

  DateTime now() => clock;

  Future<void> setAlarm({
    required DateTime at,
    required String message,
  }) async => alarms.add(Alarm(at, message));

  // Tue/Wed/Thu at 8h => a 24h week.
  final settings = const Settings().copyWith(
    workingWeekdays: const <int>{
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
    },
  );

  setUp(() {
    alarms = <Alarm>[];
    clock = DateTime(2026, 8, 26, 9); // Wednesday 09:00
  });

  Future<void> pump(WidgetTester tester, FakeDayRepository repo) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(repository: repo, now: now, setAlarm: setAlarm),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> checkIn(WidgetTester tester) async {
    await tester.tap(find.byType(CheckButton));
    await tester.pump(commitWindow);
    await tester.pumpAndSettle();
  }

  /// Tuesday, 8h23m logged.
  DayEntry tuesday() {
    final checkIn = DateTime(2026, 8, 25, 9);
    return DayEntry(
      dateKey: '2026-08-25',
      checkIn: checkIn,
      checkOut: checkIn.add(const Duration(hours: 8, minutes: 23)),
    );
  }

  group('the offer', () {
    testWidgets('checking in proposes the split target', (tester) async {
      await pump(
        tester,
        FakeDayRepository(days: <DayEntry>[tuesday()], settings: settings),
      );
      await checkIn(tester);

      // 24h - 8h23m = 15h37m over Wed+Thu => 7h49m, so 09:00 + 7h49m.
      expect(find.text('Checked in'), findsOneWidget);
      expect(
        find.textContaining('Work 7h 49m today, until 16:49.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('15h 37m left this week over 2 days'),
        findsOneWidget,
      );
    });

    testWidgets('accepting sets an alarm for that time', (tester) async {
      await pump(
        tester,
        FakeDayRepository(days: <DayEntry>[tuesday()], settings: settings),
      );
      await checkIn(tester);
      await tester.tap(find.text('Set alarm'));
      await tester.pumpAndSettle();

      expect(alarms, hasLength(1));
      expect(alarms.single.at, DateTime(2026, 8, 26, 16, 49));
      expect(alarms.single.message, contains('check out'));
    });

    testWidgets('declining sets no alarm', (tester) async {
      await pump(
        tester,
        FakeDayRepository(days: <DayEntry>[tuesday()], settings: settings),
      );
      await checkIn(tester);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(alarms, isEmpty);
    });

    testWidgets('the target stays on screen after the dialog closes', (
      tester,
    ) async {
      await pump(
        tester,
        FakeDayRepository(days: <DayEntry>[tuesday()], settings: settings),
      );
      await checkIn(tester);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Until 16:49'), findsOneWidget);
    });

    testWidgets('checking OUT does not propose an alarm', (tester) async {
      final repo = FakeDayRepository(
        days: <DayEntry>[
          DayEntry(dateKey: '2026-08-26', checkIn: DateTime(2026, 8, 26, 9)),
        ],
        settings: settings,
      );
      await pump(tester, repo);
      await checkIn(tester); // this is a check-OUT

      expect(find.text('Checked in'), findsNothing);
      expect(alarms, isEmpty);
    });
  });

  group('no target', () {
    testWidgets('nothing is proposed on a non-working day', (tester) async {
      clock = DateTime(2026, 8, 28, 9); // Friday, not a working day here
      await pump(tester, FakeDayRepository(settings: settings));
      await checkIn(tester);

      expect(find.text('Checked in'), findsNothing);
      expect(alarms, isEmpty);
    });

    testWidgets('nothing is proposed once the week is banked', (tester) async {
      final big = DayEntry(
        dateKey: '2026-08-25',
        checkIn: DateTime(2026, 8, 25, 6),
        checkOut: DateTime(2026, 8, 26, 6), // 24h in one go
      );
      await pump(
        tester,
        FakeDayRepository(days: <DayEntry>[big], settings: settings),
      );
      await checkIn(tester);

      expect(find.text('Checked in'), findsNothing);
      expect(alarms, isEmpty);
    });
  });

  testWidgets('a plain Mon-Fri week proposes a plain 8h day', (tester) async {
    clock = DateTime(2026, 8, 24, 9); // Monday
    await pump(tester, FakeDayRepository());
    await checkIn(tester);

    expect(
      find.textContaining('Work 8h 00m today, until 17:00.'),
      findsOneWidget,
    );
  });

  group('the target survives a restart', () {
    testWidgets('a day left open still shows its target on a fresh launch', (
      tester,
    ) async {
      // Opening the app on an already-running day must not lose the target:
      // _target used to be set only by the check-in flow, so killing and
      // reopening the app dropped the "Until ..." line entirely.
      final repo = FakeDayRepository(
        days: <DayEntry>[
          tuesday(),
          // Checked in this morning, still running.
          DayEntry(dateKey: '2026-08-26', checkIn: DateTime(2026, 8, 26, 9)),
        ],
        settings: settings,
      );
      await pump(tester, repo);

      expect(find.text('CHECK OUT'), findsOneWidget);
      expect(find.textContaining('Until 16:49'), findsOneWidget);
      // Nothing is proposed on a plain reopen -- only on a fresh check-in.
      expect(find.text('Checked in'), findsNothing);
      expect(alarms, isEmpty);
    });

    testWidgets('a sealed day shows no target', (tester) async {
      final checkIn = DateTime(2026, 8, 26, 9);
      final repo = FakeDayRepository(
        days: <DayEntry>[
          DayEntry(
            dateKey: '2026-08-26',
            checkIn: checkIn,
            checkOut: checkIn.add(const Duration(hours: 8)),
          ),
        ],
        settings: settings,
      );
      await pump(tester, repo);

      expect(find.text('CHECKED OUT'), findsOneWidget);
      expect(find.textContaining('Until'), findsNothing);
    });
  });

  testWidgets('a failing alarm is reported, not fatal', (tester) async {
    // The real failure this guards: without the SET_ALARM permission the
    // intent throws PlatformException, which used to escape as an unhandled
    // exception after the check-in had already been saved.
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          repository: FakeDayRepository(
            days: <DayEntry>[tuesday()],
            settings: settings,
          ),
          now: now,
          setAlarm: ({required DateTime at, required String message}) async =>
              throw PlatformException(code: 'error', message: 'Permission'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await checkIn(tester);
    await tester.tap(find.text('Set alarm'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Could not set the alarm'), findsOneWidget);
    // The day itself is still checked in.
    expect(find.text('CHECK OUT'), findsOneWidget);
  });
}
