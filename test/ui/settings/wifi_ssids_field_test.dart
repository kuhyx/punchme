import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/ui/settings/wifi_ssids_field.dart';
import 'package:punchme/ui/wifi/current_network_picker.dart';

import '../../support/fake_wifi.dart';

void main() {
  late List<Set<String>> changes;
  late int settingsOpened;

  setUp(() {
    changes = <Set<String>>[];
    settingsOpened = 0;
  });

  Future<void> pump(
    WidgetTester tester, {
    Set<String> ssids = const <String>{},
    CurrentNetworkPicker? picker,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WifiSsidsField(
            ssids: ssids,
            picker: picker ?? fakePicker(),
            openSettings: () async => settingsOpened++,
            onChanged: changes.add,
          ),
        ),
      ),
    );
  }

  Future<void> addCurrent(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Add current network'));
    await tester.pumpAndSettle();
  }

  testWidgets('says so when there are none', (tester) async {
    await pump(tester);
    expect(find.bySemanticsLabel('No work Wi-Fi networks yet'), findsOneWidget);
  });

  testWidgets('offers no free-text entry', (tester) async {
    await pump(tester);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('lists existing SSIDs as chips', (tester) async {
    await pump(tester, ssids: const <String>{'Office'});
    expect(find.text('Office'), findsOneWidget);
  });

  testWidgets('adds the network the phone is on', (tester) async {
    await pump(tester, ssids: const <String>{'Annex'});
    await addCurrent(tester);
    expect(changes, <Set<String>>[
      const <String>{'Annex', 'Office'},
    ]);
  });

  testWidgets('a network already listed adds nothing', (tester) async {
    await pump(tester, ssids: const <String>{'Office'});
    await addCurrent(tester);
    expect(changes, isEmpty);
  });

  testWidgets('says to connect first when not on Wi-Fi', (tester) async {
    await pump(tester, picker: fakePicker(ssid: null));
    await addCurrent(tester);
    expect(changes, isEmpty);
    expect(find.bySemanticsLabel(kNotOnWifiMessage), findsOneWidget);
    expect(find.byKey(const Key('onboarding-settings')), findsNothing);
  });

  testWidgets('a refusal explains and offers app settings', (tester) async {
    await pump(
      tester,
      picker: fakePicker(granted: false, requestGrants: false),
    );
    await addCurrent(tester);
    expect(find.bySemanticsLabel(kLocationDeniedMessage), findsOneWidget);

    await tester.tap(find.byKey(const Key('wifi-open-settings')));
    expect(settingsOpened, 1);
  });

  testWidgets('backing out of the explanation reports nothing', (tester) async {
    await pump(
      tester,
      picker: fakePicker(granted: false, explainAccepted: false),
    );
    await addCurrent(tester);
    expect(changes, isEmpty);
    expect(find.bySemanticsLabel(kLocationDeniedMessage), findsNothing);
    expect(find.bySemanticsLabel(kNotOnWifiMessage), findsNothing);
  });

  testWidgets('deleting a chip removes that network', (tester) async {
    await pump(tester, ssids: const <String>{'Office', 'Annex'});
    await tester.tap(find.byTooltip('Delete').first);
    await tester.pumpAndSettle();
    expect(changes.single, hasLength(1));
  });
}
