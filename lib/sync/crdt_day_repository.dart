/// A [DayRepository] backed by the shared CRDT log.
library;

import 'package:crdt_sync/crdt_sync.dart';
import 'package:punchme/data/day_repository.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/settings.dart';
import 'package:punchme/sync/day_record_codec.dart';

/// Called after a write, to push it. Returns without waiting for the network.
typedef PushLog = void Function();

/// Stores days and settings as CRDT records instead of a flat JSON file.
///
/// Implements the same [DayRepository] interface the JSON store does, so
/// everything above it -- the coordinator, the screens, the export path --
/// is untouched by the change of backend.
///
/// Every write stamps its fields from [LogStore.nextHlc], so this device's
/// records and the store's own tombstones share one monotonic sequence and
/// two devices editing the same day converge per field rather than per day.
class CrdtDayRepository implements DayRepository {
  /// Creates a repository over [store].
  ///
  /// [onWrite] fires after each committed write. It is deliberately
  /// synchronous and defaults to doing nothing: a punch must not wait on the
  /// network, and no test should reach it by accident.
  CrdtDayRepository({required this.store, PushLog? onWrite})
    : _onWrite = onWrite ?? _noPush;

  /// The local CRDT log this repository reads and writes.
  final LogStore store;

  final PushLog _onWrite;

  static void _noPush() {}

  @override
  Future<List<DayEntry>> loadDays() async => daysFromLog(store.snapshot());

  @override
  Future<void> saveDay(DayEntry entry) async {
    // An open day only clears `checkOut` when this device already knew the
    // day was closed -- that is Undo, a deliberate reopen. A day this device
    // has never seen closed is a fresh check-in, and must leave the field
    // alone: writing null there would erase a check-out a peer recorded but
    // this device has not merged yet.
    final known = store.get(entry.dateKey);
    final reopening =
        entry.checkOut == null &&
        known != null &&
        !known.deleted &&
        known.fields[kCheckOutField]?.$1 != null;
    await store.upsert(
      dayToRecord(entry, store.nextHlc(), clearCheckOut: reopening),
    );
    _onWrite();
  }

  @override
  Future<void> deleteDay(String dateKey) async {
    // A tombstone rather than a drop: deleting a key that a peer still holds
    // would let that peer's copy return on the next merge. Absent locally is
    // not an error -- `undoPunch` can reach here for a day no longer stored.
    if (store.get(dateKey) == null) {
      return;
    }
    await store.delete(dateKey);
    _onWrite();
  }

  @override
  Future<Settings> loadSettings() async => settingsFromLog(store.snapshot());

  @override
  Future<void> saveSettings(Settings settings) async {
    await store.upsert(settingsToRecord(settings, store.nextHlc()));
    _onWrite();
  }
}
