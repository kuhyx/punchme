import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform/platform.dart';
import 'package:punchme/logic/checkout_alarm.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dev.fluttercommunity.plus/android_intent');
  late List<MethodCall> calls;

  setUp(() {
    // launch() no-ops off Android, and the test host is Linux.
    alarmPlatform = FakePlatform(operatingSystem: Platform.android);
    calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    alarmPlatform = const LocalPlatform();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('launches ACTION_SET_ALARM with the hour and minute', () async {
    await setCheckOutAlarm(
      at: DateTime(2026, 8, 26, 16, 49),
      message: 'punchme: check out',
    );

    expect(calls, hasLength(1));
    final args = calls.single.arguments as Map<dynamic, dynamic>;
    expect(args['action'], 'android.intent.action.SET_ALARM');
    final extras = args['arguments'] as Map<dynamic, dynamic>;
    expect(extras['android.intent.extra.alarm.HOUR'], 16);
    expect(extras['android.intent.extra.alarm.MINUTES'], 49);
    expect(extras['android.intent.extra.alarm.MESSAGE'], 'punchme: check out');
  });

  test(
    'shows the Clock app UI rather than creating an alarm silently',
    () async {
      await setCheckOutAlarm(at: DateTime(2026, 8, 26, 9), message: 'x');

      final args = calls.single.arguments as Map<dynamic, dynamic>;
      final extras = args['arguments'] as Map<dynamic, dynamic>;
      expect(extras['android.intent.extra.alarm.SKIP_UI'], false);
    },
  );

  test(
    'gives up rather than hanging when the Clock app never replies',
    () async {
      // android_intent_plus v5 uses startActivityForResult and the Clock app
      // sends no result, so a missing reply must time out, not hang forever.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            await Future<void>.delayed(const Duration(seconds: 30));
            return null;
          });

      await expectLater(
        setCheckOutAlarm(at: DateTime(2026, 8, 26, 9), message: 'x'),
        completes,
      );
    },
  );
}
