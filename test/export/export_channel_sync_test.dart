import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/export/export_channel.dart';

import '../support/fake_day_repository.dart';

/// The two channel methods that answer questions about sync.
///
/// Split from `export_channel_test.dart` to clear the 250-line gate. Both
/// report on syncing, but only one moves a credential -- so they are pinned
/// together, and apart from the export/import contract.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(kExportChannelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('ExportChannel sync methods', () {
    test('runs a sync check when one is wired up', () async {
      ExportChannel(
        repository: FakeDayRepository(),
        channel: channel,
        syncCheck: () async => '{"outcome":"synced"}',
      ).listen();

      final reply = await messenger.handlePlatformMessage(
        kExportChannelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall(kRunSyncCheckMethod),
        ),
        (_) {},
      );
      expect(
        const StandardMethodCodec().decodeEnvelope(reply!),
        contains('synced'),
      );
    });

    test('reports a build with no sync as an error', () async {
      // Better than answering "not synced": a build that cannot sync at all
      // and a device that merely is not enrolled are different problems.
      ExportChannel(repository: FakeDayRepository(), channel: channel).listen();

      final reply = await messenger.handlePlatformMessage(
        kExportChannelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall(kRunSyncCheckMethod),
        ),
        (_) {},
      );
      expect(
        () => const StandardMethodCodec().decodeEnvelope(reply!),
        throwsA(anything),
      );
    });

    test('exports a session when one is wired up', () async {
      ExportChannel(
        repository: FakeDayRepository(),
        channel: channel,
        sessionDump: () async => '{"present":true}',
      ).listen();

      final reply = await messenger.handlePlatformMessage(
        kExportChannelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall(kDumpSessionMethod),
        ),
        (_) {},
      );
      expect(
        const StandardMethodCodec().decodeEnvelope(reply!),
        contains('present'),
      );
    });

    test('reports a build that cannot export a session as an error', () async {
      ExportChannel(repository: FakeDayRepository(), channel: channel).listen();

      final reply = await messenger.handlePlatformMessage(
        kExportChannelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall(kDumpSessionMethod),
        ),
        (_) {},
      );
      expect(
        () => const StandardMethodCodec().decodeEnvelope(reply!),
        throwsA(anything),
      );
    });
  });
}
