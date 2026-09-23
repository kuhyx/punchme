import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/models/settings.dart';
import 'package:punchme/ui/home/home_with_nfc.dart';
import 'package:punchme/wifi/wifi_observation_store.dart';

import '../../support/fake_day_repository.dart';

/// The Wi-Fi resume check `HomeWithNfc` runs alongside its NFC plumbing.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('punchme_resume_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  testWidgets('a work network on resume checks in at once', (tester) async {
    final repo = FakeDayRepository(
      settings: const Settings(workWifiSsids: <String>{'Office'}),
    );
    final store = WifiObservationStore(File('${dir.path}/wifi.json'));

    await tester.pumpWidget(
      MaterialApp(
        home: HomeWithNfc(
          repository: repo,
          now: () => DateTime(2026, 8, 25, 9),
          currentSsid: () async => 'Office',
          openObservations: () async => store,
        ),
      ),
    );
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(repo.savedDays, hasLength(1));
    expect(repo.savedDays.single.checkOut, isNull);
  });

  testWidgets('a missing platform channel is not an error', (tester) async {
    // A real "no host behind this channel" call is unawaited from the
    // lifecycle callback, so its rejection can land on a tick `pumpAndSettle`
    // has already stopped watching for. Throwing directly keeps this
    // deterministic while still exercising the same catch clause.
    await tester.pumpWidget(
      MaterialApp(
        home: HomeWithNfc(
          repository: FakeDayRepository(),
          currentSsid: () async => throw MissingPluginException('no host'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('CHECK IN'), findsOneWidget);
  });
}
