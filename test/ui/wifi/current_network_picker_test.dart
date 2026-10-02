import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/ui/wifi/current_network_picker.dart';

import '../../support/fake_wifi.dart';

void main() {
  /// Runs [picker] from a live context and returns what it produced.
  Future<NetworkPick> run(
    WidgetTester tester,
    CurrentNetworkPicker picker,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));
    return picker.pick(context);
  }

  testWidgets('granted: reads the SSID with no explanation', (tester) async {
    var explained = false;
    final pick = await run(
      tester,
      CurrentNetworkPicker(
        status: () async => locationStatus(granted: true),
        requestLocation: () async => fail('must not prompt'),
        currentSsid: () async => 'Office',
        explain: (_) async => explained = true,
      ),
    );
    expect(pick.ssid, 'Office');
    expect(pick.message, isNull);
    expect(explained, isFalse);
  });

  testWidgets('not granted: explains before prompting', (tester) async {
    final order = <String>[];
    final pick = await run(
      tester,
      CurrentNetworkPicker(
        status: () async => locationStatus(granted: false),
        requestLocation: () async {
          order.add('prompt');
          return true;
        },
        currentSsid: () async => 'Office',
        explain: (_) async {
          order.add('explain');
          return true;
        },
      ),
    );
    expect(order, <String>['explain', 'prompt']);
    expect(pick.ssid, 'Office');
  });

  testWidgets('backing out of the explanation never prompts', (tester) async {
    final pick = await run(
      tester,
      CurrentNetworkPicker(
        status: () async => locationStatus(granted: false),
        requestLocation: () async => fail('must not prompt'),
        currentSsid: () async => 'Office',
        explain: (_) async => false,
      ),
    );
    expect(pick, same(NetworkPick.cancelled));
    expect(pick.message, isNull);
  });

  testWidgets('a refused prompt reports denied', (tester) async {
    final pick = await run(
      tester,
      fakePicker(granted: false, requestGrants: false),
    );
    expect(pick, same(NetworkPick.denied));
    expect(pick.needsSettings, isTrue);
  });

  testWidgets('no Wi-Fi reports not-on-Wi-Fi', (tester) async {
    final pick = await run(tester, fakePicker(ssid: null));
    expect(pick, same(NetworkPick.notOnWifi));
    expect(pick.needsSettings, isFalse);
  });

  testWidgets('a context gone before the explanation cancels', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));
    await tester.pumpWidget(const SizedBox());
    final pick = await fakePicker(granted: false).pick(context);
    expect(pick, same(NetworkPick.cancelled));
  });
}
