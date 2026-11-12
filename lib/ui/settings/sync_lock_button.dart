/// The sync tile's end-to-end encryption passphrase button.
library;

import 'dart:async';

import 'package:crdt_sync_flutter/crdt_sync_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:punchme/sync/sync_service.dart';

/// Icon only (textgate): shows the lock state the last sync tick published
/// and opens the hidden field the encryption key is derived from.
class SyncLockButton extends StatelessWidget {
  /// Creates the button; both defaults are the real ones.
  const SyncLockButton({this.locked, this.onSaved, super.key});

  /// Whether the last tick found encryption locked; defaults to [e2eLocked].
  final ValueListenable<bool>? locked;

  /// Runs after a passphrase is saved; defaults to retrying the sync.
  final Future<void> Function()? onSaved;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: locked ?? e2eLocked,
    builder: (_, isLocked, _) => E2ePassphraseButton(
      locked: isLocked,
      onSaved: () => unawaited((onSaved ?? resyncAfterPassphrase)()),
    ),
  );
}
