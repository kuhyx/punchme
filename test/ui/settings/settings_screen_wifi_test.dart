import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/models/settings.dart';
import 'package:punchme/ui/settings/google_sign_in_result.dart';
import 'package:punchme/ui/settings/settings_screen.dart';

import '../../support/fake_day_repository.dart';

/// The "Work Wi-Fi" section.
///
/// Split from `settings_screen_test.dart` to clear the 250-line gate.
void main() {
  DateTime now() => DateTime(2026, 8, 25, 12);
  late List<bool> armedCalls;

  setUp(() => armedCalls = <bool>[]);

  Future<void> pump(
    WidgetTester tester,
    FakeDayRepository repo, {
    Future<String?> Function() currentSsid = _noCurrentSsid,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          repository: repo,
          now: now,
          // Stubbed: the real probe reads the keystore over a platform
          // channel no host answers here, which would hang the whole file.
          syncProbe: () async => false,
          syncConnect: () async => GoogleSignInStatus.cancelled,
          currentSsid: currentSsid,
          armWifi: ({required bool armed}) async => armedCalls.add(armed),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The free-days calendar makes the page taller than the test viewport, so
  // anything below it has to be scrolled into range before it can be tapped.
  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('says so when none are configured', (tester) async {
    await pump(tester, FakeDayRepository());
    await scrollTo(tester, find.text('No work Wi-Fi networks yet'));
    expect(find.text('No work Wi-Fi networks yet'), findsOneWidget);
  });

  testWidgets('adding a network saves it and arms native', (tester) async {
    final repo = FakeDayRepository();
    await pump(tester, repo);

    await scrollTo(tester, find.byTooltip('Add'));
    await tester.enterText(find.byType(TextField).last, 'Office');
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();

    expect((await repo.loadSettings()).workWifiSsids, const <String>{'Office'});
    expect(armedCalls, <bool>[true]);
  });

  testWidgets('removing the last network disarms native', (tester) async {
    final repo = FakeDayRepository(
      settings: const Settings(workWifiSsids: <String>{'Office'}),
    );
    await pump(tester, repo);

    await scrollTo(tester, find.byTooltip('Delete'));
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();

    expect((await repo.loadSettings()).workWifiSsids, isEmpty);
    expect(armedCalls, <bool>[false]);
  });

  testWidgets('use current network fills it in from native', (tester) async {
    final repo = FakeDayRepository();
    await pump(tester, repo, currentSsid: () async => 'Office');

    await scrollTo(tester, find.text('Use current network'));
    await tester.tap(find.text('Use current network'));
    await tester.pumpAndSettle();

    expect((await repo.loadSettings()).workWifiSsids, const <String>{'Office'});
  });

  testWidgets('the status card is hidden behind a hint until armed', (
    tester,
  ) async {
    await pump(tester, FakeDayRepository());
    await scrollTo(tester, find.text('Add a network above to turn this on.'));
    expect(find.text('Add a network above to turn this on.'), findsOneWidget);
  });
}

Future<String?> _noCurrentSsid() async => null;
