import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/main.dart';
import 'package:punchme/ui/home/home_screen.dart';

import 'support/fake_day_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
