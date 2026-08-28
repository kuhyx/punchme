/// Assembling the synced repository at startup.
library;

import 'dart:async';
import 'dart:io';

import 'package:crdt_sync/crdt_sync.dart';
import 'package:crdt_sync/crdt_sync_io.dart';
import 'package:crdt_sync_flutter/crdt_sync_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:punchme/data/day_repository.dart';
import 'package:punchme/data/json_day_repository.dart';
import 'package:punchme/sync/crdt_day_repository.dart';
import 'package:punchme/sync/day_log_migration.dart';
import 'package:punchme/sync/sync_service.dart';

/// The synced repository, plus the tick that pushes it.
class SyncedStore {
  /// Bundles [repository] with the [sync] that publishes its writes.
  const SyncedStore({
    required this.repository,
    required this.sync,
    required this.deviceId,
    required this.openClient,
  });

  /// What the app reads and writes days through.
  final DayRepository repository;

  /// Runs one push/pull tick.
  final Future<SyncOutcome> Function() sync;

  /// The persisted per-install id this device's records are stored under.
  ///
  /// Exposed because the verification path has to name the exact remote path
  /// to read back, and only this side knows the id.
  final String deviceId;

  /// Opens a signed-in client, or null when this device has no session.
  final Future<RemoteStore?> Function() openClient;
}

/// Builds the CRDT-backed repository, migrating the JSON file on first run.
///
/// The order matters and is the whole safety argument:
///   1. hydrate the local log;
///   2. migrate the existing JSON timesheet in, if the log is still empty;
///   3. only then sync, so the first push carries the user's real history
///      rather than an empty log that a peer would merge as a deletion.
///
/// The old JSON file is read and never written, so an install that has to be
/// rolled back still finds its timesheet exactly where it left it.
Future<SyncedStore> openSyncedStore({
  Directory? directory,
  DayRepository? legacy,
  Future<RemoteStore?> Function()? openClient,
  Future<DeviceIdentity> Function()? identity,
}) async {
  final dir = directory ?? await getApplicationSupportDirectory();
  final me = await (identity ?? loadDeviceIdentity)();
  final store = LogStore(
    persistence: FileLogPersistence(File(p.join(dir.path, 'punch_log.json'))),
    nodeId: me.deviceId,
  );
  await store.load();
  await migrateIntoLog(
    source: legacy ?? JsonDayRepository(File(p.join(dir.path, 'punchme.json'))),
    store: store,
  );

  Future<RemoteStore?> open() =>
      openClient == null ? openSync(kSyncApp) : openClient();

  Future<SyncOutcome> tick() =>
      syncNow(store: store, deviceId: me.deviceId, openClient: open);

  return SyncedStore(
    deviceId: me.deviceId,
    openClient: open,
    repository: CrdtDayRepository(
      store: store,
      // Fire-and-forget: a punch must land on screen at once, so the push is
      // not awaited and a failed one is not an error the user has to see.
      // The record is already durable locally by the time this runs.
      onWrite: () => unawaited(tick().catchError((_) => SyncOutcome.synced)),
    ),
    sync: tick,
  );
}
