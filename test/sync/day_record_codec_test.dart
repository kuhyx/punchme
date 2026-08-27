import 'package:crdt_sync/crdt_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/local_date.dart';
import 'package:punchme/models/settings.dart';
import 'package:punchme/sync/day_record_codec.dart';

/// Pins the translation between punchme's models and the shared CRDT shape.
///
/// The round-trip cases matter most: a timestamp that loses its offset here
/// would silently rewrite the user's real timesheet the first time it synced,
/// and the migration would report success while doing it.
void main() {
  const node = 'test-node';
  const at = Hlc(wallTimeMs: 1700000000000, counter: 0, nodeId: node);
  const later = Hlc(wallTimeMs: 1700000001000, counter: 0, nodeId: node);

  group('dayToRecord', () {
    test('keys the record by the date key', () {
      final entry = DayEntry(
        dateKey: '2026-08-25',
        checkIn: DateTime(2026, 8, 25, 10, 29),
      );

      expect(dayToRecord(entry, at).id, '2026-08-25');
    });

    test('omits the check-out of an open day rather than nulling it', () {
      final entry = DayEntry(
        dateKey: '2026-08-25',
        checkIn: DateTime(2026, 8, 25, 10, 29),
      );

      final record = dayToRecord(entry, at);

      expect(record.fields[kCheckInField]!.$2, at);
      // Absent, not null: a null stamped at a later clock would beat, and
      // erase, a check-out a peer had already recorded for this day.
      expect(record.fields.containsKey(kCheckOutField), isFalse);
    });

    test('stamps an explicit null when the clear is deliberate', () {
      final entry = DayEntry(
        dateKey: '2026-08-25',
        checkIn: DateTime(2026, 8, 25, 10, 29),
      );

      final record = dayToRecord(entry, at, clearCheckOut: true);

      // Undo reopening a sealed day: the null has to travel, and win.
      expect(record.fields[kCheckOutField]!.$1, isNull);
      expect(record.fields[kCheckOutField]!.$2, at);
    });

    test('writes timestamps with their offset', () {
      final checkIn = DateTime(2026, 8, 25, 10, 29);
      final entry = DayEntry(dateKey: '2026-08-25', checkIn: checkIn);

      expect(
        dayToRecord(entry, at).fields[kCheckInField]!.$1,
        isoWithOffset(checkIn),
      );
    });
  });

  group('recordToDay', () {
    test('round-trips a closed day unchanged', () {
      final entry = DayEntry(
        dateKey: '2026-08-25',
        checkIn: DateTime(2026, 8, 25, 10, 29),
        checkOut: DateTime(2026, 8, 25, 18, 52),
      );

      final back = recordToDay(dayToRecord(entry, at))!;

      expect(back.dateKey, entry.dateKey);
      expect(back.checkIn, entry.checkIn);
      expect(back.checkOut, entry.checkOut);
    });

    test('round-trips an open day, keeping the check-out null', () {
      final entry = DayEntry(
        dateKey: '2026-08-26',
        checkIn: DateTime(2026, 8, 26, 9),
      );

      final back = recordToDay(dayToRecord(entry, at))!;

      expect(back.checkOut, isNull);
      expect(back.isOpen, isTrue);
    });

    test('round-trips a microsecond-precision instant exactly', () {
      // The real timesheet holds both millisecond and microsecond forms; a
      // codec that truncated would rewrite history on the first sync.
      final checkIn = DateTime(2026, 8, 27, 9, 0, 35, 951, 752);
      final entry = DayEntry(dateKey: '2026-08-27', checkIn: checkIn);

      expect(recordToDay(dayToRecord(entry, at))!.checkIn, checkIn);
    });

    test('is null for a tombstoned record', () {
      final entry = DayEntry(
        dateKey: '2026-08-25',
        checkIn: DateTime(2026, 8, 25, 10, 29),
      );
      final record = dayToRecord(entry, at);

      expect(
        recordToDay(
          Record(id: record.id, fields: record.fields, deleted: true),
        ),
        isNull,
      );
    });

    test('is null for the settings record', () {
      expect(recordToDay(settingsToRecord(const Settings(), at)), isNull);
    });

    test('is null when the check-in is missing or not a string', () {
      expect(
        recordToDay(
          const Record(id: '2026-08-25', fields: <String, Field>{}),
        ),
        isNull,
      );
      expect(
        recordToDay(
          const Record(
            id: '2026-08-25',
            fields: <String, Field>{kCheckInField: (42, at)},
          ),
        ),
        isNull,
      );
    });

    test('is null when a stored timestamp is unparseable', () {
      expect(
        recordToDay(
          const Record(
            id: '2026-08-25',
            fields: <String, Field>{kCheckInField: ('not-a-date', at)},
          ),
        ),
        isNull,
      );
    });

    test('drops an unparseable check-out rather than the whole day', () {
      final day = recordToDay(
        const Record(
          id: '2026-08-25',
          fields: <String, Field>{
            kCheckInField: ('2026-08-25T10:29:00.000+02:00', at),
            kCheckOutField: (7, at),
          },
        ),
      );

      expect(day, isNotNull);
      expect(day!.checkOut, isNull);
    });
  });

  group('settings', () {
    test('round-trips every field', () {
      const settings = Settings(
        requiredPerDay: Duration(hours: 7, minutes: 30),
        workingWeekdays: <int>{1, 2, 3},
        freeDays: <String>{'2026-08-25'},
      );

      final back = recordToSettings(settingsToRecord(settings, at));

      expect(back.requiredPerDay, settings.requiredPerDay);
      expect(back.workingWeekdays, settings.workingWeekdays);
      expect(back.freeDays, settings.freeDays);
    });

    test('falls back to defaults for a field a peer never wrote', () {
      final back = recordToSettings(
        const Record(id: kSettingsRecordId, fields: <String, Field>{}),
      );

      expect(back.requiredPerDay, const Duration(hours: 8));
      expect(back.workingWeekdays, Settings.defaultWorkingWeekdays);
      expect(back.freeDays, isEmpty);
    });
  });

  group('daysFromLog', () {
    test('returns days ascending by key, skipping non-days', () {
      final log = <String, Record>{
        '2026-08-26': dayToRecord(
          DayEntry(dateKey: '2026-08-26', checkIn: DateTime(2026, 8, 26, 9)),
          at,
        ),
        '2026-08-25': dayToRecord(
          DayEntry(dateKey: '2026-08-25', checkIn: DateTime(2026, 8, 25, 10)),
          at,
        ),
        kSettingsRecordId: settingsToRecord(const Settings(), at),
      };

      expect(
        daysFromLog(log).map((d) => d.dateKey),
        <String>['2026-08-25', '2026-08-26'],
      );
    });

    test('is empty for an empty log', () {
      expect(daysFromLog(const <String, Record>{}), isEmpty);
    });
  });

  group('settingsFromLog', () {
    test('reads the stored settings', () {
      const settings = Settings(requiredPerDay: Duration(hours: 6));
      final log = <String, Record>{
        kSettingsRecordId: settingsToRecord(settings, later),
      };

      expect(settingsFromLog(log).requiredPerDay, const Duration(hours: 6));
    });

    test('is defaults when the log holds none', () {
      expect(
        settingsFromLog(const <String, Record>{}).requiredPerDay,
        const Duration(hours: 8),
      );
    });

    test('is defaults when the settings record is tombstoned', () {
      final log = <String, Record>{
        kSettingsRecordId: Record(
          id: kSettingsRecordId,
          fields: settingsToRecord(const Settings(), at).fields,
          deleted: true,
        ),
      };

      expect(
        settingsFromLog(log).requiredPerDay,
        const Duration(hours: 8),
      );
    });
  });
}
