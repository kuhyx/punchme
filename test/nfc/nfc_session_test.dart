import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:punchme/nfc/nfc_service.dart';
import 'package:punchme/nfc/nfc_session.dart';
import 'package:punchme/nfc/punch_tag.dart';

import 'fake_ndef.dart';

void main() {
  late int starts;
  late int stops;
  late List<PunchTag> punches;
  late NfcAvailability availability;
  late void Function(NfcTag)? discovered;

  setUp(() {
    starts = 0;
    stops = 0;
    punches = <PunchTag>[];
    availability = NfcAvailability.enabled;
    discovered = null;
  });

  NfcService buildService() => NfcService(
    availability: () async => availability,
    stopSession: () async => stops++,
    ndefFrom: (_) => FakeNdef(cachedMessage: buildPunchMessageFor('desk')),
    startSession:
        ({
          required Set<NfcPollingOption> pollingOptions,
          required void Function(NfcTag) onDiscovered,
        }) async {
          starts++;
          discovered = onDiscovered;
        },
  );

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NfcSession(
          service: buildService(),
          onPunch: punches.add,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('starts a session on mount', (tester) async {
    await pump(tester);
    expect(starts, 1);
  });

  testWidgets('does not start when NFC is off', (tester) async {
    availability = NfcAvailability.disabled;
    await pump(tester);
    expect(starts, 0);
  });

  testWidgets('delivers a tag read to onPunch', (tester) async {
    await pump(tester);
    discovered!(const NfcTag(data: 'x'));
    expect(punches.single, const PunchTag(label: 'desk'));
  });

  testWidgets('stops when backgrounded and restarts on resume', (
    tester,
  ) async {
    await pump(tester);
    expect(starts, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(stops, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(starts, 2);
  });

  testWidgets('does not stack sessions on a repeated resume', (tester) async {
    await pump(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(starts, 1);
  });

  testWidgets('stops when the widget goes away', (tester) async {
    await pump(tester);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();
    expect(stops, 1);
  });
}
