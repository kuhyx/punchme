import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/nfc/background_punch_channel.dart';
import 'package:punchme/nfc/ndef_codec.dart';
import 'package:punchme/nfc/punch_tag.dart';

/// The flavor-specific MIME type.
///
/// The sandbox build filters a different type from the daily one, so a tag
/// written by either is invisible to the other. That separation is what lets
/// the app be tested destructively without risking the real timesheet, so it
/// is worth pinning rather than trusting.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('kuhy.punchme/mime.test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void hostReports(String? mime) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, kGetPunchMimeMethod);
      return mime;
    });
  }

  setUp(() => activePunchMime = kPunchMime);

  tearDown(() {
    activePunchMime = kPunchMime;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('defaults to the daily type', () {
    expect(activePunchMime, 'application/vnd.kuhy.punchme');
  });

  test('adopts the type the host was built with', () async {
    hostReports('application/vnd.kuhy.punchme.sandbox');
    await BackgroundPunchChannel(channel: channel).adoptPunchMime();
    expect(activePunchMime, 'application/vnd.kuhy.punchme.sandbox');
  });

  test('keeps the default when the host reports nothing', () async {
    hostReports(null);
    await BackgroundPunchChannel(channel: channel).adoptPunchMime();
    expect(activePunchMime, kPunchMime);
  });

  test('keeps the default when the host reports an empty type', () async {
    hostReports('');
    await BackgroundPunchChannel(channel: channel).adoptPunchMime();
    expect(activePunchMime, kPunchMime);
  });

  test('keeps the default off Android, where there is no host', () async {
    await BackgroundPunchChannel(
      channel: const MethodChannel('kuhy.punchme/absent-host'),
    ).adoptPunchMime();
    expect(activePunchMime, kPunchMime);
  });

  test('a tag written under one type is unreadable under the other', () {
    // The whole point of the flavor split: the sandbox build writes a record
    // the daily build must not accept as a clock tag.
    activePunchMime = 'application/vnd.kuhy.punchme.sandbox';
    final sandboxTag = buildPunchMessage(const PunchTag(label: 'test'));
    expect(readPunchTag(sandboxTag), const PunchTag(label: 'test'));

    activePunchMime = kPunchMime;
    expect(readPunchTag(sandboxTag), isNull);
  });

  test('a daily tag still reads under the daily type', () {
    final dailyTag = buildPunchMessage(const PunchTag(label: 'office'));
    expect(readPunchTag(dailyTag), const PunchTag(label: 'office'));
  });
}
