import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/ui/history/history_screen.dart';
import 'package:punchme/ui/home/home_screen.dart';
import 'package:punchme/ui/stats/stats_screen.dart';

import '../support/fake_day_repository.dart';

/// Main screens fit one Pixel 6a screen: no vertical scrolling at all.
void main() {
  DateTime now() => DateTime(2026, 8, 25, 12);

  /// A closed 8h day for every date of August 2026 up to the 25th.
  List<DayEntry> august() => <DayEntry>[
    for (var d = 1; d <= 25; d++)
      DayEntry(
        dateKey: '2026-08-${d.toString().padLeft(2, '0')}',
        checkIn: DateTime(2026, 8, d, 9),
        checkOut: DateTime(2026, 8, d, 17),
      ),
  ];

  /// Pixel 6a: 1080x2400 px at 2.625, with the real status/nav insets.
  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    const insets = FakeViewPadding(top: 132, bottom: 63);
    tester.view.padding = insets;
    tester.view.viewPadding = insets;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Fails on any vertical Scrollable, scrolled or not.
  void expectNoVerticalScroll(WidgetTester tester) {
    for (final element in find.byType(Scrollable).evaluate()) {
      final state = (element as StatefulElement).state as ScrollableState;
      if (state.widget.axis == Axis.vertical) {
        fail('vertical Scrollable present: ${state.position.maxScrollExtent}');
      }
    }
    expect(tester.takeException(), isNull);
  }

  testWidgets('history shows a full month without scrolling', (tester) async {
    await pump(
      tester,
      HistoryScreen(
        repository: FakeDayRepository(days: august()),
        now: now,
      ),
    );
    expectNoVerticalScroll(tester);
    expect(find.byKey(const ValueKey<String>('day-2026-08-24')), findsOne);
    expect(find.byKey(const ValueKey<String>('day-2026-08-31')), findsOne);
  });

  testWidgets('history stays on one screen at large text', (tester) async {
    await pump(
      tester,
      HistoryScreen(
        repository: FakeDayRepository(days: august()),
        now: now,
      ),
      textScale: 2,
    );
    expectNoVerticalScroll(tester);
  });

  testWidgets('stats shows all periods without scrolling', (tester) async {
    await pump(
      tester,
      StatsScreen(
        repository: FakeDayRepository(days: august()),
        now: now,
      ),
      textScale: 2,
    );
    expectNoVerticalScroll(tester);
    expect(find.text('This week'), findsOne);
    expect(find.text('This year'), findsOne);
  });

  testWidgets('home fits and its actions are hit-testable', (tester) async {
    await pump(
      tester,
      HomeScreen(
        repository: FakeDayRepository(days: august()),
        now: () => DateTime(2026, 8, 25, 18),
      ),
    );
    expectNoVerticalScroll(tester);
    expect(find.text('CHECKED OUT').hitTestable(), findsOne);
    expect(find.text('Undo').hitTestable(), findsOne);
  });
}
