import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/logic/balance.dart';
import 'package:punchme/models/horizon.dart';
import 'package:punchme/models/settings.dart';
import 'package:punchme/ui/stats/balance_card.dart';
import 'package:punchme/ui/stats/stats_screen.dart';

import '../../support/fake_day_repository.dart';

/// Cards switched off in Settings read as info, not as a verdict.
void main() {
  const behind = Balance(
    worked: Duration(hours: 4),
    expected: Duration(hours: 8),
    quota: Duration(hours: 40),
    todaySoFar: Duration.zero,
  );

  Color chipFill(WidgetTester tester) =>
      (tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: find.byType(BalanceCard),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration)
          .color!;

  Future<void> pumpCard(WidgetTester tester, {required bool infoOnly}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: BalanceCard(
              title: 'This month',
              balance: behind,
              infoOnly: infoOnly,
            ),
          ),
        ),
      );

  testWidgets('a counted card behind is drawn in the danger colour', (
    tester,
  ) async {
    await pumpCard(tester, infoOnly: false);
    final status = Theme.of(
      tester.element(find.byType(BalanceCard)),
    ).extension<AppStatusColors>()!;
    expect(chipFill(tester), status.danger);
    expect(find.text('This month'), findsOneWidget);
  });

  testWidgets('an info-only card is labelled and drawn neutral', (
    tester,
  ) async {
    await pumpCard(tester, infoOnly: true);
    final theme = Theme.of(tester.element(find.byType(BalanceCard)));
    expect(find.text('This month · Info only'), findsOneWidget);
    expect(chipFill(tester), theme.colorScheme.surfaceContainerHighest);
    expect(find.text('-4h 00m'), findsOneWidget);
  });

  testWidgets('Statistics marks the cards that do not count', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StatsScreen(
          repository: FakeDayRepository(
            settings: const Settings(countedHorizons: <Horizon>{Horizon.week}),
          ),
          now: () => DateTime(2026, 8, 25, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('This month · Info only'), findsOneWidget);
    expect(find.text('This year · Info only'), findsOneWidget);
  });
}
