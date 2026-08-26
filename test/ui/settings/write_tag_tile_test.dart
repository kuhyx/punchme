import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:punchme/nfc/nfc_service.dart';
import 'package:punchme/ui/settings/settings_screen.dart';
import 'package:punchme/ui/settings/write_tag_screen.dart';

import '../../support/fake_day_repository.dart';

void main() {
  DateTime now() => DateTime(2026, 8, 25, 9);

  Future<void> openTile(WidgetTester tester, {NfcService? nfc}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          repository: FakeDayRepository(),
          now: now,
          nfc: nfc,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tile = find.text('Write clock tag');
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }

  testWidgets('the tile opens the write-tag screen', (tester) async {
    await openTile(
      tester,
      nfc: NfcService(
        availability: () async => NfcAvailability.disabled,
        stopSession: () async {},
      ),
    );
    expect(find.byType(WriteTagScreen), findsOneWidget);
  });

  testWidgets('builds a real service when none was injected', (tester) async {
    // Exercises the `?? NfcService()` fallback: the screen opens, and nothing
    // touches the hardware until the user asks it to.
    await openTile(tester);
    expect(find.byType(WriteTagScreen), findsOneWidget);
  });
}
