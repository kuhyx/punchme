import 'package:nfc_manager/ndef_record.dart';
import 'package:punchme/nfc/ndef_codec.dart';
import 'package:punchme/nfc/punch_tag.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

/// A hand-written Ndef stand-in; the repo uses fakes, not a mocking package.
class FakeNdef implements Ndef {
  FakeNdef({
    this.cachedMessage,
    this.isWritable = true,
    this.maxSize = 256,
    this.readBack,
    this.throwOnWrite = false,
  });

  @override
  final NdefMessage? cachedMessage;
  @override
  final bool isWritable;
  @override
  final int maxSize;

  NdefMessage? readBack;
  final bool throwOnWrite;
  final List<NdefMessage> written = <NdefMessage>[];

  @override
  Map<String, dynamic> get additionalData => <String, dynamic>{};

  @override
  Future<NdefMessage?> read() async => readBack;

  @override
  Future<void> write({required NdefMessage message}) async {
    if (throwOnWrite) {
      throw Exception('tag removed');
    }
    written.add(message);
    readBack ??= message;
  }

  @override
  Future<void> writeLock() async {}
}

/// An Ndef whose read-back always comes up empty.
class EmptyReadNdef extends FakeNdef {
  @override
  Future<NdefMessage?> read() async => null;
}

/// A one-record punchme message labelled [label].
NdefMessage buildPunchMessageFor(String label) =>
    buildPunchMessage(PunchTag(label: label));
