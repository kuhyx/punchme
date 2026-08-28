import 'dart:convert';

import 'package:crdt_sync_flutter/testing/fake_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/sync/session_dump.dart';

/// Covers the session export.
///
/// What it exports is the shared `kuhy-syncs` refresh token, which every
/// sibling app authenticates with. These tests pin that it reports absence
/// honestly rather than throwing, so "no session" is an answer and not a
/// crash on a device that was never enrolled.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reports a device that holds no session', () async {
    installFakeSecureStorage();

    final report = jsonDecode(await dumpSession()) as Map<String, dynamic>;

    expect(report['present'], isFalse);
    expect(report['credentials'], isNull);
    expect(report['account'], isNull);
  });

  test('exports the stored session and account', () async {
    installFakeSecureStorage(
      initial: <String, String>{
        kCredentialsKey: jsonEncode(<String, dynamic>{
          'id_token': 'an-id-token',
          'refresh_token': 'a-refresh-token',
          'expires_at': '2026-08-28T12:00:00.000Z',
        }),
        'firebase.account': jsonEncode(<String, dynamic>{
          'email': '321krzychu@gmail.com',
          'password': '',
        }),
      },
    );

    final report = jsonDecode(await dumpSession()) as Map<String, dynamic>;

    expect(report['present'], isTrue);
    final credentials = report['credentials']! as Map<String, dynamic>;
    expect(credentials['refresh_token'], 'a-refresh-token');
    final account = report['account']! as Map<String, dynamic>;
    expect(account['email'], '321krzychu@gmail.com');
  });

  test('an account marker with no session still reports absent', () async {
    // The state `isSyncConfigured` calls stale: a marker outliving its
    // session. Reporting `present: true` here would claim a credential that
    // is not actually in the blob.
    installFakeSecureStorage(
      initial: <String, String>{
        'firebase.account': jsonEncode(<String, dynamic>{
          'email': '321krzychu@gmail.com',
          'password': '',
        }),
      },
    );

    final report = jsonDecode(await dumpSession()) as Map<String, dynamic>;

    expect(report['present'], isFalse);
    expect(report['account'], isNotNull);
  });
}
