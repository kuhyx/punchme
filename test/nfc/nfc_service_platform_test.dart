import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:punchme/nfc/nfc_service.dart';

/// Exercises the real plugin-backed defaults.
///
/// nfc_manager's Android layer is pigeon-generated, so its channels can be
/// answered here. That keeps the default functions genuinely covered instead
/// of stubbed out behind a coverage suppression -- this repo has exactly one
/// of those, and this feature does not add more.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const prefix = 'dev.flutter.pigeon.nfc_manager.HostApiPigeon';
  late List<String> calls;

  void answer(String method, Object? reply) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('$prefix.$method', (ByteData? message) async {
          calls.add(method);
          return const StandardMessageCodec().encodeMessage(<Object?>[reply]);
        });
  }

  setUp(() {
    calls = <String>[];
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    for (final method in <String>[
      'nfcAdapterIsEnabled',
      'nfcAdapterEnableReaderMode',
      'nfcAdapterDisableReaderMode',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('$prefix.$method', null);
    }
  });

  test('checkAvailability reports an enabled adapter', () async {
    answer('nfcAdapterIsEnabled', true);
    expect(await NfcService().checkAvailability(), NfcAvailability.enabled);
    expect(calls, <String>['nfcAdapterIsEnabled']);
  });

  test('checkAvailability reports a disabled adapter', () async {
    answer('nfcAdapterIsEnabled', false);
    expect(await NfcService().checkAvailability(), NfcAvailability.disabled);
  });

  test('startReading enables reader mode', () async {
    answer('nfcAdapterEnableReaderMode', null);
    await NfcService().startReading(onPunch: (_) {});
    expect(calls, <String>['nfcAdapterEnableReaderMode']);
  });

  test('stopReading disables reader mode', () async {
    answer('nfcAdapterDisableReaderMode', null);
    await NfcService().stopReading();
    expect(calls, <String>['nfcAdapterDisableReaderMode']);
  });
}
