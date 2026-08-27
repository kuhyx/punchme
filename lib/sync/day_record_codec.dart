/// Translating punchme's models to and from the shared CRDT record shape.
library;

import 'package:crdt_sync/crdt_sync.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/local_date.dart';
import 'package:punchme/models/settings.dart';

/// The record id the single settings record is stored under.
///
/// A date key is `YYYY-MM-DD`, so a non-date id cannot collide with a day.
const String kSettingsRecordId = 'settings';

/// The field names a day record carries.
const String kCheckInField = 'checkIn';

/// The field holding the check-out instant, absent while a day is open.
const String kCheckOutField = 'checkOut';

/// Builds a record for [entry], stamping every field at [at].
///
/// Per-field rather than one blob: `checkIn` and `checkOut` then merge
/// independently, so a check-out written on the phone survives a concurrent
/// edit of the same day's check-in on another device.
///
/// An *open* day omits `checkOut` entirely rather than stamping it null,
/// unless [clearCheckOut] says the null is deliberate. Writing null
/// unconditionally loses real data: a device that has not merged yet sees no
/// day, creates a fresh open one at a later clock, and that null then beats
/// the peer's recorded check-out under last-writer-wins. Omitting the field
/// leaves the peer's value untouched, which is the safe direction -- while
/// `undoPunch` still needs the explicit clear, hence the flag.
///
/// Timestamps go through [isoWithOffset], the same spelling the JSON store
/// uses, so a value that round-trips through the log is byte-identical to one
/// that never left disk.
Record dayToRecord(DayEntry entry, Hlc at, {bool clearCheckOut = false}) =>
    Record(
      id: entry.dateKey,
      fields: <String, Field>{
        kCheckInField: (isoWithOffset(entry.checkIn), at),
        if (entry.checkOut != null)
          kCheckOutField: (isoWithOffset(entry.checkOut!), at)
        else if (clearCheckOut)
          kCheckOutField: (null, at),
      },
    );

/// Rebuilds a day from [record], or null when it does not describe one.
///
/// Null rather than throwing: a tombstoned record, a settings record, or one
/// written by a newer build with a missing field must not take down the whole
/// load. A day with no readable check-in is not a day.
DayEntry? recordToDay(Record record) {
  if (record.deleted || record.id == kSettingsRecordId) {
    return null;
  }
  final checkIn = record.fields[kCheckInField]?.$1;
  if (checkIn is! String) {
    return null;
  }
  final checkOut = record.fields[kCheckOutField]?.$1;
  try {
    return DayEntry(
      dateKey: record.id,
      checkIn: parseLocal(checkIn),
      checkOut: checkOut is String ? parseLocal(checkOut) : null,
    );
  } on FormatException {
    return null;
  }
}

/// Builds the single settings record, stamping every field at [at].
Record settingsToRecord(Settings settings, Hlc at) => Record(
  id: kSettingsRecordId,
  fields: <String, Field>{
    for (final entry in settings.toJson().entries) entry.key: (entry.value, at),
  },
);

/// Rebuilds settings from [record], falling back to defaults per field.
///
/// Mirrors [Settings.fromJson]'s tolerance: a field a peer never wrote leaves
/// that setting at its default rather than refusing the whole record.
Settings recordToSettings(Record record) => Settings.fromJson(
  record.fields.map((name, field) => MapEntry(name, field.$1)),
);

/// Every day in [log], ascending by date key, skipping unreadable records.
List<DayEntry> daysFromLog(Log log) {
  final days = <DayEntry>[
    for (final record in log.values) ?recordToDay(record),
  ]..sort((a, b) => a.dateKey.compareTo(b.dateKey));
  return days;
}

/// The settings in [log], or defaults when it holds none.
Settings settingsFromLog(Log log) {
  final record = log[kSettingsRecordId];
  if (record == null || record.deleted) {
    return const Settings();
  }
  return recordToSettings(record);
}
