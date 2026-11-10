/// Raising the Google picker, and saying which of three things happened.
///
/// `google_account_token` returns null for a dismissed chooser and for a
/// failed token request alike (it logs the failure), so on Android a null is
/// reported as a cancel. What stays distinct is the platform with no
/// AccountManager at all: there the attempt fails with a reason the user sees,
/// as it did before the plugin swap.
library;

import 'package:google_account_token/google_account_token.dart' as plugin;

/// Which of the three outcomes a sign-in attempt reached.
enum GoogleSignInStatus {
  /// An ID token came back.
  succeeded,

  /// The user backed out. A choice, not a failure: nothing to report.
  cancelled,

  /// Google refused. The user has to see this, with the reason.
  failed,
}

/// The outcome of one attempt, with the detail needed to act on a failure.
class GoogleSignInResult {
  /// A successful attempt carrying [idToken].
  const GoogleSignInResult.succeeded(String this.idToken)
    : status = GoogleSignInStatus.succeeded,
      detail = null;

  /// A user-dismissed picker.
  const GoogleSignInResult.cancelled()
    : status = GoogleSignInStatus.cancelled,
      idToken = null,
      detail = null;

  /// A refusal, described by [detail].
  const GoogleSignInResult.failed(String this.detail)
    : status = GoogleSignInStatus.failed,
      idToken = null;

  /// What happened.
  final GoogleSignInStatus status;

  /// The Google ID token, when one was minted.
  final String? idToken;

  /// Why the attempt failed, in terms a person can act on.
  final String? detail;
}

/// Raises the account chooser and reports what came back.
///
/// [serverClientId] must be the project's **Web** client id; Android has to
/// request a token minted for it, and an Android client id yields a token
/// Firebase rejects as an audience mismatch.
Future<GoogleSignInResult> googleSignInAttempt({
  required String serverClientId,
}) async {
  if (!plugin.googleAccountTokenSupported) {
    return const GoogleSignInResult.failed(
      'this platform has no Google sign-in flow available',
    );
  }
  final token = await plugin.googleIdToken(serverClientId: serverClientId);
  if (token == null) {
    return const GoogleSignInResult.cancelled();
  }
  return GoogleSignInResult.succeeded(token);
}
