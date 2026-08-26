/// Keeps a foreground NFC reader session alive while the app is in front.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:punchme/nfc/nfc_service.dart';
import 'package:punchme/nfc/punch_tag.dart';

/// Runs a reader session for as long as [child] is visible and resumed.
///
/// A session left running while the app is backgrounded keeps the reader
/// hardware awake and steals taps that Android should be routing to the
/// launch intent instead, so it is stopped and restarted with the lifecycle.
class NfcSession extends StatefulWidget {
  /// Wraps [child] in a reader session driven by [service].
  const NfcSession({
    required this.service,
    required this.onPunch,
    required this.child,
    this.onBlankTag,
    super.key,
  });

  /// Talks to the NFC hardware.
  final NfcService service;

  /// Called with each punchme tag read.
  final void Function(PunchTag) onPunch;

  /// Called when a readable tag is not one of ours, or is still blank.
  final VoidCallback? onBlankTag;

  /// The screen underneath.
  final Widget child;

  @override
  State<NfcSession> createState() => _NfcSessionState();
}

class _NfcSessionState extends State<NfcSession> with WidgetsBindingObserver {
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(start());
    } else {
      stop();
    }
  }

  /// Starts reading, unless a session is already running or NFC is off.
  Future<void> start() async {
    if (_running) {
      return;
    }
    final availability = await widget.service.checkAvailability();
    if (!mounted || availability != NfcAvailability.enabled) {
      return;
    }
    _running = true;
    await widget.service.startReading(
      onPunch: widget.onPunch,
      onOther: widget.onBlankTag,
    );
  }

  /// Stops the session if one is running.
  void stop() {
    if (!_running) {
      return;
    }
    _running = false;
    widget.service.stopReading().ignore();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
