/// Adding the Wi-Fi network the phone is on right now.
library;

import 'package:flutter/widgets.dart';
import 'package:punchme/ui/wifi/location_rationale.dart';
import 'package:punchme/wifi/wifi_channel.dart';

/// Shown when location was refused, so no network name can be read.
const String kLocationDeniedMessage =
    'Location permission is needed to read the network name. If Android no '
    'longer asks, allow it in app settings.';

/// Shown when the phone is not connected to any Wi-Fi network.
const String kNotOnWifiMessage =
    'Not connected to Wi-Fi. Connect to your work network first.';

/// What one attempt to read the current network produced.
class NetworkPick {
  const NetworkPick._({this.message, this.needsSettings = false}) : ssid = null;

  /// The network was read.
  const NetworkPick.found(String this.ssid)
    : message = null,
      needsSettings = false;

  /// The user backed out of the explanation; nothing to report.
  static const NetworkPick cancelled = NetworkPick._();

  /// Location was refused.
  static const NetworkPick denied = NetworkPick._(
    message: kLocationDeniedMessage,
    needsSettings: true,
  );

  /// Permission is fine, but there is no Wi-Fi network to read.
  static const NetworkPick notOnWifi = NetworkPick._(
    message: kNotOnWifiMessage,
  );

  /// The SSID read, when there was one.
  final String? ssid;

  /// Why nothing was read, worth telling the user. Null when cancelled.
  final String? message;

  /// Whether the fix lives in the system's app settings page.
  final bool needsSettings;
}

/// Explains, asks for location only when missing, then reads the SSID.
///
/// The one path every "add this network" button goes through, so no screen
/// can raise the system prompt without the explanation in front of it.
class CurrentNetworkPicker {
  /// Creates a picker over the real channel, or injected stand-ins.
  const CurrentNetworkPicker({
    this.status = wifiPermissionStatus,
    this.requestLocation = requestWifiLocation,
    this.currentSsid = currentWifiSsid,
    this.explain = showLocationRationaleDialog,
  });

  /// Asks native what is granted.
  final Future<WifiPermissionStatus> Function() status;

  /// Raises the system location prompt.
  final Future<bool> Function() requestLocation;

  /// Reads the connected SSID.
  final Future<String?> Function() currentSsid;

  /// Shows the explanation; true means "go ahead and ask".
  final Future<bool> Function(BuildContext context) explain;

  /// Runs the whole flow from [context].
  Future<NetworkPick> pick(BuildContext context) async {
    final granted = (await status()).locationGranted;
    if (!granted) {
      if (!context.mounted || !await explain(context)) {
        return NetworkPick.cancelled;
      }
      if (!await requestLocation()) {
        return NetworkPick.denied;
      }
    }
    final ssid = await currentSsid();
    return ssid == null ? NetworkPick.notOnWifi : NetworkPick.found(ssid);
  }
}
