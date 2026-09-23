/// Editing the list of Wi-Fi networks that count as "at work".
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Lets the user add and remove work Wi-Fi SSIDs by name.
class WifiSsidsField extends StatefulWidget {
  /// Creates a field over [ssids].
  const WifiSsidsField({
    required this.ssids,
    required this.onChanged,
    this.currentSsid,
    super.key,
  });

  /// The SSIDs currently configured as work networks.
  final Set<String> ssids;

  /// Called with the new set when one is added or removed.
  final ValueChanged<Set<String>> onChanged;

  /// Asks for the SSID of the network the phone is on right now.
  ///
  /// Null hides the "use current network" button, so a build with no host
  /// behind the channel does not offer a button that can only ever add
  /// nothing.
  final Future<String?> Function()? currentSsid;

  @override
  State<WifiSsidsField> createState() => _WifiSsidsFieldState();
}

class _WifiSsidsFieldState extends State<WifiSsidsField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(String ssid) {
    final trimmed = ssid.trim();
    if (trimmed.isEmpty || widget.ssids.contains(trimmed)) {
      return;
    }
    widget.onChanged(<String>{...widget.ssids, trimmed});
    _controller.clear();
  }

  void _remove(String ssid) => widget.onChanged(<String>{
    for (final existing in widget.ssids)
      if (existing != ssid) existing,
  });

  Future<void> _useCurrent() async {
    final ssid = await widget.currentSsid?.call();
    if (ssid != null) {
      _add(ssid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = widget.ssids.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Network name (SSID)',
                ),
                onSubmitted: _add,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add',
              onPressed: () => _add(_controller.text),
            ),
          ],
        ),
        if (widget.currentSsid != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _useCurrent,
              child: const Text('Use current network'),
            ),
          ),
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
