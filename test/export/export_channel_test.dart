import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/export/export_channel.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/settings.dart';

import '../support/fake_day_repository.dart';

/// The headless export path.
///
/// Kotlin never enters lcov, so this is where the contract is pinned: which
/// formats are accepted, what an unknown one does, and that the bytes are the
/// same ones the Settings buttons would produce.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(kExportChannelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final day = DayEntry(
    dateKey: '2026-08-25',
    checkIn: DateTime(2026, 8, 25, 9),
    checkOut: DateTime(2026, 8, 25, 17),
  );

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('ExportFormat.parse', () {
    test('accepts each known format', () {
      expect(ExportFormat.parse('json'), ExportFormat.json);
      expect(ExportFormat.parse('csv'), ExportFormat.csv);
      expect(ExportFormat.parse('ics'), ExportFormat.ics);
    });

    test('rejects an unknown name', () {
      expect(ExportFormat.parse('pdf'), isNull);
    });

    test('rejects a missing name', () {
      expect(ExportFormat.parse(null), isNull);
    });
  });

  group('renderExport', () {
    test('renders JSON carrying days and settings', () async {
      final repo = FakeDayRepository(
        days: <DayEntry>[day],
        settings: const Settings(),
      );
      final out = await renderExport(
        repository: repo,
        format: ExportFormat.json,
        now: DateTime(2026, 8, 27, 20),
      );
      expect(out, contains('"days"'));
      expect(out, contains('"settings"'));
      expect(out, contains('2026-08-25'));
    });

    test('renders CSV', () async {
      final out = await renderExport(
        repository: FakeDayRepository(days: <DayEntry>[day]),
        format: ExportFormat.csv,
        now: DateTime(2026, 8, 27, 20),
      );
      expect(out, contains('2026-08-25'));
    });

    test('renders iCalendar', () async {
      final out = await renderExport(
        repository: FakeDayRepository(days: <DayEntry>[day]),
        format: ExportFormat.ics,
        now: DateTime(2026, 8, 27, 20),
      );
      expect(out, contains('BEGIN:VCALENDAR'));
    });
  });

  group('ExportChannel', () {
    test('answers a known format with the rendered bytes', () async {
      final repo = FakeDayRepository(days: <DayEntry>[day]);
      ExportChannel(repository: repo, channel: channel).listen();

      final reply = await messenger.handlePlatformMessage(
        kExportChannelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall(kRunExportMethod, 'json'),
        ),
        (_) {},
      );
      final decoded = const StandardMethodCodec().decodeEnvelope(reply!);
      expect(decoded, contains('2026-08-25'));
    });

    test('reports an unknown format as a platform error', () async {
      ExportChannel(
        repository: FakeDayRepository(),
        channel: channel,
      ).listen();

      final reply = await messenger.handlePlatformMessage(
        kExportChannelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall(kRunExportMethod, 'pdf'),
        ),
        (_) {},
      );
      expect(
        () => const StandardMethodCodec().decodeEnvelope(reply!),
        throwsA(isA<PlatformException>()),
      );
    });

    test('ignores a method it does not know', () async {
      ExportChannel(
        repository: FakeDayRepository(),
        channel: channel,
      ).listen();

      final reply = await messenger.handlePlatformMessage(
        kExportChannelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('somethingElse', 'json'),
        ),
        (_) {},
      );
      expect(const StandardMethodCodec().decodeEnvelope(reply!), isNull);
    });

    test('restores a JSON export handed to it', () async {
      final repo = FakeDayRepository();
      ExportChannel(repository: repo, channel: channel).listen();

      final reply = await messenger.handlePlatformMessage(
        kExportChannelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall(
            kRunImportMethod,
            '{"days":[{"dateKey":"2026-08-27",'
            '"checkIn":"2026-08-27T09:00:00.000+02:00"}],"settings":{}}',
          ),
        ),
        (_) {},
      );
      expect(
        const StandardMethodCodec().decodeEnvelope(reply!),
        contains('restored 1 days'),
      );
      expect(repo.savedDays, hasLength(1));
    });

    test('reports a malformed import as an error', () async {
      ExportChannel(
        repository: FakeDayRepository(),
        channel: channel,
      ).listen();

      final reply = await messenger.handlePlatformMessage(
        kExportChannelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall(kRunImportMethod, 'not json'),
        ),
        (_) {},
      );
      expect(
        () => const StandardMethodCodec().decodeEnvelope(reply!),
        throwsA(anything),
      );
    });

    test('stop detaches the handler', () async {
      ExportChannel(repository: FakeDayRepository(), channel: channel)
        ..listen()
        ..stop();

      final reply = await messenger.handlePlatformMessage(
        kExportChannelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall(kRunExportMethod, 'json'),
        ),
        (_) {},
      );
      expect(reply, isNull);
    });

    test('builds the real channel and clock when none are injected', () {
      expect(
        () => ExportChannel(repository: FakeDayRepository()).listen(),
        returnsNormally,
      );
      ExportChannel(repository: FakeDayRepository()).stop();
    });
  });
}
