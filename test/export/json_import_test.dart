import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/export/json_export.dart';
import 'package:punchme/export/json_import.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/settings.dart';

import '../support/fake_day_repository.dart';

/// Restoring an export.
///
/// The round-trip test is the important one: a backup is only a backup if it
/// puts back exactly what it took, down to the sub-second precision the day
/// editor's time picker cannot express.
void main() {
  test('round-trips days and settings without loss', () async {
    const settings = Settings(
      requiredPerDay: Duration(minutes: 480),
      workingWeekdays: <int>{2, 3, 4},
      freeDays: <String>{'2026-09-02', '2026-09-03'},
    );
    final days = <DayEntry>[
      DayEntry(
        dateKey: '2026-08-27',
        // Microsecond precision, exactly as a real recorded punch carries.
        checkIn: DateTime.parse('2026-08-27T09:00:35.951752+02:00'),
        checkOut: DateTime.parse('2026-08-27T16:41:22.401518+02:00'),
      ),
    ];
    final exported = toJsonExport(days: days, settings: settings);

    final repo = FakeDayRepository();
    final result = await importJson(repository: repo, source: exported);

    expect(result.days, 1);
    expect(result.settingsRestored, isTrue);
    final restored = await repo.loadDays();
    // Compared as instants: the file stores an offset, so a restore yields
    // the same moment expressed in the device's local zone. What must not
    // change is the instant itself, microseconds included.
    expect(
      restored.single.checkIn.isAtSameMomentAs(days.single.checkIn),
      isTrue,
      reason: 'check-in instant must survive the round trip exactly',
    );
    expect(
      restored.single.checkOut!.isAtSameMomentAs(days.single.checkOut!),
      isTrue,
      reason: 'check-out instant must survive the round trip exactly',
    );
    expect(restored.single.checkIn.microsecond, 752);
    expect(restored.single.checkOut!.microsecond, 518);
    expect(repo.savedSettings.single.freeDays, settings.freeDays);
    expect(repo.savedSettings.single.workingWeekdays, <int>{2, 3, 4});
  });

  test('restores days when the export carries no settings', () async {
    final repo = FakeDayRepository();
    final result = await importJson(
      repository: repo,
      source:
          '{"days":[{"dateKey":"2026-08-27",'
          '"checkIn":"2026-08-27T09:00:00.000+02:00"}]}',
    );
    expect(result.days, 1);
    expect(result.settingsRestored, isFalse);
    expect(repo.savedSettings, isEmpty);
  });

  test('accepts an empty day list', () async {
    final repo = FakeDayRepository();
    final result = await importJson(
      repository: repo,
      source: '{"days":[],"settings":{}}',
    );
    expect(result.days, 0);
    expect(result.settingsRestored, isTrue);
  });

  test('rejects payloads that are not JSON', () {
    expect(
      () => importJson(repository: FakeDayRepository(), source: 'nope'),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects JSON that is not an object', () {
    expect(
      () => importJson(repository: FakeDayRepository(), source: '[1,2]'),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects an export with no days list', () {
    expect(
      () => importJson(repository: FakeDayRepository(), source: '{"a":1}'),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects a day entry that is not an object', () {
    expect(
      () => importJson(
        repository: FakeDayRepository(),
        source: '{"days":[42]}',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
