import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:punchme/nfc/background_punch_channel.dart';
import 'package:punchme/nfc/nfc_service.dart';
import 'package:punchme/ui/home/home_with_nfc.dart';
import 'package:punchme/ui/home/punch_banner.dart';

import '../../support/fake_day_repository.dart';

/// The plumbing between the platform channel and the home screen.
///
/// Driven over a real [MethodChannel] with a mock host on the other end, so
/// the same wiring the phone uses is what is exercised here -- there is no
/// stand-in channel object that could drift from the real one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = 'kuhy.punchme/nfc.test';
  const channel = MethodChannel(channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late String? launchPayload;

  setUp(() {
    launchPayload = null;
    messenger.setMockMethodCallHandler(
      channel,
      (call) async =>
          call.method == kGetLaunchPunchMethod ? launchPayload : null,
    );
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  /// A service that finds no tags, so only the background path is in play.
  NfcService quietService() => NfcService(
    availability: () async => NfcAvailability.disabled,
    stopSession: () async {},
    startSession:
        ({
          required Set<NfcPollingOption> pollingOptions,
          required void Function(NfcTag) onDiscovered,
        }) async {},
  );

  Future<void> pump(WidgetTester tester, FakeDayRepository repo) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeWithNfc(
          repository: repo,
          service: quietService(),
          channel: BackgroundPunchChannel(channel: channel),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Delivers a warm tap the way `onNewIntent` does.
  Future<void> hostTaps(String payload) => messenger.handlePlatformMessage(
    channelName,
    const StandardMethodCodec().encodeMethodCall(
      MethodCall(kBackgroundPunchMethod, payload),
    ),
    (_) {},
  );

  testWidgets('commits the tap the app was launched by', (tester) async {
    launchPayload = '{"v":1,"tag":"desk"}';
    final repo = FakeDayRepository();
    await pump(tester, repo);

    expect(repo.savedDays, hasLength(1));
    expect(repo.savedDays.single.checkOut, isNull);
  });

  testWidgets('writes nothing when the app was launched normally', (
    tester,
  ) async {
    final repo = FakeDayRepository();
    await pump(tester, repo);

    expect(repo.savedDays, isEmpty);
    expect(find.text('CHECK IN'), findsOneWidget);
  });

  testWidgets('commits a warm tap delivered while running', (tester) async {
    final repo = FakeDayRepository();
    await pump(tester, repo);
    expect(repo.savedDays, isEmpty);

    await hostTaps('{"v":1,"tag":"door"}');
    await tester.pumpAndSettle();

    expect(repo.savedDays, hasLength(1));
  });

  testWidgets('shows the held banner when the app comes forward', (
    tester,
  ) async {
    final repo = FakeDayRepository();
    await pump(tester, repo);

    await hostTaps('{"v":1,"tag":"door"}');
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.textContaining('via door tag'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.pump(kPunchBannerDuration);
    await tester.pumpAndSettle();
  });

  testWidgets('a non-resumed lifecycle change shows nothing', (tester) async {
    final repo = FakeDayRepository();
    await pump(tester, repo);

    await hostTaps('{"v":1,"tag":"door"}');
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    // Still held: pausing is not somebody looking at the screen.
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a tap after disposal is not delivered', (tester) async {
    final repo = FakeDayRepository();
    await pump(tester, repo);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();
    await hostTaps('{"v":1,"tag":"door"}');
    await tester.pumpAndSettle();

    expect(repo.savedDays, isEmpty);
  });

  testWidgets('builds the real channel when none is injected', (tester) async {
    // No host answers `kuhy.punchme/nfc` here, so the drain reports no launch
    // tap rather than throwing -- which is the off-Android case too.
    await tester.pumpWidget(
      MaterialApp(
        home: HomeWithNfc(
          repository: FakeDayRepository(),
          service: quietService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CHECK IN'), findsOneWidget);
  });
}
