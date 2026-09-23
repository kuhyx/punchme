import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/logic/punch_coordinator.dart';
import 'package:punchme/models/settings.dart';
import 'package:punchme/wifi/wifi_channel.dart';
import 'package:punchme/wifi/wifi_observation_store.dart';

import '../support/fake_day_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(kWifiChannelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late Directory dir;
  late WifiObservationStore observations;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('punchme_wifi_channel_test');
    observations = WifiObservationStore(File('${dir.path}/wifi.json'));
  });

  tearDown(() {
    dir.deleteSync(recursive: true);
    messenger.setMockMethodCallHandler(channel, null);
  });

  Future<Object?> hostCalls(String method, Object? arguments) async {
    final reply = await messenger.handlePlatformMessage(
      kWifiChannelName,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(method, arguments),
      ),
      (_) {},
    );
    return reply == null
        ? null
        : const StandardMethodCodec().decodeEnvelope(reply);
  }

  group('WifiChannel', () {
    test('commits a check-in from a reported observation', () async {
      final repo = FakeDayRepository(
        settings: const Settings(workWifiSsids: <String>{'Office'}),
      );
      WifiChannel(
        coordinator: PunchCoordinator(repository: repo),
        observations: observations,
        channel: channel,
      ).listen();

      await hostCalls(kRunWifiCheckMethod, <String, Object?>{
        'ssid': 'Office',
        'at': '2026-08-25T09:00:00.000+00:00',
      });

      expect(repo.savedDays, hasLength(1));
      expect(repo.savedDays.single.checkOut, isNull);
    });

    test('falls back to the real clock when no instant is given', () async {
      final repo = FakeDayRepository(
        settings: const Settings(workWifiSsids: <String>{'Office'}),
      );
      WifiChannel(
        coordinator: PunchCoordinator(repository: repo),
        observations: observations,
        channel: channel,
      ).listen();

      await hostCalls(kRunWifiCheckMethod, <String, Object?>{'ssid': 'Office'});

      expect(repo.savedDays, hasLength(1));
    });

    test('ignores a method it does not know', () async {
      final repo = FakeDayRepository();
      WifiChannel(
        coordinator: PunchCoordinator(repository: repo),
        observations: observations,
        channel: channel,
      ).listen();

      final reply = await hostCalls('somethingElse', null);

      expect(reply, isNull);
      expect(repo.savedDays, isEmpty);
    });

    test('stop detaches the handler', () async {
      final repo = FakeDayRepository(
        settings: const Settings(workWifiSsids: <String>{'Office'}),
      );
      WifiChannel(
          coordinator: PunchCoordinator(repository: repo),
          observations: observations,
          channel: channel,
        )
        ..listen()
        ..stop();

      await hostCalls(kRunWifiCheckMethod, <String, Object?>{'ssid': 'Office'});

      expect(repo.savedDays, isEmpty);
    });

    test('builds the real channel when none is injected', () {
      expect(
        () => WifiChannel(
          coordinator: PunchCoordinator(repository: FakeDayRepository()),
          observations: observations,
        ).listen(),
        returnsNormally,
      );
    });
  });

  group('currentWifiSsid', () {
    test('returns what the host reports', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, kGetCurrentSsidMethod);
        return 'Office';
      });
      expect(await currentWifiSsid(channel: channel), 'Office');
    });

    test('treats a missing host as no current network', () async {
      expect(
        await currentWifiSsid(
          channel: const MethodChannel('kuhy.punchme/wifi.absent'),
        ),
        isNull,
      );
    });

    test('builds the real channel when none is injected', () async {
      expect(await currentWifiSsid(), isNull);
    });
  });

  group('setWifiArmed', () {
    test('sends the armed flag to the host', () async {
      final calls = <Object?>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.arguments);
        return null;
      });
      await setWifiArmed(armed: true, channel: channel);
      expect(calls, <Object?>[true]);
    });

    test('treats a missing host as nothing to arm', () async {
      await expectLater(
        setWifiArmed(
          armed: true,
          channel: const MethodChannel('kuhy.punchme/wifi.absent'),
        ),
        completes,
      );
    });

    test('builds the real channel when none is injected', () async {
      await expectLater(setWifiArmed(armed: false), completes);
    });
  });

  group('WifiPermissionStatus', () {
    test('reads a full status map', () {
      final status = WifiPermissionStatus.fromMap(<Object?, Object?>{
        'locationGranted': true,
        'notificationGranted': false,
        'serviceRunning': true,
      });
      expect(status.locationGranted, isTrue);
      expect(status.notificationGranted, isFalse);
      expect(status.serviceRunning, isTrue);
    });

    test('treats a missing key as false', () {
      final status = WifiPermissionStatus.fromMap(const <Object?, Object?>{});
      expect(status.locationGranted, isFalse);
      expect(status.notificationGranted, isFalse);
      expect(status.serviceRunning, isFalse);
    });
  });

  group('wifiPermissionStatus', () {
    test('returns what the host reports', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, kGetWifiStatusMethod);
        return <Object?, Object?>{
          'locationGranted': true,
          'notificationGranted': true,
          'serviceRunning': true,
        };
      });
      final status = await wifiPermissionStatus(channel: channel);
      expect(status.locationGranted, isTrue);
    });

    test('treats a missing host as unavailable', () async {
      final status = await wifiPermissionStatus(
        channel: const MethodChannel('kuhy.punchme/wifi.absent'),
      );
      expect(status.locationGranted, isFalse);
      expect(status.serviceRunning, isFalse);
    });

    test('treats a null reply as unavailable', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      final status = await wifiPermissionStatus(channel: channel);
      expect(status.serviceRunning, isFalse);
    });

    test('builds the real channel when none is injected', () async {
      final status = await wifiPermissionStatus();
      expect(status.serviceRunning, isFalse);
    });
  });
}
