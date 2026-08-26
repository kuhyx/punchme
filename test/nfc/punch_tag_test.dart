import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/nfc/punch_tag.dart';

Uint8List bytes(String text) => Uint8List.fromList(utf8.encode(text));

void main() {
  group('PunchTag', () {
    test('round-trips through bytes', () {
      const tag = PunchTag(label: 'desk');
      expect(PunchTag.fromBytes(tag.toBytes()), tag);
    });

    test('writes the documented wire shape', () {
      expect(const PunchTag(label: 'desk').toJson(), <String, dynamic>{
        'v': 1,
        'tag': 'desk',
      });
    });

    test('defaults v to 1 and tag to "default"', () {
      final tag = PunchTag.fromBytes(bytes('{}'));
      expect(tag.version, 1);
      expect(tag.label, 'default');
      expect(tag.isKnownVersion, isTrue);
    });

    test('ignores unknown and extra fields', () {
      final tag = PunchTag.fromBytes(
        bytes('{"v":1,"tag":"desk","note":"hi","extra":[1,2]}'),
      );
      expect(tag, const PunchTag(label: 'desk'));
    });

    test('keeps an unknown version but flags it', () {
      final tag = PunchTag.fromBytes(bytes('{"v":7,"tag":"desk"}'));
      expect(tag.version, 7);
      expect(tag.isKnownVersion, isFalse);
    });

    test('falls back when fields are the wrong type', () {
      final tag = PunchTag.fromBytes(bytes('{"v":"one","tag":42}'));
      expect(tag.version, 1);
      expect(tag.label, 'default');
    });

    test('falls back on an empty label', () {
      expect(PunchTag.fromBytes(bytes('{"tag":""}')).label, 'default');
    });

    test('rejects malformed JSON', () {
      expect(
        () => PunchTag.fromBytes(bytes('{not json')),
        throwsFormatException,
      );
    });

    test('rejects a payload that is not an object', () {
      expect(() => PunchTag.fromBytes(bytes('[1,2]')), throwsFormatException);
      expect(() => PunchTag.fromBytes(bytes('"x"')), throwsFormatException);
    });

    test('rejects invalid UTF-8', () {
      expect(
        () => PunchTag.fromBytes(Uint8List.fromList(<int>[0xC3, 0x28])),
        throwsFormatException,
      );
    });

    test('has value equality and a readable toString', () {
      expect(const PunchTag(label: 'a'), const PunchTag(label: 'a'));
      expect(
        const PunchTag(label: 'a').hashCode,
        const PunchTag(label: 'a').hashCode,
      );
      expect(const PunchTag(label: 'a'), isNot(const PunchTag(label: 'b')));
      expect(const PunchTag(label: 'desk').toString(), 'PunchTag(v1, desk)');
    });
  });
}
