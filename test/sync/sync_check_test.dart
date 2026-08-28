import 'dart:convert';

import 'package:crdt_sync/crdt_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/sync/sync_check.dart';
import 'package:punchme/sync/sync_service.dart';

import 'fake_remote_store.dart';

/// Covers the check that makes a green tile mean something.
///
/// The failure it exists to catch: `openSync` returns null on an unenrolled
/// device, every push no-ops, and the UI still reads "Sync connected". So the
/// report has to distinguish "synced and the record is really there" from
/// "reported connected while the remote holds nothing".
void main() {
  const path = 'punchme/daily/devices/device-a/log.json';

  test('reports the record the remote actually holds', () async {
    final remote = FakeRemoteStore(<String, String>{
      path: jsonEncode(<String, dynamic>{'2026-08-25': <String, dynamic>{}}),
    });

    final check = await runSyncCheck(
      sync: () async => SyncOutcome.synced,
      openClient: () async => remote,
      deviceId: 'device-a',
      pathPrefix: 'punchme/daily/devices',
    );

    expect(check.outcome, SyncOutcome.synced);
    expect(check.deviceId, 'device-a');
    expect(check.path, path);
    final report = jsonDecode(check.toJson()) as Map<String, dynamic>;
    expect(report['present'], isTrue);
    expect(report['recordCount'], 1);
  });

  test(
    'an unenrolled device reports notConfigured and nothing stored',
    () async {
      // The silent failure in full: no client, so no push happened and there is
      // nothing at the path. A tile alone could not tell you this.
      final check = await runSyncCheck(
        sync: () async => SyncOutcome.notConfigured,
        openClient: () async => null,
        deviceId: 'device-a',
        pathPrefix: 'punchme/daily/devices',
      );

      final report = jsonDecode(check.toJson()) as Map<String, dynamic>;
      expect(report['outcome'], 'notConfigured');
      expect(report['present'], isFalse);
      expect(report['recordCount'], isNull);
      expect(report['remote'], isNull);
    },
  );

  test('a signed-in device with an empty path is not "present"', () async {
    // Enrolled, but the remote holds nothing yet: reported honestly rather
    // than as a success, because an absent record is the thing being checked.
    final check = await runSyncCheck(
      sync: () async => SyncOutcome.synced,
      openClient: () async => FakeRemoteStore(),
      deviceId: 'device-a',
      pathPrefix: 'punchme/daily/devices',
    );

    final report = jsonDecode(check.toJson()) as Map<String, dynamic>;
    expect(report['outcome'], 'synced');
    expect(report['present'], isFalse);
  });

  test('a non-map payload counts no records rather than throwing', () async {
    final remote = FakeRemoteStore(<String, String>{path: '[]'});

    final check = await runSyncCheck(
      sync: () async => SyncOutcome.synced,
      openClient: () async => remote,
      deviceId: 'device-a',
      pathPrefix: 'punchme/daily/devices',
    );

    final report = jsonDecode(check.toJson()) as Map<String, dynamic>;
    expect(report['present'], isTrue);
    expect(report['recordCount'], isNull);
  });

  test('falls back to the flavor path when none is given', () async {
    final check = await runSyncCheck(
      sync: () async => SyncOutcome.synced,
      openClient: () async => null,
      deviceId: 'device-a',
    );

    // Derived from the adopted MIME, so the sandbox flavor cannot report on
    // the daily build's records.
    expect(check.path, '${syncPathPrefix()}/device-a/log.json');
  });

  test('the report never carries a credential', () async {
    final check = await runSyncCheck(
      sync: () async => SyncOutcome.synced,
      openClient: () async => FakeRemoteStore(),
      deviceId: 'device-a',
      pathPrefix: 'punchme/daily/devices',
    );

    // The keys are fixed and none of them is a secret: the refresh token is
    // the shared kuhy-syncs credential and must never leave the phone.
    final report = jsonDecode(check.toJson()) as Map<String, dynamic>;
    expect(report.keys, <String>{
      'outcome',
      'deviceId',
      'path',
      'present',
      'recordCount',
      'remote',
    });
  });
}
