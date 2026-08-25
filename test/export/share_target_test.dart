import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/export/share_target.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  const share = MethodChannel('dev.fluttercommunity.plus/share');

  late Directory temp;
  late List<MethodCall> shareCalls;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('punchme_share');
    shareCalls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          ..setMockMethodCallHandler(pathProvider, (_) async => temp.path);
    messenger.setMockMethodCallHandler(share, (call) async {
      shareCalls.add(call);
      return 'dev.fluttercommunity.plus/share/success';
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          ..setMockMethodCallHandler(pathProvider, null);
    messenger.setMockMethodCallHandler(share, null);
    temp.deleteSync(recursive: true);
  });

  test(
    'writes the file into the temp dir and hands it to the share sheet',
    () async {
      await shareTextFile(
        fileName: 'punchme.csv',
        contents: 'date,check_in\n',
        subject: 'punchme hours (CSV)',
      );

      final written = File('${temp.path}/punchme.csv');
      expect(written.existsSync(), isTrue);
      expect(written.readAsStringSync(), 'date,check_in\n');
      expect(shareCalls, hasLength(1));
    },
  );

  test('overwrites a previous export of the same name', () async {
    await shareTextFile(
      fileName: 'punchme.csv',
      contents: 'first',
      subject: 's',
    );
    await shareTextFile(
      fileName: 'punchme.csv',
      contents: 'second',
      subject: 's',
    );
    expect(File('${temp.path}/punchme.csv').readAsStringSync(), 'second');
  });
}
