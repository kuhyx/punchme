import 'package:flutter_test/flutter_test.dart';
import 'package:kuhy_credit/kuhy_credit.dart';
import 'package:material_ui/material_ui.dart';
import 'package:punchme/ui/settings/google_sign_in_result.dart';
import 'package:punchme/ui/settings/settings_screen.dart';

import '../../support/fake_day_repository.dart';

void main() {
  // The credit sits at the end of the settings ListView, which stretches its
  // children; at kuhy_credit 0.3.0 that drew the logo invisibly wide.
  testWidgets('the credit logo shows at its own size', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          repository: FakeDayRepository(),
          now: () => DateTime(2026, 8, 25, 12),
          share:
              ({
                required String fileName,
                required String contents,
                required String subject,
              }) async {},
          syncProbe: () async => false,
          syncConnect: () async => GoogleSignInStatus.cancelled,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final logo = find.byKey(KuhyCredit.logoKey);
    await tester.scrollUntilVisible(
      logo,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(logo), const Size(40, 40));
  });
}
