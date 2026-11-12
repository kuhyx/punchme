import 'package:crdt_sync/crdt_sync.dart';
import 'package:crdt_sync_flutter/crdt_sync_flutter.dart'
    show kE2ePassphraseKey;
import 'package:crdt_sync_flutter/testing/fake_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/sync/sync_service.dart';

/// The passphrase every syncing test's keystore starts with.
const String kTestPassphrase = 'test-passphrase';

/// Installs the keystore fake for a test that syncs.
///
/// Sync is end-to-end encrypted, so a device with no passphrase is locked;
/// tests start with one unless [withPassphrase] is false. Argon2id is lowered
/// to a trivial cost and the library's per-process copy memo is reset, so
/// each test migrates from a clean slate.
void installE2eKeystore({bool withPassphrase = true}) {
  TestWidgetsFlutterBinding.ensureInitialized();
  e2eArgon2Params = const Argon2Params(
    memoryKiB: 8,
    iterations: 1,
    parallelism: 1,
  );
  resetE2eCopyMemo();
  e2eLocked.value = false;
  installFakeSecureStorage(
    initial: <String, String>{
      if (withPassphrase) kE2ePassphraseKey: kTestPassphrase,
    },
  );
}
