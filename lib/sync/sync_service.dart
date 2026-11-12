/// Pushing the local log to Firebase, and pulling every peer's back.
library;

import 'package:crdt_sync/crdt_sync.dart';
import 'package:crdt_sync_flutter/crdt_sync_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:punchme/nfc/punch_tag.dart';

/// The shared `kuhy-syncs` project.
///
/// Safe to commit: the Web API key is a public identifier that already ships
/// inside every APK, and the security rules -- not its secrecy -- are what
/// protect the data.
const FirebaseProject kSyncProject = FirebaseProject(
  apiKey: 'AIzaSyCF_sA3xCMehAYXK8eND-rAygb9NXXW_8E',
  databaseUrl:
      'https://kuhy-syncs-default-rtdb.europe-west1.firebasedatabase.app',
);

/// The uid the database rules pin.
const String kSyncUid = 'OvA2REQyLIhAHOEjzwS1o877rgG3';

/// This app's descriptor for the shared bootstrap.
const SyncApp kSyncApp = SyncApp(project: kSyncProject, expectedUid: kSyncUid);

/// The RTDB path this build's devices push under.
///
/// Derived from [activePunchMime], which the host hands over at startup, so
/// the sandbox flavor lands on `punchme/sandbox/devices` while the daily
/// build uses `punchme/daily/devices`. Two builds therefore cannot merge each
/// other's logs, which is the whole point of the flavor split: testing
/// destructively must not be able to reach the real timesheet.
///
/// Reading the *adopted* MIME rather than a compiled-in constant keeps this
/// on the single definition the manifest filter also comes from.
String syncPathPrefix() {
  final flavor = activePunchMime.endsWith('.sandbox') ? 'sandbox' : 'daily';
  return 'punchme/$flavor/devices';
}

/// What a sync attempt did.
enum SyncOutcome {
  /// This device is not enrolled; nothing was pushed or pulled.
  notConfigured,

  /// The log was pushed, and every peer's merged in.
  synced,

  /// Signed in, but end-to-end encryption has no usable key on this device
  /// (no or wrong passphrase, unreadable header): nothing was pulled or
  /// pushed, rather than syncing in plaintext.
  locked,
}

/// Argon2id cost for new encryption headers; only tests lower it.
@visibleForTesting
Argon2Params e2eArgon2Params = Argon2Params.recommended;

/// Opens the end-to-end encrypted view of [client] for the old plaintext
/// prefix [oldPrefix].
typedef E2eOpener =
    Future<E2eState> Function(RemoteStore client, String oldPrefix);

/// The real opener: the shared crdt-sync passphrase and the derived-key cache
/// both live in the OS keystore, so a tick never prompts.
Future<E2eState> openE2eFromKeystore(RemoteStore client, String oldPrefix) =>
    openEncryptedStoreFromKeystore(
      store: client,
      oldPrefix: oldPrefix,
      params: e2eArgon2Params,
    );

/// Whether the last tick found encryption locked; the settings lock icon
/// reads it.
final ValueNotifier<bool> e2eLocked = ValueNotifier<bool>(false);

/// Reruns a tick once a passphrase is entered; the bootstrap installs the
/// real one, so the settings screen needs no handle on the store.
Future<void> Function() resyncAfterPassphrase = () async {};

/// Merges the local log with every peer's, then pushes the result.
///
/// [openClient] and [openE2e] are injected so the whole path is exercisable
/// without a network or a keystore; the defaults are the real ones.
///
/// Everything pushed is end-to-end encrypted under `<prefix>-e2e`; the old
/// plaintext prefix is copied over once by the library and never deleted
/// here. Without a usable key the tick is [SyncOutcome.locked], never a
/// plaintext sync.
///
/// Returns [SyncOutcome.notConfigured] when this device has no session. That
/// is a normal state, not an error -- the app keeps working against its local
/// store -- but it is reported rather than swallowed so a caller can tell
/// "synced" from "silently did nothing".
Future<SyncOutcome> syncNow({
  required LogStore store,
  required String deviceId,
  required Future<RemoteStore?> Function() openClient,
  String? pathPrefix,
  E2eOpener openE2e = openE2eFromKeystore,
}) async {
  final client = await openClient();
  if (client == null) {
    return SyncOutcome.notConfigured;
  }
  final oldPrefix = pathPrefix ?? syncPathPrefix();
  final e2e = await openE2e(client, oldPrefix);
  e2eLocked.value = e2e is! E2eReady;
  if (e2e is! E2eReady) {
    return SyncOutcome.locked;
  }
  final layout = E2eLayout.of(oldPrefix);
  final merged = await syncLog(
    client: e2e.store,
    deviceId: deviceId,
    pathPrefix: layout.prefix,
    revsPath: layout.revsPath,
    localLog: store.snapshot(),
    encode: logToJson,
    decode: logFromJson,
    commitMessage: 'punchme sync',
  );
  await store.replaceAll(merged);
  return SyncOutcome.synced;
}
