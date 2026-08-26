import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:punchme/nfc/ndef_codec.dart';
import 'package:punchme/nfc/punch_tag.dart';

NdefRecord record({
  required TypeNameFormat format,
  required String type,
  required String payload,
}) => NdefRecord(
  typeNameFormat: format,
  type: Uint8List.fromList(ascii.encode(type)),
  identifier: Uint8List(0),
  payload: Uint8List.fromList(utf8.encode(payload)),
);

void main() {
  group('buildPunchMessage', () {
    test('builds a single media record carrying the punchme MIME', () {
      final message = buildPunchMessage(const PunchTag(label: 'desk'));
      final only = message.records.single;
      expect(only.typeNameFormat, TypeNameFormat.media);
      expect(ascii.decode(only.type), kPunchMime);
      expect(only.identifier, isEmpty);
      expect(jsonDecode(utf8.decode(only.payload)), <String, dynamic>{
        'v': 1,
        'tag': 'desk',
      });
    });

    test('round-trips through readPunchTag', () {
      const tag = PunchTag(label: 'desk');
      expect(readPunchTag(buildPunchMessage(tag)), tag);
    });

    test('reports a byte length a capacity check can use', () {
      expect(buildPunchMessage(const PunchTag()).byteLength, greaterThan(0));
    });
  });

  group('readPunchTag', () {
    test('finds our record among foreign ones', () {
      final message = NdefMessage(
        records: <NdefRecord>[
          record(format: TypeNameFormat.wellKnown, type: 'T', payload: 'hi'),
          record(
            format: TypeNameFormat.media,
            type: 'text/plain',
            payload: 'nope',
          ),
          buildPunchMessage(const PunchTag(label: 'desk')).records.single,
        ],
      );
      expect(readPunchTag(message), const PunchTag(label: 'desk'));
    });

    test('returns null for an empty message', () {
      expect(readPunchTag(const NdefMessage(records: <NdefRecord>[])), isNull);
    });

    test('returns null for a well-known text record', () {
      final message = NdefMessage(
        records: <NdefRecord>[
          record(format: TypeNameFormat.wellKnown, type: 'T', payload: 'hi'),
        ],
      );
      expect(readPunchTag(message), isNull);
    });

    test('returns null for another app\'s MIME type', () {
      final message = NdefMessage(
        records: <NdefRecord>[
          record(
            format: TypeNameFormat.media,
            type: 'application/vnd.other.app',
            payload: '{"v":1}',
          ),
        ],
      );
      expect(readPunchTag(message), isNull);
    });

    test('rejects a same-length MIME type that is not ours', () {
      final other = 'application/vnd.kuhy.punchmX';
      expect(other.length, kPunchMime.length);
      final message = NdefMessage(
        records: <NdefRecord>[
          record(format: TypeNameFormat.media, type: other, payload: '{}'),
        ],
      );
      expect(readPunchTag(message), isNull);
    });

    test('throws when our own record carries a bad payload', () {
      final message = NdefMessage(
        records: <NdefRecord>[
          record(
            format: TypeNameFormat.media,
            type: kPunchMime,
            payload: 'not json',
          ),
        ],
      );
      expect(() => readPunchTag(message), throwsFormatException);
    });
  });
}
