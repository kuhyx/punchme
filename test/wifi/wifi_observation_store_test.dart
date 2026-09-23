import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/wifi/wifi_observation_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late WifiObservationStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('punchme_wifi_test');
    store = WifiObservationStore(File('${dir.path}/wifi_observations.json'));
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('an absent file reads as empty', () async {
    expect(await store.load(), isEmpty);
  });

  test('a saved observation round-trips', () async {
    final at = DateTime(2026, 8, 25, 12, 30);
    await store.save(<String, DateTime>{'2026-08-25': at});
    expect(await store.load(), <String, DateTime>{'2026-08-25': at});
  });

  test('save replaces the whole file', () async {
    await store.save(<String, DateTime>{'2026-08-24': DateTime(2026, 8, 24)});
    await store.save(<String, DateTime>{'2026-08-25': DateTime(2026, 8, 25)});
    expect((await store.load()).keys, <String>['2026-08-25']);
  });

  test('creates the parent directory when it does not exist', () async {
    final nested = WifiObservationStore(
      File('${dir.path}/a/b/wifi_observations.json'),
    );
    await nested.save(<String, DateTime>{'2026-08-25': DateTime(2026, 8, 25)});
    expect(nested.file.existsSync(), isTrue);
  });

  group('damaged files', () {
    test('unparseable JSON reads as empty rather than throwing', () async {
      store.file.writeAsStringSync('{not json at all');
      expect(await store.load(), isEmpty);
    });

    test('an empty file reads as empty', () async {
      store.file.writeAsStringSync('   ');
      expect(await store.load(), isEmpty);
    });

    test('a JSON array instead of an object reads as empty', () async {
      store.file.writeAsStringSync('[]');
      expect(await store.load(), isEmpty);
    });

    test('a non-string value is skipped, not loaded', () async {
      store.file.writeAsStringSync('{"2026-08-25": 5}');
      expect(await store.load(), isEmpty);
    });

    test('an unparseable instant is skipped without losing the rest', () async {
      store.file.writeAsStringSync(
        '{"2026-08-24": "garbage", '
        '"2026-08-25": "2026-08-25T09:00:00.000+00:00"}',
      );
      expect((await store.load()).keys, <String>['2026-08-25']);
    });
  });

  group('open', () {
    const channel = MethodChannel('plugins.flutter.io/path_provider');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('places the file in the app-support directory', () async {
      final support = Directory('${dir.path}/support')..createSync();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => support.path);

      final opened = await WifiObservationStore.open();
      expect(opened.file.path, '${support.path}/wifi_observations.json');
    });
  });
}
