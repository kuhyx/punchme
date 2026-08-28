/// Answering "is this device actually syncing?" from the device itself.
///
/// The tile going green is not evidence. `openSync` returns null on a device
/// with no session and every push then silently no-ops, which is the exact
/// failure the sync feature exists to prevent -- so a check that only reads
/// the UI would confirm nothing.
///
/// This runs a real tick and then reads back what the remote actually holds
/// for this device. Deliberately reports *data*, never credentials: the
/// keystore's refresh token is the shared `kuhy-syncs` credential and grants
/// access to every sibling app, so it must never leave the phone. What lands
/// in the report is the user's own timesheet, which the export path already
/// writes to the same directory.
library;

import 'dart:convert';

import 'package:crdt_sync/crdt_sync.dart';
import 'package:punchme/sync/sync_service.dart';

/// What one verification run found.
class SyncCheck {
  /// Creates a report.
  const SyncCheck({
    required this.outcome,
    required this.deviceId,
    required this.path,
    this.remote,
  });

  /// Whether the tick actually synced, or found no session.
  final SyncOutcome outcome;

  /// The persisted per-install id this device pushes under.
  final String deviceId;

  /// The full remote path the record should live at.
  final String path;

  /// What the remote holds there, or null when nothing is stored.
  final String? remote;

  /// The report as JSON, for the host to write out.
  ///
  /// `recordCount` is the number the caller cares about: a path that exists
  /// but holds an empty log is the same silent failure as no path at all.
  String toJson() =>
      const JsonEncoder.withIndent(' ').convert(<String, Object?>{
        'outcome': outcome.name,
        'deviceId': deviceId,
        'path': path,
        'present': remote != null,
        'recordCount': _countRecords(),
        'remote': remote,
      });

  int? _countRecords() {
    if (remote == null) {
      return null;
    }
    final decoded = jsonDecode(remote!);
    return decoded is Map ? decoded.length : null;
  }
}

/// Syncs, then reads back what this device's own record now contains.
///
/// The read goes through the same [RemoteStore] the push used, so a report
/// saying "present" cannot be true of a different backend than the one the
/// app writes to.
Future<SyncCheck> runSyncCheck({
  required Future<SyncOutcome> Function() sync,
  required Future<RemoteStore?> Function() openClient,
  required String deviceId,
  String? pathPrefix,
}) async {
  final outcome = await sync();
  final path = '${pathPrefix ?? syncPathPrefix()}/$deviceId/log.json';
  final client = await openClient();
  return SyncCheck(
    outcome: outcome,
    deviceId: deviceId,
    path: path,
    // Not reachable when the device holds no session, which the outcome
    // already reports; reading through a null client would be an error the
    // report cannot express.
    remote: client == null ? null : await client.getFileText(path),
  );
}
