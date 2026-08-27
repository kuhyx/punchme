import 'package:crdt_sync/crdt_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/nfc/punch_tag.dart';
import 'package:punchme/sync/crdt_day_repository.dart';
import 'package:punchme/sync/day_record_codec.dart';
import 'package:punchme/sync/sync_service.dart';

import 'fake_log_persistence.dart';
import 'fake_remote_store.dart';

/// Covers the push/pull tick and, above all, the flavor path split.
///
/// The split is a safety property, not a feature: if the sandbox build ever
/// shared a path with the daily one, testing destructively would corrupt the
/// real timesheet.
void main() {
  DayEntry openDay(String key) =>
      DayEntry(dateKey: key, checkIn: DateTime(2026, 8, 25, 10, 29));

  tearDown(() => activePunchMime = kPunchMime);

  group('syncPathPrefix', () {
    test('is the daily path for the daily build', () {
      activePunchMime = kPunchMime;

      expect(syncPathPrefix(), 'punchme/daily/devices');
    });

    test('is the sandbox path once the sandbox host is adopted', () {
      activePunchMime = 'application/vnd.kuhy.punchme.sandbox';

      expect(syncPathPrefix(), 'punchme/sandbox/devices');
    });

    test('the two builds never share a path', () {
      activePunchMime = kPunchMime;
      final daily = syncPathPrefix();
      activePunchMime = 'application/vnd.kuhy.punchme.sandbox';

      expect(syncPathPrefix(), isNot(daily));
    });
  });

  group('syncNow', () {
    test('reports notConfigured when the device has no session', () async {
      final store = await openFakeStore();

      final outcome = await syncNow(
        store: store,
        deviceId: 'device-a',
        openClient: () async => null,
      );

      // Reported, not swallowed: a caller must be able to tell this from a
      // real sync, or "syncing" silently means nothing.
      expect(outcome, SyncOutcome.notConfigured);
    });

    test('pushes the local log under this device id', () async {
      final store = await openFakeStore(nodeId: 'device-a');
      await CrdtDayRepository(store: store).saveDay(openDay('2026-08-25'));
      final remote = FakeRemoteStore();

      final outcome = await syncNow(
        store: store,
        deviceId: 'device-a',
        openClient: () async => remote,
        pathPrefix: 'punchme/daily/devices',
      );

      expect(outcome, SyncOutcome.synced);
      expect(
        remote.writes,
        contains(startsWith('punchme/daily/devices/device-a')),
      );
    });

    test("merges a peer's day into the local log", () async {
      const peer = Hlc(wallTimeMs: 1000, counter: 0, nodeId: 'device-b');
      final peerLog = <String, Record>{
        '2026-08-26': dayToRecord(openDay('2026-08-26'), peer),
      };
      final remote = FakeRemoteStore(<String, String>{
        'punchme/daily/devices/device-b/log.json': logToJson(peerLog),
      });
      final store = await openFakeStore(nodeId: 'device-a');
      await CrdtDayRepository(store: store).saveDay(openDay('2026-08-25'));

      await syncNow(
        store: store,
        deviceId: 'device-a',
        openClient: () async => remote,
        pathPrefix: 'punchme/daily/devices',
      );

      expect(
        (await CrdtDayRepository(
          store: store,
        ).loadDays()).map((d) => d.dateKey),
        <String>['2026-08-25', '2026-08-26'],
      );
    });

    test('does not pull a log this device pushed itself', () async {
      final store = await openFakeStore(nodeId: 'device-a');
      final remote = FakeRemoteStore(<String, String>{
        'punchme/daily/devices/device-a/log.json': logToJson(
          <String, Record>{
            '2026-01-01': dayToRecord(
              openDay('2026-01-01'),
              const Hlc(wallTimeMs: 1, counter: 0, nodeId: 'device-a'),
            ),
          },
        ),
      });

      await syncNow(
        store: store,
        deviceId: 'device-a',
        openClient: () async => remote,
        pathPrefix: 'punchme/daily/devices',
      );

      // Its own pushed file is not a peer's history to re-merge.
      expect(await CrdtDayRepository(store: store).loadDays(), isEmpty);
    });

    test('defaults its path to the active flavor', () async {
      activePunchMime = 'application/vnd.kuhy.punchme.sandbox';
      final store = await openFakeStore(nodeId: 'device-a');
      await CrdtDayRepository(store: store).saveDay(openDay('2026-08-25'));
      final remote = FakeRemoteStore();

      await syncNow(
        store: store,
        deviceId: 'device-a',
        openClient: () async => remote,
      );

      expect(
        remote.writes.single,
        startsWith('punchme/sandbox/devices/device-a'),
      );
    });
  });
}
