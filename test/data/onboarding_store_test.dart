import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/data/onboarding_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('punchme_onboard'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('is not done until marked', () async {
    final store = OnboardingStore(File('${dir.path}/nested/onboarding_done'));
    expect(store.isDone(), isFalse);
    await store.markDone();
    expect(store.isDone(), isTrue);
  });

  test('open() lives in the app-support directory', () async {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          ..setMockMethodCallHandler(channel, (_) async => dir.path);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final store = await OnboardingStore.open();
    expect(store.file.path, '${dir.path}/onboarding_done');
  });
}
