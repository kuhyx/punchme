/// Writing a blank NFC tag so it becomes a punchme clock tag.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:punchme/nfc/nfc_service.dart';
import 'package:punchme/nfc/punch_tag.dart';
import 'package:punchme/ui/glyphs.dart';

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

/// The pictograms standing in for each failure message.
List<IconData> writeFailureIcons(NfcWriteFailure failure) => switch (failure) {
  NfcWriteFailure.notWritable => const <IconData>[
    Icons.error_outline,
    Icons.lock,
  ],
  NfcWriteFailure.tooLarge => const <IconData>[
    Icons.error_outline,
    Icons.sd_card_alert,
  ],
  NfcWriteFailure.interrupted => const <IconData>[
    Icons.error_outline,
    Icons.pan_tool,
  ],
  NfcWriteFailure.verifyMismatch => const <IconData>[
    Icons.error_outline,
    Icons.sync_problem,
  ],
};

/// A status line: pictograms plus the sentence they replace (spoken only).
typedef WriteTagStatus = ({List<IconData> icons, String spoken});

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
  // Empty, not a suggested word: the label is the user's own text.
  final TextEditingController _label = TextEditingController();
  WriteTagStatus? _status;
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
      setState(
        () => _status = (
          icons: const <IconData>[Icons.nfc, Icons.toggle_off],
          spoken: 'Turn NFC on to write a tag.',
        ),
      );
      return;
    }
    setState(() {
      _waiting = true;
      _status = (
        icons: const <IconData>[Icons.contactless],
        spoken: 'Hold a blank tag against the back of the phone.',
      );
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
          ? (
              icons: const <IconData>[Icons.check_circle],
              spoken: 'Tag written. Tap it to clock in or out.',
            )
          : (
              icons: writeFailureIcons(failure),
              spoken: writeFailureMessage(failure),
            );
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: _label,
              enabled: !_waiting,
              decoration: const InputDecoration(
                prefixIcon: Icon(
                  Icons.label_outline,
                  semanticLabel: 'Tag label',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: const Key('write-tag-go'),
              onPressed: _waiting ? null : _start,
              child: _waiting
                  ? const Icon(
                      Icons.hourglass_top,
                      semanticLabel: 'Waiting for a tag...',
                    )
                  : const Icon(Icons.nfc, semanticLabel: 'Write tag'),
            ),
            if (status != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Cue(
                  key: const Key('write-tag-status'),
                  icons: status.icons,
                  spoken: status.spoken,
                  size: 48,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
