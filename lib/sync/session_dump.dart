/// Exporting this device's Firebase session, on explicit request.
///
/// **This writes the shared `kuhy-syncs` refresh token to external storage.**
/// That token is not punchme's alone: it authenticates todo, diet_guard,
/// wake_alarm, lyricanki and every future sibling app on the same project, so
/// a copy of it is a copy of the key to all of them. It is exported here
/// because the owner of that credential asked for it directly, having been
/// told what it covers.
///
/// The destination is the app's own external directory, which other apps
/// cannot read on API 30+ -- the same argument the export path makes. That
/// argument is weaker here than it is for a timesheet: a file on /sdcard
/// survives uninstall, is visible to anyone with adb, and lands in whatever
/// backs up that directory. Prefer [runSyncCheck] in `sync_check.dart`, which
/// answers "is this device really syncing?" without moving the secret at all.
library;

import 'dart:convert';

import 'package:crdt_sync_flutter/crdt_sync_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The keystore entry holding the Firebase credentials blob.
const String kCredentialsKey = 'firebase.credentials';

/// Reads the stored session and renders it as JSON.
///
/// Returns a JSON object with `present: false` when this device holds no
/// session, rather than throwing: "not signed in" is the answer to the
/// question, not a failure to answer it.
Future<String> dumpSession({
  FlutterSecureStorage storage = kSecureStorage,
}) async {
  final blob = await storage.read(key: kCredentialsKey);
  final account = await storage.read(key: kAccountKey);
  return const JsonEncoder.withIndent(' ').convert(<String, Object?>{
    'present': blob != null,
    'credentials': blob == null ? null : jsonDecode(blob),
    'account': account == null ? null : jsonDecode(account),
  });
}
