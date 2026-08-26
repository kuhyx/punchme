/// Turning NDEF messages into [PunchTag]s and back.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:nfc_manager/ndef_record.dart';
import 'package:punchme/nfc/punch_tag.dart';

/// The MIME type as the raw bytes an NDEF record stores in its type field.
final Uint8List _mimeBytes = Uint8List.fromList(ascii.encode(kPunchMime));

/// Whether [record] is a punchme clock-tag record.
///
/// A MIME record is `TypeNameFormat.media` whose type field holds the MIME
/// string. Anything else -- a URL, a text record, another app's MIME type --
/// is somebody else's tag and is not ours to interpret.
bool isPunchRecord(NdefRecord record) =>
    record.typeNameFormat == TypeNameFormat.media &&
    _bytesEqual(record.type, _mimeBytes);

/// Extracts the punch tag from [message], or null when there is none.
///
/// Null is the ordinary "not our tag" answer and callers ignore it silently.
/// A [FormatException] escapes only when a record *is* ours and its payload is
/// malformed, which is a real error worth showing.
PunchTag? readPunchTag(NdefMessage message) {
  for (final record in message.records) {
    if (isPunchRecord(record)) {
      return PunchTag.fromBytes(record.payload);
    }
  }
  return null;
}

/// Builds the NDEF message that [tag] is written to a blank tag as.
///
/// `ndef_record` has no `createMime` helper -- that was the 3.x API -- so the
/// record is assembled from its fields: media format, MIME bytes as the type,
/// no identifier, UTF-8 JSON as the payload.
NdefMessage buildPunchMessage(PunchTag tag) => NdefMessage(
  records: <NdefRecord>[
    NdefRecord(
      typeNameFormat: TypeNameFormat.media,
      type: _mimeBytes,
      identifier: Uint8List(0),
      payload: tag.toBytes(),
    ),
  ],
);

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
