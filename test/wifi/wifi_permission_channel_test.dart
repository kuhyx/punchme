import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/wifi/wifi_channel.dart';

/// The two calls that act on permissions rather than report them.
///
/// Split from `wifi_channel_test.dart` to stay under the 250-line gate.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(kWifiChannelName);
  const absent = MethodChannel('kuhy.punchme/wifi.absent');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('requestWifiLocation', () {
    test('returns the answer the host reports', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, kRequestLocationMethod);
        return true;
      });
      expect(await requestWifiLocation(channel: channel), isTrue);
    });

    test('treats no answer as refused', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      expect(await requestWifiLocation(channel: channel), isFalse);
    });

    test('treats a missing host as refused', () async {
      expect(await requestWifiLocation(channel: absent), isFalse);
    });

    test('builds the real channel when none is injected', () async {
      expect(await requestWifiLocation(), isFalse);
    });
  });

  group('openWifiAppSettings', () {
    test('asks the host to open the settings page', () async {
      final methods = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        methods.add(call.method);
        return null;
      });
      await openWifiAppSettings(channel: channel);
      expect(methods, <String>[kOpenAppSettingsMethod]);
    });

    test('treats a missing host as nothing to open', () async {
      await expectLater(openWifiAppSettings(channel: absent), completes);
    });

    test('builds the real channel when none is injected', () async {
      await expectLater(openWifiAppSettings(), completes);
    });
  });
}
