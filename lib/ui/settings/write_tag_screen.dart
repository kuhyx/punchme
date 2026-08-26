/// Writing a blank NFC tag so it becomes a punchme clock tag.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:punchme/nfc/nfc_service.dart';
import 'package:punchme/nfc/punch_tag.dart';

/// The message shown for each way a write can fail.
String writeFailureMessage(NfcWriteFailure failure) {
  switch (failure) {
    case NfcWriteFailure.notWritable:
      return 'That tag is locked or read-only. Try a blank one.';
    case NfcWriteFailure.tooLarge:
      return 'That tag is too small for the label.';
    case NfcWriteFailure.interrupted:
      return 'The tag moved away too soon. Hold it still and try again.';
    case NfcWriteFailure.verifyMismatch:
      return 'The tag did not read back correctly. Try again.';
  }
}

/// Writes a clock tag, and reports how it went.
class WriteTagScreen extends StatefulWidget {
  /// Creates the screen backed by [service].
  const WriteTagScreen({required this.service, super.key});

  /// Talks to the NFC hardware.
  final NfcService service;

  @override
  State<WriteTagScreen> createState() => _WriteTagScreenState();
}

class _WriteTagScreenState extends State<WriteTagScreen> {
  final TextEditingController _label = TextEditingController(text: 'desk');
  String? _status;
  bool _waiting = false;

  @override
  void dispose() {
    _label.dispose();
    unawaitedStop();
    super.dispose();
  }

  /// Ends any session still running when the screen goes away.
  void unawaitedStop() {
    if (_waiting) {
      widget.service.stopReading().ignore();
    }
  }

  Future<void> _start() async {
    final availability = await widget.service.checkAvailability();
    if (!mounted) {
      return;
    }
    if (availability != NfcAvailability.enabled) {
      setState(() => _status = 'Turn NFC on to write a tag.');
      return;
    }
    setState(() {
      _waiting = true;
      _status = 'Hold a blank tag against the back of the phone.';
    });
    await widget.service.startWriting(
      tag: PunchTag(
        label: _label.text.trim().isEmpty
            ? kDefaultTagLabel
            : _label.text.trim(),
      ),
      onDone: _finish,
    );
  }

  void _finish(NfcWriteFailure? failure) {
    if (!mounted) {
      return;
    }
    setState(() {
      _waiting = false;
      _status = failure == null
          ? 'Tag written. Tap it to clock in or out.'
          : writeFailureMessage(failure);
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Scaffold(
      appBar: AppBar(title: const Text('Write clock tag')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: _label,
              enabled: !_waiting,
              decoration: const InputDecoration(
                labelText: 'Tag label',
                helperText: 'Shown when you tap it, e.g. "desk".',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _waiting ? null : _start,
              child: Text(_waiting ? 'Waiting for a tag...' : 'Write tag'),
            ),
            if (status != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              Text(status, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
