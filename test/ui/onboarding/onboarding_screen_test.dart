import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/ui/onboarding/onboarding_screen.dart';
import 'package:punchme/ui/wifi/current_network_picker.dart';
import 'package:punchme/ui/wifi/location_rationale.dart';

import '../../support/fake_day_repository.dart';
import '../../support/fake_wifi.dart';

void main() {
  late List<bool> armedCalls;
  late int settingsOpened;

  setUp(() {
    armedCalls = <bool>[];
    settingsOpened = 0;
  });

  /// Pushes onboarding over a placeholder, so popping it is observable.
  Future<void> pump(
    WidgetTester tester,
    FakeDayRepository repo, {
    bool granted = true,
    bool requestGrants = true,
    CurrentNetworkPicker? picker,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => OnboardingScreen(
                  repository: repo,
                  picker: picker ?? fakePicker(),
                  status: () async => locationStatus(granted: granted),
                  requestLocation: () async => requestGrants,
                  armWifi: ({required bool armed}) async =>
                      armedCalls.add(armed),
                  openSettings: () async => settingsOpened++,
                ),
              ),
            ),
            child: const Text('home'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
  }

  testWidgets('with location granted, goes straight to adding', (tester) async {
    await pump(tester, FakeDayRepository());
    expect(find.text('Add this network'), findsOneWidget);
    expect(find.text(kLocationRationale), findsNothing);
  });

  testWidgets('without location, explains before anything is asked', (
    tester,
  ) async {
    await pump(tester, FakeDayRepository(), granted: false);
    expect(find.text(kLocationRationale), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('Continue with a grant moves on to adding', (tester) async {
    await pump(tester, FakeDayRepository(), granted: false);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Add this network'), findsOneWidget);
    expect(find.text(kLocationDeniedMessage), findsNothing);
  });

  testWidgets('Continue with a refusal says so and offers settings', (
    tester,
  ) async {
    await pump(
      tester,
      FakeDayRepository(),
      granted: false,
      requestGrants: false,
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text(kLocationDeniedMessage), findsOneWidget);
    await tester.tap(find.text('Open app settings'));
    expect(settingsOpened, 1);
  });

  testWidgets('adding saves the network, arms native and closes', (
    tester,
  ) async {
    final repo = FakeDayRepository();
    await pump(tester, repo);
    await tester.tap(find.text('Add this network'));
    await tester.pumpAndSettle();

    expect((await repo.loadSettings()).workWifiSsids, const <String>{'Office'});
    expect(armedCalls, <bool>[true]);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('not on Wi-Fi stays open and says why', (tester) async {
    final repo = FakeDayRepository();
    await pump(tester, repo, picker: fakePicker(ssid: null));
    await tester.tap(find.text('Add this network'));
    await tester.pumpAndSettle();

    expect(find.text(kNotOnWifiMessage), findsOneWidget);
    expect(find.text('Open app settings'), findsNothing);
    expect(armedCalls, isEmpty);
  });

  testWidgets('backing out of the explanation shows no message', (
    tester,
  ) async {
    await pump(
      tester,
      FakeDayRepository(),
      picker: fakePicker(granted: false, explainAccepted: false),
    );
    await tester.tap(find.text('Add this network'));
    await tester.pumpAndSettle();
    expect(find.text(kNotOnWifiMessage), findsNothing);
    expect(find.text(kLocationDeniedMessage), findsNothing);
  });

  testWidgets('"not at work" skips without saving', (tester) async {
    final repo = FakeDayRepository();
    await pump(tester, repo);
    await tester.tap(find.text("I'm not at work right now"));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(repo.savedSettings, isEmpty);
  });

  testWidgets('Skip on the explanation closes it', (tester) async {
    await pump(tester, FakeDayRepository(), granted: false);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });
}
