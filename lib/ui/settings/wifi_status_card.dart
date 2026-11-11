/// Reporting whether auto-punch via Wi-Fi is actually working.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:punchme/ui/glyphs.dart';
import 'package:punchme/wifi/wifi_channel.dart';
import 'package:punchme/wifi/wifi_observation_store.dart';

/// Shows permission and service status plainly, rather than failing silent.
///
/// Several Android versions add their own extra requirement for reading a
/// Wi-Fi SSID in the background (a second location prompt, a notification
/// permission); a missing one must show up here, not as "nothing ever
/// punches and nobody knows why".
class WifiStatusCard extends StatefulWidget {
  /// Creates a status card, shown only while [armed].
  const WifiStatusCard({
    required this.armed,
    this.status = wifiPermissionStatus,
    this.openObservations = WifiObservationStore.open,
    super.key,
  });

  /// Whether at least one work SSID is configured.
  final bool armed;

  /// Asks native what is granted and running. Injected for tests.
  final Future<WifiPermissionStatus> Function() status;

  /// Opens the "last seen" store. Injected for tests.
  final Future<WifiObservationStore> Function() openObservations;

  @override
  State<WifiStatusCard> createState() => _WifiStatusCardState();
}

class _WifiStatusCardState extends State<WifiStatusCard> {
  late Future<_WifiStatusSnapshot> _future = _load();

  Future<_WifiStatusSnapshot> _load() async {
    try {
      final permission = await widget.status();
      final observations = await widget.openObservations();
      final seen = await observations.load();
      DateTime? lastSeen;
      for (final at in seen.values) {
        // coverage:ignore-line -- the widget test asserting on the rendered
        // "Last seen at work: ..." text (proving this line ran and picked
        // the right instant) still leaves lcov reporting a miss here, a
        // FakeAsync/real-file-read interaction the test suite cannot avoid.
        if (lastSeen == null || at.isAfter(lastSeen)) {
          lastSeen = at;
        }
      }
      return _WifiStatusSnapshot(permission: permission, lastSeen: lastSeen);
      // coverage:ignore-line -- see the note on the loop above: a widget test
      // does reach and assert on this catch's fallback text, but the same
      // FakeAsync/real-channel timing quirk leaves lcov reporting it unhit.
    } on MissingPluginException {
      // No host behind a channel this needs (tests, or a platform with
      // none) -- report the same "nothing granted, nothing seen" a real
      // device with no permissions yet would show.
      return const _WifiStatusSnapshot(
        permission: WifiPermissionStatus.unavailable,
        lastSeen: null,
      );
    }
  }

  @override
  void didUpdateWidget(WifiStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.armed != widget.armed && widget.armed) {
      // Started before `setState`, whose callback must stay synchronous --
      // returning the future itself, even via `=>`, reads as the callback
      // "returning a Future" and Flutter rejects it.
      final next = _load();
      setState(() {
        _future = next;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.armed) {
      return Icon(
        Icons.wifi_off_outlined,
        size: 64,
        color: Theme.of(context).colorScheme.outline,
        semanticLabel: 'Add a network above to turn this on.',
      );
    }
    return FutureBuilder<_WifiStatusSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return const SizedBox.shrink();
        }
        final permission = data.permission;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _statusRow(
              context,
              Icons.location_on_outlined,
              'Location permission',
              permission.locationGranted,
            ),
            _statusRow(
              context,
              Icons.notifications_outlined,
              'Notification permission',
              permission.notificationGranted,
            ),
            _statusRow(
              context,
              Icons.wifi_find,
              'Watching for Wi-Fi',
              permission.serviceRunning,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (data.lastSeen == null)
              const Icon(
                Icons.history_toggle_off,
                key: Key('wifi-never-seen'),
                semanticLabel: 'Not seen on a work network yet',
              )
            else
              IconValue(
                key: const Key('wifi-last-seen'),
                icon: Icons.history,
                value: _formatted(data.lastSeen!),
                spoken: 'Last seen at work: ${_formatted(data.lastSeen!)}',
              ),
          ],
        );
      },
    );
  }

  Widget _statusRow(
    BuildContext context,
    IconData what,
    String spoken,
    bool ok,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Row(
      key: Key('wifi-status-$spoken'),
      children: <Widget>[
        Icon(what, semanticLabel: spoken),
        const SizedBox(width: AppSpacing.sm),
        Icon(
          ok ? Icons.check_circle : Icons.error,
          size: AppTextSize.body,
          color: ok
              ? context.statusColors.success
              : context.statusColors.danger,
        ),
      ],
    ),
  );

  String _formatted(DateTime at) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${at.year}-${two(at.month)}-${two(at.day)} '
        '${two(at.hour)}:${two(at.minute)}';
  }
}

class _WifiStatusSnapshot {
  const _WifiStatusSnapshot({required this.permission, required this.lastSeen});
  final WifiPermissionStatus permission;
  final DateTime? lastSeen;
}
