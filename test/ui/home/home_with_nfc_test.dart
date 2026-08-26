import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:punchme/nfc/nfc_service.dart';
import 'package:punchme/ui/home/check_button.dart';
import 'package:punchme/ui/home/punch_banner.dart';
import 'package:punchme/ui/home/home_with_nfc.dart';

import '../../nfc/fake_ndef.dart';
import '../../support/fake_day_repository.dart';

void main() {
  testWidgets('a tag read punches the home screen', (tester) async {
    late void Function(NfcTag) discovered;
    final repo = FakeDayRepository();
    final service = NfcService(
      availability: () async => NfcAvailability.enabled,
      stopSession: () async {},
      ndefFrom: (_) => FakeNdef(cachedMessage: buildPunchMessageFor('desk')),
      startSession:
          ({
            required Set<NfcPollingOption> pollingOptions,
            required void Function(NfcTag) onDiscovered,
          }) async => discovered = onDiscovered,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeWithNfc(repository: repo, service: service),
      ),
    );
    await tester.pumpAndSettle();

    discovered(const NfcTag(data: 'x'));
    await tester.pump();
    await tester.pump(commitWindow);
    await tester.pumpAndSettle();

    // A check-in that raises the alarm dialog hands the message off to it:
    // the banner is cleared so a failed alarm is not queued behind it. The
    // banner itself is covered for check-out, and for a check-in with no
    // target, in nfc_punch_test.dart.
    expect(find.text('Set alarm'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(repo.savedDays, hasLength(1));
    expect(repo.savedDays.single.checkOut, isNull);
    expect(find.text('CHECK OUT'), findsOneWidget);
  });

  testWidgets('an unwritten tag prompts for the write screen', (tester) async {
    late void Function(NfcTag) discovered;
    final repo = FakeDayRepository();
    final service = NfcService(
      availability: () async => NfcAvailability.enabled,
      stopSession: () async {},
      // A blank tag: readable, but carrying no NDEF message at all.
      ndefFrom: (_) => FakeNdef(),
      startSession:
          ({
            required Set<NfcPollingOption> pollingOptions,
            required void Function(NfcTag) onDiscovered,
          }) async => discovered = onDiscovered,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeWithNfc(repository: repo, service: service),
      ),
    );
    await tester.pumpAndSettle();

    discovered(const NfcTag(data: 'x'));
    await tester.pumpAndSettle();

    expect(find.text(kBlankTagMessage), findsOneWidget);
    expect(repo.savedDays, isEmpty);
    expect(find.text('CHECK IN'), findsOneWidget);
  });

  testWidgets('builds a real service when none is injected', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeWithNfc(repository: FakeDayRepository())),
    );
    await tester.pumpAndSettle();
    expect(find.text('CHECK IN'), findsOneWidget);
  });
}
