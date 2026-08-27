import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/settings.dart';
import 'package:punchme/sync/crdt_day_repository.dart';
import 'package:punchme/sync/day_log_migration.dart';
import 'package:punchme/sync/day_record_codec.dart';

import '../support/fake_day_repository.dart';
import 'fake_log_persistence.dart';

/// Pins the one-shot move of an existing timesheet into the CRDT log.
///
/// The input here is the user's real work history, so the properties that
/// matter are that it runs exactly once, that it never writes to the source,
/// and that every instant survives byte-identical.
void main() {
  DayEntry day(String key, {DateTime? out}) => DayEntry(
    dateKey: key,
    checkIn: DateTime(2026, 8, 25, 10, 29),
    checkOut: out,
  );

  test('copies days and settings into an empty log', () async {
    final source = FakeDayRepository(
      days: <DayEntry>[
        day('2026-08-25', out: DateTime(2026, 8, 25, 18, 52)),
        day('2026-08-26'),
      ],
      settings: const Settings(requiredPerDay: Duration(hours: 7)),
    );
    final store = await openFakeStore();

    final outcome = await migrateIntoLog(source: source, store: store);

    expect(outcome, MigrationOutcome.migrated);
    final migrated = CrdtDayRepository(store: store);
    expect((await migrated.loadDays()).map((d) => d.dateKey), <String>[
      '2026-08-25',
      '2026-08-26',
    ]);
    expect(
      (await migrated.loadSettings()).requiredPerDay,
      const Duration(hours: 7),
    );
  });

  test('preserves every instant exactly, to the microsecond', () async {
    // The shape the real timesheet is in: mixed millisecond and microsecond
    // precision. A migration that rounded would rewrite recorded history.
    final checkIn = DateTime(2026, 8, 27, 9, 0, 35, 951, 752);
    final checkOut = DateTime(2026, 8, 27, 16, 41, 22, 401, 518);
    final source = FakeDayRepository(
      days: <DayEntry>[
        DayEntry(dateKey: '2026-08-27', checkIn: checkIn, checkOut: checkOut),
      ],
    );
    final store = await openFakeStore();

    await migrateIntoLog(source: source, store: store);

    final back = (await CrdtDayRepository(store: store).loadDays()).single;
    expect(back.checkIn, checkIn);
    expect(back.checkOut, checkOut);
  });

  test('never writes to the source', () async {
    final source = FakeDayRepository(days: <DayEntry>[day('2026-08-25')]);
    final store = await openFakeStore();

    await migrateIntoLog(source: source, store: store);

    // The old file is the recovery path if the migration is ever wrong, so
    // it has to survive untouched.
    expect(source.savedDays, isEmpty);
    expect(source.deletedKeys, isEmpty);
    expect(source.savedSettings, isEmpty);
  });

  test('is a no-op the second time, and does not duplicate', () async {
    final source = FakeDayRepository(days: <DayEntry>[day('2026-08-25')]);
    final store = await openFakeStore();
    await migrateIntoLog(source: source, store: store);

    final again = await migrateIntoLog(source: source, store: store);

    expect(again, MigrationOutcome.alreadyMigrated);
    expect(await CrdtDayRepository(store: store).loadDays(), hasLength(1));
  });

  test('leaves an empty source alone', () async {
    final store = await openFakeStore();

    final outcome = await migrateIntoLog(
      source: FakeDayRepository(),
      store: store,
    );

    expect(outcome, MigrationOutcome.nothingToMigrate);
    expect(store.snapshot(), isEmpty);
  });

  test('does not write a settings record for untouched defaults', () async {
    final store = await openFakeStore();

    await migrateIntoLog(
      source: FakeDayRepository(days: <DayEntry>[day('2026-08-25')]),
      store: store,
    );

    // Migrating defaults would look identical to a deliberate choice once a
    // peer merged it, overriding whatever that peer had actually set.
    expect(store.get(kSettingsRecordId), isNull);
  });

  test('migrates settings alone when there are no days', () async {
    final store = await openFakeStore();

    final outcome = await migrateIntoLog(
      source: FakeDayRepository(
        settings: const Settings(freeDays: <String>{'2026-08-25'}),
      ),
      store: store,
    );

    expect(outcome, MigrationOutcome.migrated);
    expect(
      (await CrdtDayRepository(store: store).loadSettings()).freeDays,
      <String>{'2026-08-25'},
    );
  });

  test('does not run when the log already holds only settings', () async {
    final store = await openFakeStore();
    await CrdtDayRepository(store: store).saveSettings(
      const Settings(requiredPerDay: Duration(hours: 6)),
    );

    final outcome = await migrateIntoLog(
      source: FakeDayRepository(days: <DayEntry>[day('2026-08-25')]),
      store: store,
    );

    // A log with any record in it has already been through this.
    expect(outcome, MigrationOutcome.alreadyMigrated);
    expect(await CrdtDayRepository(store: store).loadDays(), isEmpty);
  });

  test(
    'stamps migrated records with this device, in increasing order',
    () async {
      final source = FakeDayRepository(
        days: <DayEntry>[day('2026-08-25'), day('2026-08-26')],
      );
      final store = await openFakeStore(nodeId: 'migrating-device');

      await migrateIntoLog(source: source, store: store);

      final first = store.get('2026-08-25')!.fields[kCheckInField]!.$2;
      final second = store.get('2026-08-26')!.fields[kCheckInField]!.$2;
      expect(first.nodeId, 'migrating-device');
      expect(second.compareTo(first), greaterThan(0));
    },
  );
}
