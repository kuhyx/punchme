import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/models/horizon.dart';
import 'package:punchme/models/settings.dart';
import 'package:punchme/ui/settings/counted_horizons_field.dart';
import 'package:punchme/ui/settings/google_sign_in_result.dart';
import 'package:punchme/ui/settings/settings_screen.dart';

import '../../support/fake_day_repository.dart';
import '../../support/fake_wifi.dart';

void main() {
  group('CountedHorizonsField', () {
    late List<Set<Horizon>> changes;

    setUp(() => changes = <Set<Horizon>>[]);

    Future<void> pump(WidgetTester tester, Set<Horizon> counted) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CountedHorizonsField(
                counted: counted,
                onChanged: changes.add,
              ),
            ),
          ),
        );

    bool switchOn(WidgetTester tester, String label) => tester
        .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, label))
        .value;

    testWidgets('shows one switch per card, on when it counts', (tester) async {
      await pump(tester, const <Horizon>{Horizon.week});
      expect(switchOn(tester, 'This week'), isTrue);
      expect(switchOn(tester, 'This month'), isFalse);
      expect(switchOn(tester, 'This year'), isFalse);
    });

    testWidgets('switching a card off drops only that card', (tester) async {
      await pump(tester, Settings.allHorizons);
      await tester.tap(find.text('This month'));
      expect(changes.single, const <Horizon>{Horizon.week, Horizon.year});
    });

    testWidgets('switching a card on adds it', (tester) async {
      await pump(tester, const <Horizon>{Horizon.week});
      await tester.tap(find.text('This year'));
      expect(changes.single, const <Horizon>{Horizon.week, Horizon.year});
    });
  });

  testWidgets('Settings saves the choice', (tester) async {
    final repo = FakeDayRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          repository: repo,
          now: () => DateTime(2026, 8, 25, 12),
          syncProbe: () async => false,
          syncConnect: () async => GoogleSignInStatus.cancelled,
          picker: fakePicker(),
          armWifi: ({required bool armed}) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Fully on screen, not just scrolled to the edge: a tap on a tile half
    // under the viewport lands on nothing.
    final yearSwitch = find.widgetWithText(SwitchListTile, 'This year');
    await tester.scrollUntilVisible(
      yearSwitch,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(yearSwitch);
    await tester.pumpAndSettle();
    await tester.tap(yearSwitch);
    await tester.pumpAndSettle();

    expect((await repo.loadSettings()).countedHorizons, const <Horizon>{
      Horizon.week,
      Horizon.month,
    });
  });
}
