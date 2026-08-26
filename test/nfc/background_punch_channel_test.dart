import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/nfc/background_punch_channel.dart';
import 'package:punchme/nfc/punch_tag.dart';

/// Exercises both directions of the background-punch channel.
///
/// Kotlin never enters lcov, so the Dart end is where the contract is pinned:
/// what a drain returns, what a warm call delivers, and which malformed
/// payloads are dropped rather than committed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(kNfcChannelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Answers `getLaunchPunch` with [reply].
  void hostReplies(Object? reply) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, kGetLaunchPunchMethod);
      return reply;
    });
  }

  /// Delivers an incoming [method] call as the host would.
  Future<void> hostCalls(String method, Object? arguments) =>
      messenger.handlePlatformMessage(
        kNfcChannelName,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall(method, arguments),
        ),
        (_) {},
      );

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('decodePunchPayload', () {
    test('decodes a well-formed payload', () {
      expect(
        decodePunchPayload('{"v":1,"tag":"desk"}'),
        const PunchTag(label: 'desk'),
      );
    });

    test('returns null when the host had no launch tap', () {
      expect(decodePunchPayload(null), isNull);
    });

    test('returns null for an empty payload', () {
      expect(decodePunchPayload(''), isNull);
    });

    test('returns null for a non-string reply', () {
      expect(decodePunchPayload(42), isNull);
    });

    test('returns null for a payload that is not JSON', () {
      expect(decodePunchPayload('not json'), isNull);
    });

    test('returns null for JSON that is not an object', () {
      expect(decodePunchPayload('[1,2]'), isNull);
    });
  });

  group('drainLaunchPunch', () {
    test('returns the tag the app was launched by', () async {
      hostReplies('{"v":1,"tag":"desk"}');
      expect(
        await BackgroundPunchChannel(channel: channel).drainLaunchPunch(),
        const PunchTag(label: 'desk'),
      );
    });

    test('returns null when there was no launch tap', () async {
      hostReplies(null);
      expect(
        await BackgroundPunchChannel(channel: channel).drainLaunchPunch(),
        isNull,
      );
    });

    test('treats a missing host as no launch tap', () async {
      // No mock handler registered at all: what a non-Android host looks like.
      expect(
        await BackgroundPunchChannel(
          channel: const MethodChannel('kuhy.punchme/absent'),
        ).drainLaunchPunch(),
        isNull,
      );
    });

    test('builds the real platform channel when none is injected', () async {
      hostReplies(null);
      expect(await BackgroundPunchChannel().drainLaunchPunch(), isNull);
    });
  });

  group('listen', () {
    test('reports a warm background tap', () async {
      final seen = <PunchTag>[];
      BackgroundPunchChannel(channel: channel).listen(seen.add);
      await hostCalls(kBackgroundPunchMethod, '{"v":1,"tag":"door"}');
      expect(seen, <PunchTag>[const PunchTag(label: 'door')]);
    });

    test('drops a payload it cannot parse', () async {
      final seen = <PunchTag>[];
      BackgroundPunchChannel(channel: channel).listen(seen.add);
      await hostCalls(kBackgroundPunchMethod, 'not json');
      expect(seen, isEmpty);
    });

    test('ignores a method it does not know', () async {
      final seen = <PunchTag>[];
      BackgroundPunchChannel(channel: channel).listen(seen.add);
      await hostCalls('somethingElse', '{"v":1,"tag":"desk"}');
      expect(seen, isEmpty);
    });

    test('stop detaches the handler', () async {
      final seen = <PunchTag>[];
      BackgroundPunchChannel(channel: channel)
        ..listen(seen.add)
        ..stop();
      await hostCalls(kBackgroundPunchMethod, '{"v":1,"tag":"desk"}');
      expect(seen, isEmpty);
    });
  });
}
