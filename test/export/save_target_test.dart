import 'package:data_transfer_flutter/data_transfer_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/export/save_target.dart';

class _FakePlatform implements DataTransferPlatform {
  final saves = <(String, String, String)>[];

  @override
  Future<bool> saveText({
    required String fileName,
    required String text,
    String mimeType = 'application/json',
  }) async {
    saves.add((fileName, text, mimeType));
    return true;
  }

  @override
  Future<bool> shareText({
    required String fileName,
    required String text,
    String mimeType = 'application/json',
  }) async => throw StateError('an export must not go to the share sheet');

  @override
  Future<String?> pickText() async => null;
}

void main() {
  late _FakePlatform fake;
  late DataTransferPlatform original;

  setUp(() {
    original = DataTransfer.platform;
    fake = _FakePlatform();
    DataTransfer.platform = fake;
  });

  tearDown(() => DataTransfer.platform = original);

  test(
    'saves the file through the Save-as picker, never the share sheet',
    () async {
      await saveTextFile(
        fileName: 'punchme.csv',
        contents: 'date,check_in\n',
        subject: 'punchme hours (CSV)',
      );

      expect(fake.saves.single, ('punchme.csv', 'date,check_in\n', 'text/csv'));
    },
  );

  test('types each export by its extension', () {
    expect(mimeTypeFor('punchme.csv'), 'text/csv');
    expect(mimeTypeFor('punchme.ics'), 'text/calendar');
    expect(mimeTypeFor('punchme.json'), 'application/json');
  });
}
