import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/main.dart';
import 'package:punchme/nfc/background_punch_channel.dart';
import 'package:punchme/nfc/punch_tag.dart';
import 'package:punchme/ui/home/home_screen.dart';

import 'support/fake_day_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `bootstrap` asks the host for its MIME type. Under `testWidgets` the body
  // runs in a fake-async zone, so an unanswered platform call never completes:
  // the MissingPluginException that ends it off-device is delivered by the real
  // event loop, which the fake clock never pumps. Answering it here keeps the
  // await from hanging the whole file -- and a hung file writes no coverage at
  // all, which is what dropped PunchmeApp.build out of the report.
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const nfcChannel = MethodChannel(kNfcChannelName);

  // `openSyncedStore` reaches SharedPreferences for the device id and the
  // keystore for a session. Both are platform channels with no host under
  // `flutter_test`, and an unanswered one hangs the whole file rather than
  // throwing -- see the note above.
  const prefsChannel = MethodChannel('plugins.flutter.io/shared_preferences');
  const secureChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  setUp(() {
    messenger
      ..setMockMethodCallHandler(nfcChannel, (call) async => null)
      ..setMockMethodCallHandler(prefsChannel, (call) async {
        // First launch: no stored id, so the identity is generated and
        // written back. `setValue` must answer true, not null.
        if (call.method == 'getAll') return <String, Object?>{};
        return call.method.startsWith('set') || call.method == 'clear';
      })
      // No stored session: the device reads as not enrolled, which is a
      // normal state and keeps the suite off the network entirely.
      ..setMockMethodCallHandler(secureChannel, (call) async => null);
  });

  tearDown(() {
    messenger
      ..setMockMethodCallHandler(nfcChannel, null)
      ..setMockMethodCallHandler(prefsChannel, null)
      ..setMockMethodCallHandler(secureChannel, null);
    activePunchMime = kPunchMime;
  });

  testWidgets('the app root builds and lands on the home screen', (
    tester,
  ) async {
    await tester.pumpWidget(PunchmeApp(repository: FakeDayRepository()));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('CHECK IN'), findsOneWidget);
  });

  testWidgets('uses the shared design-system themes', (tester) async {
    await tester.pumpWidget(PunchmeApp(repository: FakeDayRepository()));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'punchme');
    expect(app.theme, isNotNull);
    expect(app.darkTheme, isNotNull);
    // The frozen palette's accent, not a Material default.
    expect(app.theme!.colorScheme.primary, const Color(0xFFB8862E));
  });

  testWidgets('bootstrap opens the on-disk store and builds the app', (
    tester,
  ) async {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final dir = Directory.systemTemp.createTempSync('punchme_boot');
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      dir.deleteSync(recursive: true);
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);

    await tester.pumpWidget(await bootstrap());
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(File('${dir.path}/punchme.json').existsSync(), isFalse);
  });

  testWidgets('runPunchme boots and hands the app to the runner', (
    tester,
  ) async {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final dir = Directory.systemTemp.createTempSync('punchme_run');
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      dir.deleteSync(recursive: true);
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);

    Widget? handed;
    await runPunchme(run: (app) => handed = app);

    expect(handed, isA<PunchmeApp>());
  });
}
