/// Editing the list of Wi-Fi networks that count as "at work".
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:punchme/ui/wifi/current_network_picker.dart';
import 'package:punchme/wifi/wifi_channel.dart';

/// Lets the user add the network they are on, and remove configured ones.
///
/// There is deliberately no free-text entry: a typed SSID that is off by one
/// character never matches, and nothing would ever say why auto-punch is
/// silent. Reading the name off the live connection cannot be mistyped.
class WifiSsidsField extends StatefulWidget {
  /// Creates a field over [ssids].
  const WifiSsidsField({
    required this.ssids,
    required this.onChanged,
    this.picker = const CurrentNetworkPicker(),
    this.openSettings = openWifiAppSettings,
    super.key,
  });

  /// The SSIDs currently configured as work networks.
  final Set<String> ssids;

  /// Called with the new set when one is added or removed.
  final ValueChanged<Set<String>> onChanged;

  /// Reads the current network, explaining and asking for location first.
  final CurrentNetworkPicker picker;

  /// Opens the system app-settings page. Injected for tests.
  final Future<void> Function() openSettings;

  @override
  State<WifiSsidsField> createState() => _WifiSsidsFieldState();
}

class _WifiSsidsFieldState extends State<WifiSsidsField> {
  /// Why the last attempt added nothing, until the next attempt.
  NetworkPick? _failure;

  Future<void> _addCurrent() async {
    final pick = await widget.picker.pick(context);
    if (!mounted) {
      return;
    }
    setState(() => _failure = pick.message == null ? null : pick);
    final ssid = pick.ssid;
    if (ssid != null && !widget.ssids.contains(ssid)) {
      widget.onChanged(<String>{...widget.ssids, ssid});
    }
  }

  void _remove(String ssid) => widget.onChanged(<String>{
    for (final existing in widget.ssids)
      if (existing != ssid) existing,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = widget.ssids.toList()..sort();
    final failure = _failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: _addCurrent,
          icon: const Icon(Icons.wifi),
          label: const Text('Add current network'),
        ),
        if (failure != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(failure.message!),
          if (failure.needsSettings)
            TextButton(
              onPressed: widget.openSettings,
              child: const Text('Open app settings'),
            ),
        ],
        const SizedBox(height: AppSpacing.sm),
        if (sorted.isEmpty)
          const Text('No work Wi-Fi networks yet')
        else
          Wrap(
            spacing: AppSpacing.sm,
            children: <Widget>[
              for (final ssid in sorted)
                InputChip(label: Text(ssid), onDeleted: () => _remove(ssid)),
            ],
          ),
      ],
    );
  }
}
