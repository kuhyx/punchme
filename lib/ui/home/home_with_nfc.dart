/// The home screen, with foreground and background NFC readers attached.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:punchme/data/day_repository.dart';
import 'package:punchme/nfc/background_punch_channel.dart';
import 'package:punchme/nfc/nfc_service.dart';
import 'package:punchme/nfc/nfc_session.dart';
import 'package:punchme/nfc/punch_tag.dart';
import 'package:punchme/ui/home/home_punch_handlers.dart';
import 'package:punchme/ui/home/home_screen.dart';

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
    super.key,
  });

  /// Where days are read from and written to.
  final DayRepository repository;

  /// Talks to the NFC hardware. Defaults to the real plugin.
  final NfcService? service;

  /// Carries taps from outside the app. Defaults to the real channel.
  final BackgroundPunchChannel? channel;

  @override
  State<HomeWithNfc> createState() => _HomeWithNfcState();
}

class _HomeWithNfcState extends State<HomeWithNfc> with WidgetsBindingObserver {
  late final NfcService _service = widget.service ?? NfcService();
  late final BackgroundPunchChannel _channel =
      widget.channel ?? BackgroundPunchChannel();
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
      onReady: (handlers) => _handlers = handlers,
    ),
  );
}
