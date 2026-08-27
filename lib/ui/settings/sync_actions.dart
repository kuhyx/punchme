/// Connecting this device to the shared sync account.
library;

import 'dart:async';

import 'package:crdt_sync_flutter/crdt_sync_flutter.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:punchme/sync/sync_service.dart';

/// The project's **Web** OAuth client id.
///
/// Web, not Android: `google_sign_in` wants the server client id, and hands
/// back an id token minted for it. Shared with the sibling apps because they
/// all sign in to the same `kuhy-syncs` project.
const String kServerClientId =
    '845446124781-prdoherj0v64vc6egvvcp3l0693khaur.apps.googleusercontent.com';

/// Whether this device already holds a usable session.
typedef SyncProbe = Future<bool> Function();

/// Runs the interactive sign-in. True when a session now exists.
typedef SyncConnect = Future<bool> Function();

/// The real probe: asks the keystore, not a local flag.
///
/// Reads through the package's default storage, so a test covers this by
/// installing the shared secure-storage fake rather than by passing a stub.
Future<bool> probeSyncSession() => isSyncConfigured(kSyncApp);

/// The real connect: raises the Google picker, then signs in to Firebase.
///
/// False when the user dismisses the picker, which is a choice rather than a
/// failure and so must not surface as an error.
///
/// [signInFn] replaces the account picker, which reaches a platform channel
/// `flutter test` has no host for; [httpClient] replaces the Firebase token
/// exchange. Both default to the real thing.
Future<bool> connectSyncAccount({
  Future<String?> Function()? signInFn,
  http.Client? httpClient,
}) async {
  final client = await signInWithGoogle(
    kSyncApp,
    tokenFetcher: () =>
        googleIdToken(serverClientId: kServerClientId, signInFn: signInFn),
    httpClient: httpClient,
  );
  client?.close();
  return client != null;
}

/// Shows whether this device syncs, and connects it when it does not.
///
/// Without this the app is silently local-only: `openSync` returns null on a
/// device with no session, every push no-ops, and nothing says so. The state
/// is read back from the keystore rather than remembered, because a revoked
/// token would otherwise leave this reading "Connected" while every sync
/// failed.
class SyncActions extends StatefulWidget {
  /// Creates the sync section.
  ///
  /// Both platform calls are injected so a widget test never reaches Google
  /// or the keystore -- an unanswered channel would hang the whole test file
  /// rather than fail it.
  const SyncActions({
    this.probe = probeSyncSession,
    this.connect = connectSyncAccount,
    super.key,
  });

  /// Reports whether a session exists.
  final SyncProbe probe;

  /// Performs the interactive sign-in.
  final SyncConnect connect;

  @override
  State<SyncActions> createState() => _SyncActionsState();
}

class _SyncActionsState extends State<SyncActions> {
  bool _connected = false;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final connected = await widget.probe();
    if (!mounted) {
      return;
    }
    setState(() {
      _connected = connected;
      _busy = false;
    });
  }

  Future<void> _connect() async {
    setState(() => _busy = true);
    String? failure;
    try {
      await widget.connect();
    } on Object catch (error) {
      // Surfaced rather than swallowed: a wrong-uid or unregistered-client
      // failure is a misconfiguration the user has to see, not a silent
      // return to "Not connected".
      failure = '$error';
    }
    await _refresh();
    if (!mounted || failure == null) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Sign-in failed: $failure')));
  }

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(_connected ? 'Sync connected' : 'Connect Google account'),
    subtitle: Text(
      _connected
          ? 'This device syncs its hours with your other devices.'
          : 'Until this is connected, hours stay on this device only.',
    ),
    trailing: _busy
        ? const SizedBox(
            width: AppSpacing.lg,
            height: AppSpacing.lg,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(_connected ? Icons.cloud_done_outlined : Icons.cloud_off),
    onTap: _busy || _connected ? null : _connect,
  );
}
