import 'package:crdt_sync/crdt_sync.dart';
import 'package:crdt_sync_flutter/crdt_sync_flutter.dart'
    show kE2ePassphraseKey;
import 'package:crdt_sync_flutter/testing/fake_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/sync/crdt_day_repository.dart';
import 'package:punchme/sync/day_record_codec.dart';
import 'package:punchme/sync/sync_service.dart';

import 'e2e_keystore.dart';
import 'fake_log_persistence.dart';
import 'fake_remote_store.dart';

/// Covers end-to-end encryption of the pushed log: the remote must never see
/// a field name or a punch time in the clear, and a device without the key
/// must fail closed rather than sync in plaintext.
void main() {
  const old = 'punchme/daily/devices';
  const sealed = 'punchme/daily/devices-e2e';

  DayEntry openDay(String key) =>
      DayEntry(dateKey: key, checkIn: DateTime(2026, 8, 25, 10, 29));

  Future<SyncOutcome> push(
    FakeRemoteStore remote, {
    String deviceId = 'device-a',
    String day = '2026-08-25',
  }) async {
    final store = await openFakeStore(nodeId: deviceId);
    await CrdtDayRepository(store: store).saveDay(openDay(day));
    return syncNow(
      store: store,
      deviceId: deviceId,
      openClient: () async => remote,
      pathPrefix: old,
    );
  }

  setUp(installE2eKeystore);

  test('the pushed blob holds no plaintext field name or time', () async {
    final remote = FakeRemoteStore();

    expect(await push(remote), SyncOutcome.synced);

    expect(remote.files.keys, contains('$sealed/device-a/log.json'));
    for (final blob in remote.files.values) {
      expect(blob, isNot(contains('checkIn')));
      expect(blob, isNot(contains('2026-08-25T10:29')));
    }
    expect(remote.files.keys.where((k) => k.startsWith('$old/')), isEmpty);
    expect(e2eLocked.value, isFalse);
  });

  test('two devices with the same passphrase merge sealed logs', () async {
    final remote = FakeRemoteStore();
    await push(remote, deviceId: 'device-b', day: '2026-08-26');

    final store = await openFakeStore(nodeId: 'device-a');
    await syncNow(
      store: store,
      deviceId: 'device-a',
      openClient: () async => remote,
      pathPrefix: old,
    );

    expect(
      (await CrdtDayRepository(store: store).loadDays()).map((d) => d.dateKey),
      <String>['2026-08-26'],
    );
  });

  test('no passphrase is locked: nothing pulled or pushed', () async {
    installE2eKeystore(withPassphrase: false);
    final remote = FakeRemoteStore();

    expect(await push(remote), SyncOutcome.locked);

    expect(remote.writes, isEmpty);
    expect(e2eLocked.value, isTrue);
  });

  test('a wrong passphrase is locked and writes nothing new', () async {
    final remote = FakeRemoteStore();
    await push(remote, deviceId: 'device-b');
    final before = Map<String, String>.of(remote.files);
    installFakeSecureStorage(
      initial: <String, String>{kE2ePassphraseKey: 'wrong'},
    );

    expect(await push(remote), SyncOutcome.locked);

    expect(remote.files, before);
  });

  test('the old plaintext prefix is copied over and left in place', () async {
    const peer = Hlc(wallTimeMs: 1000, counter: 0, nodeId: 'device-b');
    final plain = logToJson(<String, Record>{
      '2026-08-24': dayToRecord(openDay('2026-08-24'), peer),
    });
    final remote = FakeRemoteStore(<String, String>{
      '$old/device-b/log.json': plain,
    });
    final store = await openFakeStore(nodeId: 'device-a');

    await syncNow(
      store: store,
      deviceId: 'device-a',
      openClient: () async => remote,
      pathPrefix: old,
    );

    expect(
      (await CrdtDayRepository(store: store).loadDays()).map((d) => d.dateKey),
      <String>['2026-08-24'],
    );
    expect(remote.files['$old/device-b/log.json'], plain);
    // Record ids (the date) stay clear by design; fields and times do not.
    expect(
      remote.files['$sealed/device-b/log.json'],
      isNot(contains('checkIn')),
    );
  });
}
