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

  /// Tuesday, 7h56m logged: 4 minutes short.
  DayEntry tuesday() {
    final checkIn = DateTime(2026, 8, 25, 9);
    return DayEntry(
      dateKey: '2026-08-25',
      checkIn: checkIn,
      checkOut: checkIn.add(const Duration(hours: 7, minutes: 56)),
    );
  }

  group('the offer', () {
    testWidgets('checking in proposes making up the week', (tester) async {
      await pump(
        tester,
        FakeDayRepository(days: <DayEntry>[tuesday()], settings: settings),
      );
      await checkIn(tester);

      // 4 minutes short on Tuesday => 8h04m today, so 09:00 + 8h04m.
      expect(find.text('Checked in'), findsOneWidget);
      expect(
        find.textContaining('Work 8h 04m today, until 17:04.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('0h 04m behind this week — all today.'),
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
      expect(alarms.single.at, DateTime(2026, 8, 26, 17, 4));
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

      expect(find.textContaining('Until 17:04'), findsOneWidget);
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
  });

  testWidgets('a banked week still proposes a plain day', (tester) async {
    // Being ahead never shortens a day: the required 8h stands.
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

    expect(find.text('Checked in'), findsOneWidget);
    expect(
      find.textContaining('Work 8h 00m today, until 17:00.'),
      findsOneWidget,
    );
    expect(find.text('On track, nothing to make up.'), findsOneWidget);
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
}
