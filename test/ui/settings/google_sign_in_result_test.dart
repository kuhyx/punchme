import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/ui/settings/google_sign_in_result.dart';

import 'fake_account_token.dart';

/// Covers the three outcomes of one attempt through the plugin's channel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(resetFakeAccountToken);

  test('a minted token succeeds, asked for the Web client id', () async {
    final sent = fakeAccountToken('an-id-token');

    final attempt = await googleSignInAttempt(serverClientId: 'web-client');

    expect(attempt.status, GoogleSignInStatus.succeeded);
    expect(attempt.idToken, 'an-id-token');
    // The Web client id, not an Android one: Firebase rejects a token minted
    // for an Android client as an audience mismatch.
    expect(sent, [
      {'serverClientId': 'web-client'},
    ]);
  });

  test('a dismissed chooser is a choice, not a failure', () async {
    fakeAccountToken(null);

    final attempt = await googleSignInAttempt(serverClientId: 'web-client');

    expect(attempt.status, GoogleSignInStatus.cancelled);
    expect(attempt.detail, isNull);
  });

  test('a platform with no AccountManager fails loudly', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    final attempt = await googleSignInAttempt(serverClientId: 'web-client');

    expect(attempt.status, GoogleSignInStatus.failed);
    expect(attempt.detail, contains('no Google sign-in flow'));
  });
}
