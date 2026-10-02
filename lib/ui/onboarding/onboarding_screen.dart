/// First launch: explain location, then add the work Wi-Fi network.
library;

import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:punchme/data/day_repository.dart';
import 'package:punchme/ui/wifi/current_network_picker.dart';
import 'package:punchme/ui/wifi/location_rationale.dart';
import 'package:punchme/wifi/wifi_channel.dart';

/// The two onboarding steps: why location, then which network.
///
/// The explanation step is skipped when location is already granted. Either
/// step can be skipped outright -- a first launch at home must not trap the
/// user in a flow that needs them to be at work.
class OnboardingScreen extends StatefulWidget {
  /// Creates the onboarding flow, saving into [repository].
  const OnboardingScreen({
    required this.repository,
    this.picker = const CurrentNetworkPicker(),
    this.status = wifiPermissionStatus,
    this.requestLocation = requestWifiLocation,
    this.armWifi = setWifiArmed,
    this.openSettings = openWifiAppSettings,
    super.key,
  });

  /// Where the chosen network is saved.
  final DayRepository repository;

  /// Reads the current network for the second step.
  final CurrentNetworkPicker picker;

  /// Asks native what is granted. Injected for tests.
  final Future<WifiPermissionStatus> Function() status;

  /// Raises the system location prompt. Injected for tests.
  final Future<bool> Function() requestLocation;

  /// Tells native a work SSID now exists. Injected for tests.
  final Future<void> Function({required bool armed}) armWifi;

  /// Opens the system app-settings page. Injected for tests.
  final Future<void> Function() openSettings;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step { loading, explain, addNetwork }

class _OnboardingScreenState extends State<OnboardingScreen> {
  _Step _step = _Step.loading;
  NetworkPick? _failure;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    final granted = (await widget.status()).locationGranted;
    if (!mounted) {
      return;
    }
    setState(() => _step = granted ? _Step.addNetwork : _Step.explain);
  }

  Future<void> _continue() async {
    final granted = await widget.requestLocation();
    if (!mounted) {
      return;
    }
    setState(() {
      _step = _Step.addNetwork;
      _failure = granted ? null : NetworkPick.denied;
    });
  }

  Future<void> _addCurrent() async {
    final pick = await widget.picker.pick(context);
    final ssid = pick.ssid;
    if (ssid == null) {
      if (mounted) {
        setState(() => _failure = pick.message == null ? null : pick);
      }
      return;
    }
    final settings = await widget.repository.loadSettings();
    await widget.repository.saveSettings(
      settings.copyWith(
        workWifiSsids: <String>{...settings.workWifiSsids, ssid},
      ),
    );
    await widget.armWifi(armed: true);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _skip() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Clock in automatically')),
    body: SafeArea(
      child: switch (_step) {
        _Step.loading => const Center(child: CircularProgressIndicator()),
        _Step.explain => _page(
          children: const <Widget>[LocationRationale()],
          primary: FilledButton(
            onPressed: _continue,
            child: const Text('Continue'),
          ),
          skipLabel: 'Skip',
        ),
        _Step.addNetwork => _page(
          children: <Widget>[
            const Text(
              'Connect this phone to your work Wi-Fi, then add it. punchme '
              'will clock you in the first time each day it sees that '
              'network.',
            ),
            if (_failure case final failure?) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(failure.message!),
              if (failure.needsSettings)
                TextButton(
                  onPressed: widget.openSettings,
                  child: const Text('Open app settings'),
                ),
            ],
          ],
          primary: FilledButton.icon(
            onPressed: _addCurrent,
            icon: const Icon(Icons.wifi),
            label: const Text('Add this network'),
          ),
          skipLabel: "I'm not at work right now",
        ),
      },
    ),
  );

  Widget _page({
    required List<Widget> children,
    required Widget primary,
    required String skipLabel,
  }) => Padding(
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
        primary,
        TextButton(onPressed: _skip, child: Text(skipLabel)),
      ],
    ),
  );
}
