import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/models/settings.dart';
import 'package:punchme/ui/settings/free_day_calendar.dart';
import 'package:punchme/ui/settings/free_day_cell.dart';
import 'package:punchme/ui/settings/free_days_field.dart';

void main() {
  // A Tuesday, and a default working day.
  DateTime now() => DateTime(2026, 8, 25, 12);

  Finder dayCell(String key) => find.byKey(ValueKey<String>('free-day-$key'));

  Future<Set<String>?> pump(
    WidgetTester tester, {
    Set<String> freeDays = const <String>{},
    Set<int> workingWeekdays = Settings.defaultWorkingWeekdays,
    required Set<String>? Function() latest,
    required void Function(Set<String>) record,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FreeDaysField(
              freeDays: freeDays,
              workingWeekdays: workingWeekdays,
              onChanged: record,
              now: now,
            ),
          ),
        ),
      ),
    );
    return latest();
  }

  group('canShowMonth', () {
    test('accepts the months either side of today', () {
      expect(canShowMonth(DateTime(2026, 7), now()), isTrue);
      expect(canShowMonth(DateTime(2026, 9), now()), isTrue);
    });

    test('accepts exactly the five-year edges', () {
      expect(canShowMonth(DateTime(2021, 8), now()), isTrue);
      expect(canShowMonth(DateTime(2031, 8), now()), isTrue);
    });

    test('rejects months beyond either edge', () {
      expect(canShowMonth(DateTime(2021, 7), now()), isFalse);
      expect(canShowMonth(DateTime(2031, 9), now()), isFalse);
    });
  });

  group('grid maths', () {
    test('August 2026 starts on a Saturday, so five blanks lead it', () {
      expect(leadingBlanks(DateTime(2026, 8)), 5);
    });

    test('a month starting on Monday needs no blanks', () {
      expect(leadingBlanks(DateTime(2026, 6)), 0);
    });

    test('day counts cover short months and leap years', () {
      expect(daysInMonth(DateTime(2026, 8)), 31);
      expect(daysInMonth(DateTime(2026, 2)), 28);
      expect(daysInMonth(DateTime(2024, 2)), 29);
    });
  });

  group('tapping days', () {
    late List<Set<String>> changes;
    setUp(() => changes = <Set<String>>[]);
    Set<String>? latest() => changes.isEmpty ? null : changes.last;

    testWidgets('marks a plain working day', (tester) async {
      await pump(tester, latest: latest, record: changes.add);
      await tester.tap(dayCell('2026-08-04'));
      expect(latest(), <String>{'2026-08-04'});
    });

    testWidgets('unmarks a day that is already free', (tester) async {
      await pump(
        tester,
        freeDays: const <String>{'2026-08-04', '2026-08-05'},
        latest: latest,
        record: changes.add,
      );
      await tester.tap(dayCell('2026-08-04'));
      expect(latest(), <String>{'2026-08-05'});
    });

    testWidgets('leaves a non-working weekday alone', (tester) async {
      await pump(tester, latest: latest, record: changes.add);
      // 2026-08-08 is a Saturday, which is not a default working day.
      final cell = tester.widget<FreeDayCell>(dayCell('2026-08-08'));
      expect(cell.onTap, isNull);

      await tester.tap(dayCell('2026-08-08'), warnIfMissed: false);
      expect(changes, isEmpty);
    });

    testWidgets('still removes a stale free day', (tester) async {
      // Monday is free, then Monday stops being a working day.
      await pump(
        tester,
        freeDays: const <String>{'2026-08-03'},
        workingWeekdays: const <int>{
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
        },
        latest: latest,
        record: changes.add,
      );

      final cell = tester.widget<FreeDayCell>(dayCell('2026-08-03'));
      expect(cell.isFree, isTrue, reason: 'the record must survive');
      expect(cell.isWorkingWeekday, isFalse);
      expect(cell.onTap, isNotNull, reason: 'it must stay removable');

      await tester.tap(dayCell('2026-08-03'));
      expect(latest(), isEmpty);
    });
  });

  group('month navigation', () {
    testWidgets('opens on the month containing today', (tester) async {
      await pump(tester, latest: () => null, record: (_) {});
      expect(find.text('August 2026'), findsOneWidget);
    });

    testWidgets('steps back and forward a month', (tester) async {
      await pump(tester, latest: () => null, record: (_) {});

      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      expect(find.text('July 2026'), findsOneWidget);

      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      expect(find.text('September 2026'), findsOneWidget);
    });

    testWidgets('both arrows are live inside the window', (tester) async {
      await pump(tester, latest: () => null, record: (_) {});
      IconButton arrow(String tooltip) => tester.widget<IconButton>(
        find
            .ancestor(
              of: find.byTooltip(tooltip),
              matching: find.byType(IconButton),
            )
            .first,
      );
      expect(arrow('Previous month').onPressed, isNotNull);
      expect(arrow('Next month').onPressed, isNotNull);
    });
  });

  group('the chip inventory', () {
    testWidgets('says so when there are none', (tester) async {
      await pump(tester, latest: () => null, record: (_) {});
      expect(find.text('No free days yet'), findsOneWidget);
    });

    testWidgets('lists days from other months too', (tester) async {
      await pump(
        tester,
        freeDays: const <String>{'2026-12-25'},
        latest: () => null,
        record: (_) {},
      );
      // December is not the displayed month, so only the chip shows it.
      expect(find.text('2026-12-25'), findsOneWidget);
    });

    testWidgets('deleting a chip removes that day', (tester) async {
      final changes = <Set<String>>[];
      await pump(
        tester,
        freeDays: const <String>{'2026-12-25'},
        latest: () => null,
        record: changes.add,
      );
      await tester.scrollUntilVisible(
        find.byTooltip('Delete'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete'));
      expect(changes.single, isEmpty);
    });
  });
}
