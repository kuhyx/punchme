import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/ui/settings/free_day_cell.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool isFree,
    required bool isWorkingWeekday,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FreeDayCell(
            day: 4,
            isFree: isFree,
            isWorkingWeekday: isWorkingWeekday,
            onTap: onTap,
          ),
        ),
      ),
    );
  }

  Color? boxColour(WidgetTester tester) {
    final container = tester.widget<Container>(find.byType(Container));
    return (container.decoration! as BoxDecoration).color;
  }

  testWidgets('a working day that is not free has no fill', (tester) async {
    await pump(tester, isFree: false, isWorkingWeekday: true, onTap: () {});
    expect(find.text('4'), findsOneWidget);
    expect(boxColour(tester), isNull);
  });

  testWidgets('a free working day is filled', (tester) async {
    await pump(tester, isFree: true, isWorkingWeekday: true, onTap: () {});
    expect(boxColour(tester), isNotNull);
  });

  testWidgets('a stale free day is filled more faintly', (tester) async {
    await pump(tester, isFree: true, isWorkingWeekday: true, onTap: () {});
    final active = boxColour(tester)!;
    await pump(tester, isFree: true, isWorkingWeekday: false, onTap: () {});
    final stale = boxColour(tester)!;

    // Still marked, but visibly dimmer than an active free day.
    expect(stale.a, lessThan(active.a));
    expect(stale.a, greaterThan(0));
  });

  testWidgets('a non-working day that is not free is inert', (tester) async {
    await pump(tester, isFree: false, isWorkingWeekday: false);
    expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
    expect(boxColour(tester), isNull);
  });

  testWidgets('tapping a tappable cell calls back', (tester) async {
    var taps = 0;
    await pump(
      tester,
      isFree: false,
      isWorkingWeekday: true,
      onTap: () => taps++,
    );
    await tester.tap(find.byType(FreeDayCell));
    expect(taps, 1);
  });
}
