import 'package:flutter/material.dart';
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

/// textgate: nothing kuhy sees carries a word Claude wrote.
///
/// Every painted string (Text, RichText, field decorations) on every screen
/// and state is collected; any run of 2+ letters fails. Numbers, durations
/// such as `8h 04m`, and user data (the fakes below use digit-only SSIDs and
/// tag labels) pass. The only kept chrome is the app's proper noun.
void main() {
  // Any letter at all: weekday initials (`M T W`) are words too. Durations
  // (`8h 04m`) are the one letter-bearing value, so they are cut out first.
  final word = RegExp('[A-Za-z]');
  final duration = RegExp(r'-?\+?\d+h \d{2}m');
  const keep = <String>{'punchme'};

  DateTime now() => DateTime(2026, 8, 25, 12);

  List<DayEntry> august({bool openToday = false}) => <DayEntry>[
    for (var d = 1; d <= 25; d++)
      DayEntry(
        dateKey: '2026-08-${d.toString().padLeft(2, '0')}',
        checkIn: DateTime(2026, 8, d, 9),
        checkOut: d == 25 && openToday ? null : DateTime(2026, 8, d, 17),
      ),
  ];

  /// Every painted string with a word in it, minus [keep].
  List<String> wordsOn(WidgetTester tester) =>
      <String>[
        for (final e in find.byType(RichText).evaluate())
          (e.widget as RichText).text.toPlainText(),
      ].where((s) {
        final bare = s.replaceAll(duration, '');
        return word.hasMatch(bare) && !keep.contains(s.trim());
      }).toList();

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1080, 12000);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  void expectNoWords(WidgetTester tester) =>
      expect(wordsOn(tester), isEmpty, reason: 'painted words');

  testWidgets('home, ready to check in', (tester) async {
    await pump(tester, HomeScreen(repository: FakeDayRepository(), now: now));
    expectNoWords(tester);
  });

  testWidgets('home, checked in, pending tap', (tester) async {
    await pump(
      tester,
      HomeScreen(
        repository: FakeDayRepository(days: august(openToday: true)),
        now: now,
      ),
    );
    expectNoWords(tester);
    await tester.tap(find.byType(InkWell).first);
    await tester.pump(const Duration(milliseconds: 100));
    expectNoWords(tester);
    await tester.pumpAndSettle(const Duration(seconds: 10));
  });

  testWidgets('home, checked out', (tester) async {
    await pump(
      tester,
      HomeScreen(
        repository: FakeDayRepository(days: august()),
        now: () => DateTime(2026, 8, 25, 18),
      ),
    );
    expectNoWords(tester);
  });

  testWidgets('history and day editor', (tester) async {
    await pump(
      tester,
      HistoryScreen(
        repository: FakeDayRepository(days: august()),
        now: now,
      ),
    );
    expectNoWords(tester);
    await pump(
      tester,
      DayEditor(
        entry: DayEntry(dateKey: '2026-08-25', checkIn: now()),
      ),
    );
    expectNoWords(tester);
  });

  testWidgets('stats', (tester) async {
    await pump(
      tester,
      StatsScreen(
        repository: FakeDayRepository(days: august()),
        now: now,
      ),
    );
    expectNoWords(tester);
  });

  testWidgets('settings, whole list', (tester) async {
    await pump(
      tester,
      SettingsScreen(
        repository: FakeDayRepository(days: august()),
        now: now,
        syncProbe: () async => false,
        syncConnect: () async => GoogleSignInStatus.cancelled,
      ),
    );
    expectNoWords(tester);
  });

  testWidgets('onboarding', (tester) async {
    await pump(
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
    await pump(
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
    await pump(
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
    await pump(
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
          at: now(),
          checkedIn: true,
          tagLabel: '42',
        ),
        onUndo: () {},
      ),
      punchBanner(
        result: PunchResult.committed(
          state: DayState.checkedOut,
          at: now(),
          checkedIn: false,
          tagLabel: kDefaultTagLabel,
        ),
        onUndo: () {},
      ),
      for (final refusal in PunchRefusal.values)
        punchBanner(
          result: PunchResult.refused(
            state: DayState.checkedIn,
            at: now(),
            refusal: refusal,
          ),
          onUndo: () {},
        ),
      blankTagBanner(),
      unknownTagVersionBanner(),
    ];
    for (final bar in bars) {
      await pump(tester, Scaffold(body: bar.content));
      expectNoWords(tester);
    }
  });

  testWidgets('settings, sync connected', (tester) async {
    await pump(
      tester,
      SettingsScreen(
        repository: FakeDayRepository(),
        now: now,
        syncProbe: () async => true,
        syncConnect: () async => GoogleSignInStatus.cancelled,
      ),
    );
    expectNoWords(tester);
  });
}
