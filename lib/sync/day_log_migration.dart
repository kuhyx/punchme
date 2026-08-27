/// Moving an existing JSON timesheet into the CRDT log, exactly once.
library;

import 'dart:convert';

import 'package:crdt_sync/crdt_sync.dart';
import 'package:punchme/data/day_repository.dart';
import 'package:punchme/models/settings.dart';
import 'package:punchme/sync/day_record_codec.dart';

/// What a migration attempt did.
enum MigrationOutcome {
  /// The log already held records; the JSON file was left alone.
  alreadyMigrated,

  /// Nothing to move: no days and no stored settings.
  nothingToMigrate,

  /// Days and settings were copied into the log.
  migrated,
}

/// Copies everything in [source] into [store], if the log is still empty.
///
/// Gated on the *local* log being empty rather than on anything remote: a
/// remote check is indeterminate on a device that is not enrolled, which
/// would make whether the migration runs unpredictable. An empty local log
/// is a fact this device can always establish.
///
/// [source] is only ever read. The old file stays exactly where it is, so a
/// migration that turns out to be wrong is recoverable by reinstalling the
/// previous build -- the safety property that matters when the input is the
/// user's real timesheet.
///
/// Every record is stamped from [LogStore.nextHlc], so migrated history
/// shares this device's monotonic clock and cannot claim a future instant a
/// later real punch would then lose to.
Future<MigrationOutcome> migrateIntoLog({
  required DayRepository source,
  required LogStore store,
}) async {
  if (store.snapshot().isNotEmpty) {
    return MigrationOutcome.alreadyMigrated;
  }
  final days = await source.loadDays();
  final settings = await source.loadSettings();
  // Defaults mean the user never opened Settings; writing them would be
  // indistinguishable from a deliberate choice when a peer later merges.
  //
  // Compared through `toJson` because `Settings` has no value equality: `!=`
  // on it is identity, which is always true for two separate instances and
  // would migrate a default settings record every time.
  // `toJson` sorts its collections, so the encoding is stable and two equal
  // settings objects always produce the same string.
  final hasSettings =
      json.encode(settings.toJson()) != json.encode(const Settings().toJson());
  if (days.isEmpty && !hasSettings) {
    return MigrationOutcome.nothingToMigrate;
  }
  for (final day in days) {
    await store.upsert(dayToRecord(day, store.nextHlc()));
  }
  if (hasSettings) {
    await store.upsert(settingsToRecord(settings, store.nextHlc()));
  }
  return MigrationOutcome.migrated;
}
