import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/data/json_day_repository.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late JsonDayRepository repo;

  setUp(() {
    // A throwaway directory: the tests must never see, or touch, real data.
    dir = Directory.systemTemp.createTempSync('punchme_test');
    repo = JsonDayRepository(File('${dir.path}/punchme.json'));
  });

  tearDown(() => dir.deleteSync(recursive: true));

  DayEntry entry(String key, {bool closed = true}) {
    final checkIn = DateTime.parse('${key}T09:00:00');
    final day = DayEntry(dateKey: key, checkIn: checkIn);
    return closed ? day.closedAt(checkIn.add(const Duration(hours: 8))) : day;
  }

  group('days', () {
    test('an absent file reads as an empty history', () async {
      expect(await repo.loadDays(), isEmpty);
      expect(await repo.loadSettings(), isA<Settings>());
    });

    test('a saved day round-trips', () async {
      final day = entry('2026-08-25');
      await repo.saveDay(day);
      expect(await repo.loadDays(), <DayEntry>[day]);
    });

    test('an open day round-trips with a null check-out', () async {
      await repo.saveDay(entry('2026-08-25', closed: false));
      final loaded = await repo.loadDays();
      expect(loaded.single.checkOut, isNull);
      expect(loaded.single.isOpen, isTrue);
    });

    test('saving the same day twice replaces it', () async {
      await repo.saveDay(entry('2026-08-25', closed: false));
      await repo.saveDay(entry('2026-08-25'));
      final loaded = await repo.loadDays();
      expect(loaded, hasLength(1));
      expect(loaded.single.worked, const Duration(hours: 8));
    });

    test('days come back sorted regardless of save order', () async {
      await repo.saveDay(entry('2026-08-26'));
      await repo.saveDay(entry('2026-08-24'));
      await repo.saveDay(entry('2026-08-25'));
      expect(
        (await repo.loadDays()).map((d) => d.dateKey),
        <String>['2026-08-24', '2026-08-25', '2026-08-26'],
      );
    });

    test('an overnight session survives the round trip', () async {
      final night = DayEntry(
        dateKey: '2026-08-24',
        checkIn: DateTime(2026, 8, 24, 22),
        checkOut: DateTime(2026, 8, 25, 2),
      );
      await repo.saveDay(night);
      expect((await repo.loadDays()).single.worked, const Duration(hours: 4));
    });

    test('deleteDay removes just that day', () async {
      await repo.saveDay(entry('2026-08-24'));
      await repo.saveDay(entry('2026-08-25'));
      await repo.deleteDay('2026-08-24');
      expect((await repo.loadDays()).map((d) => d.dateKey), <String>[
        '2026-08-25',
      ]);
    });

    test('deleting an unknown day is not an error', () async {
      await repo.saveDay(entry('2026-08-25'));
      await repo.deleteDay('2020-01-01');
      expect(await repo.loadDays(), hasLength(1));
    });
  });

  group('settings', () {
    test('default when nothing was saved', () async {
      expect(
        (await repo.loadSettings()).requiredPerDay,
        const Duration(hours: 8),
      );
    });

    test('round-trip', () async {
      final settings = const Settings().copyWith(
        requiredPerDay: const Duration(hours: 6),
        freeDays: const <String>{'2026-12-25'},
      );
      await repo.saveSettings(settings);
      final loaded = await repo.loadSettings();
      expect(loaded.requiredPerDay, const Duration(hours: 6));
      expect(loaded.freeDays, const <String>{'2026-12-25'});
    });

    test('saving settings does not disturb the days, and vice versa', () async {
      await repo.saveDay(entry('2026-08-25'));
      await repo.saveSettings(
        const Settings().copyWith(requiredPerDay: const Duration(hours: 4)),
      );
      expect(await repo.loadDays(), hasLength(1));
      expect(
        (await repo.loadSettings()).requiredPerDay,
        const Duration(hours: 4),
      );
    });
  });

  group('damaged files', () {
    test('unparseable JSON reads as empty rather than throwing', () async {
      repo.file.writeAsStringSync('{not json at all');
      expect(await repo.loadDays(), isEmpty);
      expect(
        (await repo.loadSettings()).requiredPerDay,
        const Duration(hours: 8),
      );
    });

    test('an empty file reads as empty', () async {
      repo.file.writeAsStringSync('   ');
      expect(await repo.loadDays(), isEmpty);
    });

    test('a JSON array instead of an object reads as empty', () async {
      repo.file.writeAsStringSync('[]');
      expect(await repo.loadDays(), isEmpty);
    });

    test('a non-list days field reads as empty', () async {
      repo.file.writeAsStringSync(json.encode(<String, dynamic>{'days': 5}));
      expect(await repo.loadDays(), isEmpty);
    });

    test('one unreadable record does not lose the others', () async {
      repo.file.writeAsStringSync(
        json.encode(<String, dynamic>{
          'days': <dynamic>[
            'not a map',
            <String, dynamic>{'dateKey': '2026-08-25'}, // missing checkIn
            entry('2026-08-26').toJson(),
          ],
        }),
      );
      expect((await repo.loadDays()).map((d) => d.dateKey), <String>[
        '2026-08-26',
      ]);
    });

    test('a record with a malformed dateKey is skipped, not loaded', () async {
      repo.file.writeAsStringSync(
        json.encode(<String, dynamic>{
          'days': <dynamic>[
            <String, dynamic>{
              'dateKey': 'garbage',
              'checkIn': '2026-08-25T09:00:00.000+02:00',
            },
            entry('2026-08-26').toJson(),
          ],
        }),
      );
      // The bad record must not survive to reach the statistics screen.
      expect(
        (await repo.loadDays()).map((d) => d.dateKey),
        <String>['2026-08-26'],
      );
    });

    test('a non-map settings field falls back to defaults', () async {
      repo.file.writeAsStringSync(
        json.encode(<String, dynamic>{'settings': 'nope'}),
      );
      expect(
        (await repo.loadSettings()).requiredPerDay,
        const Duration(hours: 8),
      );
    });

    test('a corrupt file is repaired by the next write', () async {
      repo.file.writeAsStringSync('{broken');
      await repo.saveDay(entry('2026-08-25'));
      expect(await repo.loadDays(), hasLength(1));
    });
  });

  test('creates the parent directory when it does not exist', () async {
    final nested = JsonDayRepository(File('${dir.path}/a/b/punchme.json'));
    await nested.saveDay(entry('2026-08-25'));
    expect(nested.file.existsSync(), isTrue);
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

      final opened = await JsonDayRepository.open();
      expect(opened.file.path, '${support.path}/punchme.json');

      // And it is a working repository, not just a path.
      await opened.saveDay(entry('2026-08-25'));
      expect(await opened.loadDays(), hasLength(1));
    });
  });
}
