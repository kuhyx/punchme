import 'package:crdt_sync_flutter/testing/fake_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/sync/sync_service.dart';
import 'package:punchme/ui/settings/google_sign_in_result.dart';
import 'package:punchme/ui/settings/sync_actions.dart';

/// Covers the icon-only passphrase button on the sync tile: it shows the
/// lock state the last tick published and retries the sync once a
/// passphrase is saved.
void main() {
  const button = Key('e2e-passphrase');

  Future<void> pump(
    WidgetTester tester, {
    required bool connected,
    ValueListenable<bool>? locked,
    Future<void> Function()? onSaved,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SyncActions(
            probe: () async => connected,
            connect: () async => GoogleSignInStatus.succeeded,
            locked: locked,
            onPassphraseSaved: onSaved,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  tearDown(() {
    e2eLocked.value = false;
    resyncAfterPassphrase = () async {};
  });

  testWidgets('no button before the device is connected', (tester) async {
    await pump(tester, connected: false);

    expect(find.byKey(button), findsNothing);
  });

  testWidgets('the glyph follows the published lock state', (tester) async {
    final locked = ValueNotifier<bool>(true);
    await pump(tester, connected: true, locked: locked);

    expect(find.byIcon(Icons.lock), findsOneWidget);

    locked.value = false;
    await tester.pump();

    expect(find.byIcon(Icons.lock_open), findsOneWidget);
  });

  testWidgets('saving a passphrase stores it and retries', (tester) async {
    installFakeSecureStorage();
    var retried = 0;
    await pump(tester, connected: true, onSaved: () async => retried++);

    await tester.tap(find.byKey(button));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'secret');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(retried, 1);
  });

  testWidgets('defaults to the tick-published state and retry', (tester) async {
    installFakeSecureStorage();
    e2eLocked.value = true;
    var retried = 0;
    resyncAfterPassphrase = () async => retried++;
    await pump(tester, connected: true);

    expect(find.byIcon(Icons.lock), findsOneWidget);

    await tester.tap(find.byKey(button));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'secret');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(retried, 1);
  });
}
