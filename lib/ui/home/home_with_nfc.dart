/// The home screen, with foreground and background NFC readers attached.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:punchme/data/day_repository.dart';
import 'package:punchme/logic/punch_coordinator.dart';
import 'package:punchme/nfc/background_punch_channel.dart';
import 'package:punchme/nfc/nfc_service.dart';
import 'package:punchme/nfc/nfc_session.dart';
import 'package:punchme/nfc/punch_tag.dart';
import 'package:punchme/ui/home/home_punch_handlers.dart';
import 'package:punchme/ui/home/home_screen.dart';
import 'package:punchme/wifi/wifi_auto_punch.dart';
import 'package:punchme/wifi/wifi_channel.dart';
import 'package:punchme/wifi/wifi_observation_store.dart';

/// Wires tag reads into the home screen's punch handlers.
///
/// A separate widget because the handlers only exist once the screen's state
/// does, and both readers have to outlive individual rebuilds of it.
class HomeWithNfc extends StatefulWidget {
  /// Creates the wired-up home screen.
  const HomeWithNfc({
    required this.repository,
    this.service,
    this.channel,
    this.now = DateTime.now,
    this.currentSsid = currentWifiSsid,
    this.openObservations = WifiObservationStore.open,
    super.key,
  });

  /// Where days are read from and written to.
  final DayRepository repository;

  /// Talks to the NFC hardware. Defaults to the real plugin.
  final NfcService? service;

  /// Carries taps from outside the app. Defaults to the real channel.
  final BackgroundPunchChannel? channel;

  /// The clock, injectable so tests can pin a working day.
  final DateTime Function() now;

  /// Asks native for the currently connected Wi-Fi SSID, on resume.
  /// Injected so a test never reaches a platform channel with no host.
  final Future<String?> Function() currentSsid;

  /// Opens the store "last seen on work Wi-Fi" instants persist in.
  /// Injected so a test never touches a real file.
  final Future<WifiObservationStore> Function() openObservations;

  @override
  State<HomeWithNfc> createState() => _HomeWithNfcState();
}

class _HomeWithNfcState extends State<HomeWithNfc> with WidgetsBindingObserver {
  late final NfcService _service = widget.service ?? NfcService();
  late final BackgroundPunchChannel _channel =
      widget.channel ?? BackgroundPunchChannel();
  late final PunchCoordinator _coordinator = PunchCoordinator(
    repository: widget.repository,
    now: widget.now,
  );
  Future<WifiObservationStore>? _observations;
  HomePunchHandlers? _handlers;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _channel.listen(_onBackgroundPunch);
    // Deferred to the first frame: the handlers are handed over during the
    // screen's initState, which has not run yet at this point.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_drain()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handlers?.onResume();
      unawaited(_checkWifi());
    }
  }

  /// Gives an immediate result on opening the app while on a work network,
  /// rather than waiting for the periodic backstop to notice.
  Future<void> _checkWifi() async {
    try {
      final ssid = await widget.currentSsid();
      final observations = await (_observations ??= widget.openObservations());
      final settings = await widget.repository.loadSettings();
      await runWifiCheck(
        coordinator: _coordinator,
        observations: observations,
        settings: settings,
        currentSsid: ssid,
        now: widget.now(),
      );
    } on MissingPluginException {
      // No host behind a channel this needs (tests, or a platform with
      // none) -- nothing to check.
    }
  }

  /// Commits the tap the app was launched by, when there was one.
  Future<void> _drain() async {
    final tag = await _channel.drainLaunchPunch();
    if (tag != null) {
      _onBackgroundPunch(tag);
    }
  }

  void _onBackgroundPunch(PunchTag tag) {
    final handler = _handlers?.onBackgroundPunch;
    if (handler != null) {
      unawaited(handler(tag));
    }
  }

  void _onPunch(PunchTag tag) => _handlers?.onPunch(tag);

  void _onBlankTag() => _handlers?.onBlankTag();

  @override
  Widget build(BuildContext context) => NfcSession(
    service: _service,
    onPunch: _onPunch,
    onBlankTag: _onBlankTag,
    child: HomeScreen(
      repository: widget.repository,
      now: widget.now,
      onReady: (handlers) => _handlers = handlers,
    ),
  );
}
