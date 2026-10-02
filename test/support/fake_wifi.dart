import 'package:punchme/ui/wifi/current_network_picker.dart';
import 'package:punchme/wifi/wifi_channel.dart';

/// A permission status with only location set.
WifiPermissionStatus locationStatus({required bool granted}) =>
    WifiPermissionStatus(
      locationGranted: granted,
      notificationGranted: true,
      serviceRunning: false,
    );

/// A picker that never reaches a platform channel.
///
/// [granted] is the starting location state, [explainAccepted] how the user
/// answers the explanation, [requestGrants] how they answer the system
/// prompt, and [ssid] what the phone is connected to.
CurrentNetworkPicker fakePicker({
  bool granted = true,
  bool explainAccepted = true,
  bool requestGrants = true,
  String? ssid = 'Office',
}) => CurrentNetworkPicker(
  status: () async => locationStatus(granted: granted),
  requestLocation: () async => requestGrants,
  currentSsid: () async => ssid,
  explain: (_) async => explainAccepted,
);
