import 'dart:convert';

import 'package:crdt_sync_flutter/testing/fake_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:punchme/sync/sync_service.dart';
import 'package:punchme/ui/settings/sync_actions.dart';

/// Drives the production defaults rather than an injected stub.
///
/// Split from `sync_actions_test.dart` to clear the 250-line gate. An
/// injected fake proves the widget works; these prove it is actually plugged
/// into the shared sync library.
void main() {
  // These drive the production defaults rather than an injected stub, so
  // the wiring to the shared library is covered too -- an injected fake
  // proves the widget works, not that it is plugged into anything.

  testWidgets('probeSyncSession is false with an empty keystore', (
    tester,
  ) async {
    installFakeSecureStorage();

    expect(await probeSyncSession(), isFalse);
  });

  testWidgets('probeSyncSession is false when the keystore throws', (
    tester,
  ) async {
    // A host with no secret service. Not being able to read a session is
    // "not configured", never a crash on the settings screen.
    installFakeSecureStorage(throwing: true);

    expect(await probeSyncSession(), isFalse);
  });

  testWidgets('connectSyncAccount is false when the picker is dismissed', (
    tester,
  ) async {
    installFakeSecureStorage();

    // Null id token is what the plugin returns when the user backs out.
    expect(await connectSyncAccount(signInFn: () async => null), isFalse);
  });

  testWidgets('connectSyncAccount is true once Firebase accepts the token', (
    tester,
  ) async {
    installFakeSecureStorage();
    // Stands in for identitytoolkit: the shape `signInWithIdp` expects.
    final firebase = http_testing.MockClient(
      (_) async => http.Response(
        jsonEncode(<String, dynamic>{
          'localId': kSyncUid,
          'idToken': 'an-id-token',
          'refreshToken': 'a-refresh-token',
          'expiresIn': '3600',
          'email': '321krzychu@gmail.com',
        }),
        200,
      ),
    );

    final connected = await connectSyncAccount(
      signInFn: () async => 'a-google-id-token',
      httpClient: firebase,
    );

    expect(connected, isTrue);
    // The session is durable now, so the probe agrees.
    expect(await probeSyncSession(), isTrue);
  });

  testWidgets('connectSyncAccount rejects the wrong Google account', (
    tester,
  ) async {
    installFakeSecureStorage();
    final firebase = http_testing.MockClient(
      (_) async => http.Response(
        jsonEncode(<String, dynamic>{
          'localId': 'someone-elses-uid',
          'idToken': 'an-id-token',
          'refreshToken': 'a-refresh-token',
          'expiresIn': '3600',
        }),
        200,
      ),
    );

    // Signing in as the wrong account must fail loudly: it would otherwise
    // authenticate fine and then be denied every read and write.
    await expectLater(
      connectSyncAccount(
        signInFn: () async => 'a-google-id-token',
        httpClient: firebase,
      ),
      throwsA(isA<Exception>()),
    );
    expect(await probeSyncSession(), isFalse);
  });

  testWidgets('the tile uses the real calls by default', (tester) async {
    installFakeSecureStorage();

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SyncActions())),
    );
    await tester.pumpAndSettle();

    // The default probe ran and found no session.
    expect(find.text('Connect Google account'), findsOneWidget);
  });
}
