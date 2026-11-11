import 'package:flutter/material.dart';
import 'package:punchme/ui/glyphs.dart';
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
    expect(find.byKey(const Key('onboarding-add-network')), findsOneWidget);
    expect(find.bySemanticsLabel(kLocationRationale), findsNothing);
  });

  testWidgets('without location, explains before anything is asked', (
    tester,
  ) async {
    await pump(tester, FakeDayRepository(), granted: false);
    expect(find.bySemanticsLabel(kLocationRationale), findsOneWidget);
    expect(find.byKey(const Key('onboarding-continue')), findsOneWidget);
  });

  testWidgets('Continue with a grant moves on to adding', (tester) async {
    await pump(tester, FakeDayRepository(), granted: false);
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('onboarding-add-network')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is Cue && w.spoken == kLocationDeniedMessage,
      ),
      findsNothing,
    );
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
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) => w is Cue && w.spoken == kLocationDeniedMessage,
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('onboarding-settings')));
    expect(settingsOpened, 1);
  });

  testWidgets('adding saves the network, arms native and closes', (
    tester,
  ) async {
    final repo = FakeDayRepository();
    await pump(tester, repo);
    await tester.tap(find.byKey(const Key('onboarding-add-network')));
    await tester.pumpAndSettle();

    expect((await repo.loadSettings()).workWifiSsids, const <String>{'Office'});
    expect(armedCalls, <bool>[true]);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('not on Wi-Fi stays open and says why', (tester) async {
    final repo = FakeDayRepository();
    await pump(tester, repo, picker: fakePicker(ssid: null));
    await tester.tap(find.byKey(const Key('onboarding-add-network')));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate((w) => w is Cue && w.spoken == kNotOnWifiMessage),
      findsOneWidget,
    );
    expect(find.byKey(const Key('onboarding-settings')), findsNothing);
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
    await tester.tap(find.byKey(const Key('onboarding-add-network')));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate((w) => w is Cue && w.spoken == kNotOnWifiMessage),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is Cue && w.spoken == kLocationDeniedMessage,
      ),
      findsNothing,
    );
  });

  testWidgets('"not at work" skips without saving', (tester) async {
    final repo = FakeDayRepository();
    await pump(tester, repo);
    await tester.tap(find.bySemanticsLabel("I'm not at work right now"));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(repo.savedSettings, isEmpty);
  });

  testWidgets('Skip on the explanation closes it', (tester) async {
    await pump(tester, FakeDayRepository(), granted: false);
    await tester.tap(find.bySemanticsLabel('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });
}
