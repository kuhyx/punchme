import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import 'package:punchme/nfc/ndef_codec.dart';
import 'package:punchme/nfc/nfc_service.dart';
import 'package:punchme/nfc/punch_tag.dart';

import 'fake_ndef.dart';

const NfcTag tag = NfcTag(data: 'x');

void main() {
  group('reading', () {
    late List<PunchTag> punches;
    late int others;

    setUp(() {
      punches = <PunchTag>[];
      others = 0;
    });

    Future<void> discover(Ndef? ndef) async {
      final service = NfcService(
        startSession:
            ({
              required Set<NfcPollingOption> pollingOptions,
              required void Function(NfcTag) onDiscovered,
            }) async {
              expect(pollingOptions, <NfcPollingOption>{
                NfcPollingOption.iso14443,
              });
              onDiscovered(tag);
            },
        ndefFrom: (_) => ndef,
      );
      await service.startReading(
        onPunch: punches.add,
        onOther: () => others++,
      );
    }

    test('reports a punchme tag', () async {
      await discover(
        FakeNdef(
          cachedMessage: buildPunchMessage(const PunchTag(label: 'desk')),
        ),
      );
      expect(punches.single, const PunchTag(label: 'desk'));
      expect(others, 0);
    });

    test('treats a tag with no NDEF as blank', () async {
      await discover(null);
      expect(punches, isEmpty);
      expect(others, 1);
    });

    test('treats an empty tag as blank', () async {
      await discover(FakeNdef());
      expect(others, 1);
    });

    test('ignores a foreign tag', () async {
      await discover(
        FakeNdef(
          cachedMessage: NdefMessage(
            records: <NdefRecord>[
              NdefRecord(
                typeNameFormat: TypeNameFormat.wellKnown,
                type: Uint8List.fromList(<int>[84]),
                identifier: Uint8List(0),
                payload: Uint8List.fromList(<int>[1]),
              ),
            ],
          ),
        ),
      );
      expect(punches, isEmpty);
      expect(others, 1);
    });

    test('treats our own corrupt payload as not-a-clock-tag', () async {
      await discover(
        FakeNdef(
          cachedMessage: NdefMessage(
            records: <NdefRecord>[
              NdefRecord(
                typeNameFormat: TypeNameFormat.media,
                type: Uint8List.fromList(kPunchMime.codeUnits),
                identifier: Uint8List(0),
                payload: Uint8List.fromList('nope'.codeUnits),
              ),
            ],
          ),
        ),
      );
      expect(punches, isEmpty);
      expect(others, 1);
    });

    test('survives a missing onOther callback', () async {
      final service = NfcService(
        startSession:
            ({
              required Set<NfcPollingOption> pollingOptions,
              required void Function(NfcTag) onDiscovered,
            }) async => onDiscovered(tag),
        ndefFrom: (_) => null,
      );
      await service.startReading(onPunch: punches.add);
      expect(punches, isEmpty);
    });

    test('stops the session', () async {
      var stopped = false;
      await NfcService(
        stopSession: () async => stopped = true,
      ).stopReading();
      expect(stopped, isTrue);
    });
  });

  group('writing', () {
    Future<void> write(FakeNdef? ndef) =>
        NfcService(
          ndefFrom: (_) => ndef,
        ).writeTag(
          discovered: tag,
          tag: const PunchTag(label: 'desk'),
        );

    NfcWriteFailure failureOf(Object e) => (e as NfcWriteException).failure;

    test('writes and verifies', () async {
      final ndef = FakeNdef();
      await write(ndef);
      expect(readPunchTag(ndef.written.single), const PunchTag(label: 'desk'));
    });

    test('rejects a tag with no NDEF', () async {
      await expectLater(
        write(null),
        throwsA(
          predicate<Object>(
            (e) => failureOf(e) == NfcWriteFailure.notWritable,
          ),
        ),
      );
    });

    test('rejects a locked tag', () async {
      await expectLater(
        write(FakeNdef(isWritable: false)),
        throwsA(
          predicate<Object>(
            (e) => failureOf(e) == NfcWriteFailure.notWritable,
          ),
        ),
      );
    });

    test('rejects a tag that is too small', () async {
      await expectLater(
        write(FakeNdef(maxSize: 4)),
        throwsA(
          predicate<Object>((e) => failureOf(e) == NfcWriteFailure.tooLarge),
        ),
      );
    });

    test('reports a tag pulled out mid-write', () async {
      await expectLater(
        write(FakeNdef(throwOnWrite: true)),
        throwsA(
          predicate<Object>(
            (e) => failureOf(e) == NfcWriteFailure.interrupted,
          ),
        ),
      );
    });

    test('reports a read-back that comes up empty', () async {
      final ndef = FakeNdef()..readBack = null;
      // write() would fill readBack, so force the empty case explicitly.
      await expectLater(
        NfcService(
          ndefFrom: (_) => EmptyReadNdef(),
        ).writeTag(discovered: tag, tag: const PunchTag()),
        throwsA(
          predicate<Object>(
            (e) => failureOf(e) == NfcWriteFailure.verifyMismatch,
          ),
        ),
      );
      expect(ndef.readBack, isNull);
    });

    test('reports a read-back that disagrees', () async {
      await expectLater(
        NfcService(
          ndefFrom: (_) => FakeNdef(
            readBack: buildPunchMessage(const PunchTag(label: 'other')),
          ),
        ).writeTag(
          discovered: tag,
          tag: const PunchTag(label: 'desk'),
        ),
        throwsA(
          predicate<Object>(
            (e) => failureOf(e) == NfcWriteFailure.verifyMismatch,
          ),
        ),
      );
    });

    test('exception prints its reason', () {
      expect(
        const NfcWriteException(NfcWriteFailure.tooLarge).toString(),
        contains('tooLarge'),
      );
    });
  });
}
