/// The home screen, with a foreground NFC reader attached to it.
library;

import 'package:flutter/material.dart';
import 'package:punchme/data/day_repository.dart';
import 'package:punchme/nfc/nfc_service.dart';
import 'package:punchme/nfc/nfc_session.dart';
import 'package:punchme/nfc/punch_tag.dart';
import 'package:punchme/ui/home/home_punch_handlers.dart';
import 'package:punchme/ui/home/home_screen.dart';

/// Wires tag reads into the home screen's punch handler.
///
/// A separate widget because the handler only exists once the screen's state
/// does, and the reader session has to outlive individual rebuilds of it.
class HomeWithNfc extends StatefulWidget {
  /// Creates the wired-up home screen.
  const HomeWithNfc({required this.repository, this.service, super.key});

  /// Where days are read from and written to.
  final DayRepository repository;

  /// Talks to the NFC hardware. Defaults to the real plugin.
  final NfcService? service;

  @override
  State<HomeWithNfc> createState() => _HomeWithNfcState();
}

class _HomeWithNfcState extends State<HomeWithNfc> {
  late final NfcService _service = widget.service ?? NfcService();
  HomePunchHandlers? _handlers;

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
