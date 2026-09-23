/// The platform channel that carries Wi-Fi observations and status.
library;

import 'package:flutter/services.dart';
import 'package:punchme/logic/punch_coordinator.dart';
import 'package:punchme/models/local_date.dart';
import 'package:punchme/wifi/wifi_auto_punch.dart';
import 'package:punchme/wifi/wifi_observation_store.dart';

/// The channel native Wi-Fi transport talks over.
const String kWifiChannelName = 'kuhy.punchme/wifi';

/// The method native calls to report an observation.
const String kRunWifiCheckMethod = 'runWifiCheck';

/// The method Dart calls to ask native for the currently connected SSID.
const String kGetCurrentSsidMethod = 'getCurrentSsid';

/// The method Dart calls to tell native whether any work SSID is configured.
const String kSetWifiArmedMethod = 'setWifiArmed';

/// The method Dart calls to ask native what permissions are granted.
const String kGetWifiStatusMethod = 'getWifiStatus';

/// Answers Wi-Fi observations reported by the foreground service or the
/// periodic worker.
///
/// Kotlin only ever reports "this SSID, at this instant" -- which SSIDs
/// count as work stays a Dart decision, made inside [runWifiCheck].
class WifiChannel {
  /// Creates a channel over [coordinator] and [observations].
  WifiChannel({
    required this.coordinator,
    required this.observations,
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel(kWifiChannelName);

  /// Where a resulting punch is committed.
  final PunchCoordinator coordinator;

  /// Where "last seen" instants persist between observations.
  final WifiObservationStore observations;

  final MethodChannel _channel;

  /// Starts answering observation reports.
  void listen() {
    _channel.setMethodCallHandler((call) async {
      if (call.method != kRunWifiCheckMethod) {
        return null;
      }
      final args = call.arguments as Map<Object?, Object?>?;
      final ssid = args?['ssid'] as String?;
      final atIso = args?['at'] as String?;
      final settings = await coordinator.repository.loadSettings();
      await runWifiCheck(
        coordinator: coordinator,
        observations: observations,
        settings: settings,
        currentSsid: ssid,
        now: atIso == null ? DateTime.now() : parseLocal(atIso),
      );
      return null;
    });
  }

  /// Stops answering, so a disposed engine cannot be called back into.
  void stop() => _channel.setMethodCallHandler(null);
}

/// Asks native for the SSID of the currently connected Wi-Fi network, or
/// null when there is none -- or this build has no host behind the channel.
Future<String?> currentWifiSsid({MethodChannel? channel}) async {
  final ch = channel ?? const MethodChannel(kWifiChannelName);
  try {
    return await ch.invokeMethod<String>(kGetCurrentSsidMethod);
  } on MissingPluginException {
    return null;
  }
}

/// Tells native whether at least one work SSID is configured.
///
/// Native keeps the foreground service and periodic worker running exactly
/// while this is true, without ever being told which SSIDs they are.
Future<void> setWifiArmed({required bool armed, MethodChannel? channel}) async {
  final ch = channel ?? const MethodChannel(kWifiChannelName);
  try {
    await ch.invokeMethod<void>(kSetWifiArmedMethod, armed);
  } on MissingPluginException {
    // No host behind the channel (tests, or a platform with none) -- nothing
    // to arm.
  }
}

/// What native can currently do for the auto-punch feature.
class WifiPermissionStatus {
  /// Creates a status snapshot.
  const WifiPermissionStatus({
    required this.locationGranted,
    required this.notificationGranted,
    required this.serviceRunning,
  });

  /// Rebuilds a status from the channel's raw reply.
  factory WifiPermissionStatus.fromMap(Map<Object?, Object?> map) =>
      WifiPermissionStatus(
        locationGranted: map['locationGranted'] == true,
        notificationGranted: map['notificationGranted'] == true,
        serviceRunning: map['serviceRunning'] == true,
      );

  /// Whether the location permission SSID reads depend on is granted.
  final bool locationGranted;

  /// Whether the notification permission the foreground service needs is
  /// granted. Always true below Android 13, where none is required.
  final bool notificationGranted;

  /// Whether the foreground service is currently armed and running.
  final bool serviceRunning;

  /// Nothing granted and nothing running -- the answer with no host behind
  /// the channel (tests, or a platform with none).
  static const WifiPermissionStatus unavailable = WifiPermissionStatus(
    locationGranted: false,
    notificationGranted: false,
    serviceRunning: false,
  );
}

/// Asks native what permissions are granted and whether the service runs.
Future<WifiPermissionStatus> wifiPermissionStatus({
  MethodChannel? channel,
}) async {
  final ch = channel ?? const MethodChannel(kWifiChannelName);
  try {
    final reply = await ch.invokeMethod<Map<Object?, Object?>>(
      kGetWifiStatusMethod,
    );
    return reply == null
        ? WifiPermissionStatus.unavailable
        : WifiPermissionStatus.fromMap(reply);
  } on MissingPluginException {
    return WifiPermissionStatus.unavailable;
  }
}
