import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:punchme/logic/day_state.dart';
import 'package:punchme/logic/punch_coordinator.dart';
import 'package:punchme/logic/surplus.dart';
import 'package:punchme/logic/target_time.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/nfc/nfc_service.dart';
import 'package:punchme/nfc/punch_tag.dart';
import 'package:punchme/ui/history/day_editor.dart';
import 'package:punchme/ui/history/history_screen.dart';
import 'package:punchme/ui/home/checkout_alarm_dialog.dart';
import 'package:punchme/ui/home/home_screen.dart';
import 'package:punchme/ui/home/punch_banner.dart';
import 'package:punchme/ui/onboarding/onboarding_screen.dart';
import 'package:punchme/ui/settings/google_sign_in_result.dart';
import 'package:punchme/ui/settings/settings_screen.dart';
import 'package:punchme/ui/settings/write_tag_screen.dart';
import 'package:punchme/ui/stats/stats_screen.dart';
import 'package:punchme/ui/wifi/location_rationale.dart';

import '../support/fake_day_repository.dart';
import '../support/fake_wifi.dart';
import '../support/no_words_harness.dart';

/// textgate: nothing kuhy sees carries a word Claude wrote.
///
/// Every painted string (Text, RichText, field decorations) on every screen
/// and state is collected; any run of 2+ letters fails. Numbers, durations
/// such as `8h 04m`, and user data (the fakes below use digit-only SSIDs and
/// tag labels) pass. The only kept chrome is the app's proper noun.
void main() {
  testWidgets('home, ready to check in', (tester) async {
    await pumpScreen(
      tester,
      HomeScreen(repository: FakeDayRepository(), now: noWordsNow),
    );
    expectNoWords(tester);
  });

  testWidgets('home, checked in, pending tap', (tester) async {
    await pumpScreen(
      tester,
      HomeScreen(
        repository: FakeDayRepository(days: august(openToday: true)),
        now: noWordsNow,
      ),
    );
    expectNoWords(tester);
    await tester.tap(find.byType(InkWell).first);
    await tester.pump(const Duration(milliseconds: 100));
    expectNoWords(tester);
    await tester.pumpAndSettle(const Duration(seconds: 10));
  });

  testWidgets('home, checked out', (tester) async {
    await pumpScreen(
      tester,
      HomeScreen(
        repository: FakeDayRepository(days: august()),
        now: () => DateTime(2026, 8, 25, 18),
      ),
    );
    expectNoWords(tester);
  });

  testWidgets('history and day editor', (tester) async {
    await pumpScreen(
      tester,
      HistoryScreen(
        repository: FakeDayRepository(days: august()),
        now: noWordsNow,
      ),
    );
    expectNoWords(tester);
    await pumpScreen(
      tester,
      DayEditor(
        entry: DayEntry(dateKey: '2026-08-25', checkIn: noWordsNow()),
      ),
    );
    expectNoWords(tester);
  });

  testWidgets('stats', (tester) async {
    await pumpScreen(
      tester,
      StatsScreen(
        repository: FakeDayRepository(days: august()),
        now: noWordsNow,
      ),
    );
    expectNoWords(tester);
  });

  testWidgets('settings, whole list', (tester) async {
    await pumpScreen(
      tester,
      SettingsScreen(
        repository: FakeDayRepository(days: august()),
        now: noWordsNow,
        syncProbe: () async => false,
        syncConnect: () async => GoogleSignInStatus.cancelled,
      ),
    );
    expectNoWords(tester);
  });

  testWidgets('onboarding', (tester) async {
    await pumpScreen(
      tester,
      OnboardingScreen(
        repository: FakeDayRepository(),
        picker: fakePicker(),
        status: () async => locationStatus(granted: false),
        requestLocation: () async => true,
        armWifi: ({required bool armed}) async {},
        openSettings: () async {},
      ),
    );
    expectNoWords(tester);
  });

  testWidgets('location rationale dialog', (tester) async {
    await pumpScreen(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showLocationRationaleDialog(context),
          child: const Icon(Icons.add),
        ),
      ),
    );
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expectNoWords(tester);
  });

  testWidgets('checkout alarm dialog', (tester) async {
    await pumpScreen(
      tester,
      CheckOutAlarmDialog(
        target: TargetToday(
          share: const Duration(hours: 8, minutes: 4),
          checkOutAt: DateTime(2026, 9, 15, 17, 4),
          level: DeficitLevel.month,
          deficit: const Duration(minutes: 30),
          spreadOver: 3,
          uncovered: const Duration(minutes: 5),
          surplus: Duration.zero,
          tightest: null,
          surplusSpread: null,
          surplusCapped: false,
        ),
      ),
    );
    expectNoWords(tester);
  });

  testWidgets('write tag screen', (tester) async {
    await pumpScreen(
      tester,
      WriteTagScreen(
        service: NfcService(
          availability: () async => NfcAvailability.disabled,
          stopSession: () async {},
          ndefFrom: (_) => null,
          startSession:
              ({
                required Set<NfcPollingOption> pollingOptions,
                required void Function(NfcTag) onDiscovered,
              }) async {},
        ),
      ),
    );
    expectNoWords(tester);
    await tester.tap(find.byKey(const Key('write-tag-go')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('write-tag-status')), findsOne);
    expectNoWords(tester);
  });

  testWidgets('punch banners and tag warnings', (tester) async {
    final bars = <SnackBar>[
      punchBanner(
        result: PunchResult.committed(
          state: DayState.checkedIn,
          at: noWordsNow(),
          checkedIn: true,
          tagLabel: '42',
        ),
        onUndo: () {},
      ),
      punchBanner(
        result: PunchResult.committed(
          state: DayState.checkedOut,
          at: noWordsNow(),
          checkedIn: false,
          tagLabel: kDefaultTagLabel,
        ),
        onUndo: () {},
      ),
      for (final refusal in PunchRefusal.values)
        punchBanner(
          result: PunchResult.refused(
            state: DayState.checkedIn,
            at: noWordsNow(),
            refusal: refusal,
          ),
          onUndo: () {},
        ),
      blankTagBanner(),
      unknownTagVersionBanner(),
    ];
    for (final bar in bars) {
      await pumpScreen(tester, Scaffold(body: bar.content));
      expectNoWords(tester);
    }
  });

  testWidgets('settings, sync connected', (tester) async {
    await pumpScreen(
      tester,
      SettingsScreen(
        repository: FakeDayRepository(),
        now: noWordsNow,
        syncProbe: () async => true,
        syncConnect: () async => GoogleSignInStatus.cancelled,
      ),
    );
    expectNoWords(tester);
  });
}
