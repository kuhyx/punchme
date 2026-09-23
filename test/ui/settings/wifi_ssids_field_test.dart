import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/ui/settings/wifi_ssids_field.dart';

void main() {
  Future<Set<String>?> pump(
    WidgetTester tester, {
    Set<String> ssids = const <String>{},
    Future<String?> Function()? currentSsid,
    required void Function(Set<String>) record,
  }) async {
    Set<String>? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WifiSsidsField(
            ssids: ssids,
            currentSsid: currentSsid,
            onChanged: (value) {
              latest = value;
              record(value);
            },
          ),
        ),
      ),
    );
    return latest;
  }

  testWidgets('says so when there are none', (tester) async {
    await pump(tester, record: (_) {});
    expect(find.text('No work Wi-Fi networks yet'), findsOneWidget);
  });

  testWidgets('lists existing SSIDs as chips', (tester) async {
    await pump(tester, ssids: const <String>{'Office'}, record: (_) {});
    expect(find.text('Office'), findsOneWidget);
  });

  testWidgets('typing and submitting adds a network', (tester) async {
    Set<String>? recorded;
    await pump(tester, record: (value) => recorded = value);

    await tester.enterText(find.byType(TextField), 'Office');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(recorded, const <String>{'Office'});
  });

  testWidgets('the add button adds the typed network', (tester) async {
    Set<String>? recorded;
    await pump(tester, record: (value) => recorded = value);

    await tester.enterText(find.byType(TextField), 'Office');
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();

    expect(recorded, const <String>{'Office'});
  });

  testWidgets('blank input adds nothing', (tester) async {
    var called = false;
    await pump(tester, record: (_) => called = true);

    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();

    expect(called, isFalse);
  });

  testWidgets('a duplicate name adds nothing', (tester) async {
    var called = false;
    await pump(
      tester,
      ssids: const <String>{'Office'},
      record: (_) => called = true,
    );

    await tester.enterText(find.byType(TextField), 'Office');
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();

    expect(called, isFalse);
  });

  testWidgets('deleting a chip removes that network', (tester) async {
    Set<String>? recorded;
    await pump(
      tester,
      ssids: const <String>{'Office', 'Annex'},
      record: (value) => recorded = value,
    );

    await tester.tap(find.byTooltip('Delete').first);
    await tester.pumpAndSettle();

    expect(recorded, hasLength(1));
  });

  testWidgets('hides the button when no current-network probe is given', (
    tester,
  ) async {
    await pump(tester, record: (_) {});
    expect(find.text('Use current network'), findsNothing);
  });

  testWidgets('use current network adds the reported SSID', (tester) async {
    Set<String>? recorded;
    await pump(
      tester,
      currentSsid: () async => 'Office',
      record: (value) => recorded = value,
    );

    await tester.tap(find.text('Use current network'));
    await tester.pumpAndSettle();

    expect(recorded, const <String>{'Office'});
  });

  testWidgets('use current network does nothing when there is none', (
    tester,
  ) async {
    var called = false;
    await pump(
      tester,
      currentSsid: () async => null,
      record: (_) => called = true,
    );

    await tester.tap(find.text('Use current network'));
    await tester.pumpAndSettle();

    expect(called, isFalse);
  });
}
