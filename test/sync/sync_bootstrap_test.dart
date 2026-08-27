import 'dart:io';

import 'package:crdt_sync/crdt_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/data/json_day_repository.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/settings.dart';
import 'package:punchme/sync/sync_bootstrap.dart';
import 'package:punchme/sync/sync_service.dart';

import 'fake_remote_store.dart';

/// Covers the composition root, and the order it does things in.
///
/// The order is the safety argument: migrating before the first sync is what
/// stops an empty log being pushed over the user's real history.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('punchme_sync'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<DeviceIdentity> identity() async =>
      const DeviceIdentity(deviceId: 'device-a');

  /// Writes a legacy JSON timesheet into the temp directory.
  Future<JsonDayRepository> seedLegacy() async {
    final legacy = JsonDayRepository(File('${dir.path}/punchme.json'));
    await legacy.saveDay(
      DayEntry(
        dateKey: '2026-08-25',
        checkIn: DateTime(2026, 8, 25, 10, 29),
        checkOut: DateTime(2026, 8, 25, 18, 52),
      ),
    );
    await legacy.saveSettings(
      const Settings(requiredPerDay: Duration(hours: 7)),
    );
    return legacy;
  }

  test('migrates an existing timesheet into the log', () async {
    await seedLegacy();

    final synced = await openSyncedStore(
      directory: dir,
      openClient: () async => null,
      identity: identity,
    );

    final days = await synced.repository.loadDays();
    expect(days.single.dateKey, '2026-08-25');
    expect(days.single.checkOut, DateTime(2026, 8, 25, 18, 52));
    expect(
      (await synced.repository.loadSettings()).requiredPerDay,
      const Duration(hours: 7),
    );
  });

  test('leaves the old JSON file exactly where it was', () async {
    await seedLegacy();
    final file = File('${dir.path}/punchme.json');
    final before = await file.readAsString();

    await openSyncedStore(
      directory: dir,
      openClient: () async => null,
      identity: identity,
    );

    // The rollback path: a migration that turns out wrong must still leave
    // the user able to reinstall the old build and find their timesheet.
    expect(await file.readAsString(), before);
  });

  test('persists the log, so a second open does not re-migrate', () async {
    await seedLegacy();
    await openSyncedStore(
      directory: dir,
      openClient: () async => null,
      identity: identity,
    );

    final again = await openSyncedStore(
      directory: dir,
      openClient: () async => null,
      identity: identity,
    );

    expect(await again.repository.loadDays(), hasLength(1));
    expect(File('${dir.path}/punch_log.json').existsSync(), isTrue);
  });

  test('pushes the migrated history, not an empty log', () async {
    await seedLegacy();
    final remote = FakeRemoteStore();

    final synced = await openSyncedStore(
      directory: dir,
      openClient: () async => remote,
      identity: identity,
    );
    final outcome = await synced.sync();

    expect(outcome, SyncOutcome.synced);
    // The record has to be in the pushed payload; an empty first push would
    // read as "this device has nothing", which is not what happened.
    expect(remote.files.values.single, contains('2026-08-25'));
  });

  test('works, unsynced, when the device is not enrolled', () async {
    await seedLegacy();

    final synced = await openSyncedStore(
      directory: dir,
      openClient: () async => null,
      identity: identity,
    );

    expect(await synced.sync(), SyncOutcome.notConfigured);
    // Not being enrolled must not cost the user their local timesheet.
    expect(await synced.repository.loadDays(), hasLength(1));
  });

  test('starts empty when there is no legacy file at all', () async {
    final synced = await openSyncedStore(
      directory: dir,
      openClient: () async => null,
      identity: identity,
    );

    expect(await synced.repository.loadDays(), isEmpty);
  });

  test('a write reaches the remote through the fire-and-forget push', () async {
    final remote = FakeRemoteStore();
    final synced = await openSyncedStore(
      directory: dir,
      openClient: () async => remote,
      identity: identity,
    );

    await synced.repository.saveDay(
      DayEntry(dateKey: '2026-08-27', checkIn: DateTime(2026, 8, 27, 9)),
    );
    // The push is deliberately not awaited by the caller, so let the
    // microtask it was queued on run.
    await Future<void>.delayed(Duration.zero);

    expect(remote.files.values.single, contains('2026-08-27'));
  });

  test('a failing push does not take down the write', () async {
    final synced = await openSyncedStore(
      directory: dir,
      openClient: () async => throw const SocketException('offline'),
      identity: identity,
    );

    await synced.repository.saveDay(
      DayEntry(dateKey: '2026-08-27', checkIn: DateTime(2026, 8, 27, 9)),
    );
    await Future<void>.delayed(Duration.zero);

    // Local durability is what matters; the network is best-effort.
    expect(await synced.repository.loadDays(), hasLength(1));
  });
}
