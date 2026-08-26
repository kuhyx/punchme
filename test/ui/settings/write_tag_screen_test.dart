import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:punchme/nfc/ndef_codec.dart';
import 'package:punchme/nfc/nfc_service.dart';
import 'package:punchme/nfc/punch_tag.dart';
import 'package:punchme/ui/settings/write_tag_screen.dart';

import '../../nfc/fake_ndef.dart';

void main() {
  /// Builds a service whose session hands back [ndef] as the tapped tag.
  NfcService serviceWith({
    FakeNdef? ndef,
    NfcAvailability availability = NfcAvailability.enabled,
    bool discover = true,
  }) => NfcService(
    availability: () async => availability,
    stopSession: () async {},
    ndefFrom: (_) => ndef,
    startSession:
        ({
          required Set<NfcPollingOption> pollingOptions,
          required void Function(NfcTag) onDiscovered,
        }) async {
          if (discover) {
            onDiscovered(const NfcTag(data: 'x'));
          }
        },
  );

  Future<void> pump(WidgetTester tester, NfcService service) async {
    await tester.pumpWidget(
      MaterialApp(home: WriteTagScreen(service: service)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('writes the typed label onto the tag', (tester) async {
    final ndef = FakeNdef();
    await pump(tester, serviceWith(ndef: ndef));

    await tester.enterText(find.byType(TextField), 'kitchen');
    await tester.tap(find.text('Write tag'));
    await tester.pumpAndSettle();

    expect(readPunchTag(ndef.written.single), const PunchTag(label: 'kitchen'));
    expect(find.textContaining('Tag written'), findsOneWidget);
  });

  testWidgets('defaults the label when it is left blank', (tester) async {
    final ndef = FakeNdef();
    await pump(tester, serviceWith(ndef: ndef));

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Write tag'));
    await tester.pumpAndSettle();

    expect(
      readPunchTag(ndef.written.single),
      const PunchTag(label: kDefaultTagLabel),
    );
  });

  testWidgets('asks for NFC to be turned on', (tester) async {
    await pump(tester, serviceWith(availability: NfcAvailability.disabled));

    await tester.tap(find.text('Write tag'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Turn NFC on'), findsOneWidget);
  });

  testWidgets('waits, and disables the field, until a tag arrives', (
    tester,
  ) async {
    await pump(tester, serviceWith(discover: false));

    await tester.tap(find.text('Write tag'));
    await tester.pumpAndSettle();

    expect(find.text('Waiting for a tag...'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
  });

  group('failures', () {
    Future<void> expectMessage(
      WidgetTester tester,
      FakeNdef? ndef,
      String fragment,
    ) async {
      await pump(tester, serviceWith(ndef: ndef));
      await tester.tap(find.text('Write tag'));
      await tester.pumpAndSettle();
      expect(find.textContaining(fragment), findsOneWidget);
    }

    testWidgets('a locked tag', (tester) async {
      await expectMessage(tester, FakeNdef(isWritable: false), 'locked');
    });

    testWidgets('a tag with no NDEF at all', (tester) async {
      await expectMessage(tester, null, 'locked');
    });

    testWidgets('a tag that is too small', (tester) async {
      await expectMessage(tester, FakeNdef(maxSize: 4), 'too small');
    });

    testWidgets('a tag pulled away mid-write', (tester) async {
      await expectMessage(
        tester,
        FakeNdef(throwOnWrite: true),
        'moved away too soon',
      );
    });

    testWidgets('a tag that reads back wrong', (tester) async {
      await expectMessage(
        tester,
        FakeNdef(readBack: buildPunchMessage(const PunchTag(label: 'other'))),
        'did not read back',
      );
    });
  });

  testWidgets('stops the session when the screen goes away', (tester) async {
    var stopped = 0;
    final service = NfcService(
      availability: () async => NfcAvailability.enabled,
      stopSession: () async => stopped++,
      ndefFrom: (_) => null,
      startSession:
          ({
            required Set<NfcPollingOption> pollingOptions,
            required void Function(NfcTag) onDiscovered,
          }) async {},
    );
    await pump(tester, service);
    await tester.tap(find.text('Write tag'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();

    expect(stopped, 1);
  });

  test('every failure has its own message', () {
    final seen = NfcWriteFailure.values.map(writeFailureMessage).toSet();
    expect(seen, hasLength(NfcWriteFailure.values.length));
  });
}
