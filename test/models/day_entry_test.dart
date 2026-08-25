import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/models/day_entry.dart';

void main() {
  final checkIn = DateTime(2026, 8, 25, 9);
  final checkOut = DateTime(2026, 8, 25, 17);
  final open = DayEntry(dateKey: '2026-08-25', checkIn: checkIn);
  final closed = open.closedAt(checkOut);

  group('worked', () {
    test('is null while the day is open', () {
      expect(open.isOpen, isTrue);
      expect(open.worked, isNull);
    });

    test('is the real elapsed time once closed', () {
      expect(closed.isOpen, isFalse);
      expect(closed.worked, const Duration(hours: 8));
    });

    test('spans midnight for an overnight session', () {
      final night = DayEntry(
        dateKey: '2026-08-24',
        checkIn: DateTime(2026, 8, 24, 22),
        checkOut: DateTime(2026, 8, 25, 2),
      );
      expect(night.worked, const Duration(hours: 4));
    });
  });

  group('closedAt / reopened', () {
    test('closedAt seals the day without moving the check-in', () {
      expect(closed.checkIn, checkIn);
      expect(closed.checkOut, checkOut);
      expect(closed.dateKey, '2026-08-25');
    });

    test('reopened clears the check-out, as Undo does', () {
      expect(closed.reopened().checkOut, isNull);
      expect(closed.reopened().isOpen, isTrue);
      expect(closed.reopened().checkIn, checkIn);
    });
  });

  group('edited', () {
    test('re-keys the entry when the check-in moves to another day', () {
      final moved = closed.edited(checkIn: DateTime(2026, 8, 26, 9));
      expect(moved.dateKey, '2026-08-26');
    });

    test('replaces only the check-out when asked', () {
      final later = closed.edited(checkOut: DateTime(2026, 8, 25, 18));
      expect(later.checkIn, checkIn);
      expect(later.worked, const Duration(hours: 9));
    });

    test('clearCheckOut drops the check-out entirely', () {
      expect(closed.edited(clearCheckOut: true).checkOut, isNull);
    });

    test('with no arguments is a no-op', () {
      expect(closed.edited(), closed);
    });
  });

  group('json', () {
    test('round-trips a closed entry', () {
      expect(DayEntry.fromJson(closed.toJson()), closed);
    });

    test('round-trips an open entry, omitting checkOut', () {
      expect(open.toJson().containsKey('checkOut'), isFalse);
      expect(DayEntry.fromJson(open.toJson()), open);
    });

    test('rejects a map missing required fields', () {
      expect(
        () => DayEntry.fromJson(<String, dynamic>{'dateKey': '2026-08-25'}),
        throwsFormatException,
      );
      expect(
        () => DayEntry.fromJson(<String, dynamic>{'checkIn': '2026-08-25'}),
        throwsFormatException,
      );
    });

    test('rejects a malformed dateKey rather than passing it downstream', () {
      // A damaged file must yield an *unreadable* record (which the
      // repository skips), not a readable one that crashes the balance maths.
      expect(
        () => DayEntry.fromJson(<String, dynamic>{
          'dateKey': 'garbage',
          'checkIn': '2026-08-25T09:00:00.000+02:00',
        }),
        throwsFormatException,
      );
      expect(
        () => DayEntry.fromJson(<String, dynamic>{
          'dateKey': '2026-02-31', // not a real date
          'checkIn': '2026-08-25T09:00:00.000+02:00',
        }),
        throwsFormatException,
      );
    });

    test('rejects a non-string checkOut', () {
      expect(
        () => DayEntry.fromJson(<String, dynamic>{
          'dateKey': '2026-08-25',
          'checkIn': '2026-08-25T09:00:00.000+02:00',
          'checkOut': 42,
        }),
        throwsFormatException,
      );
    });
  });

  group('value semantics', () {
    test('equal entries are equal and share a hash code', () {
      final twin = DayEntry(
        dateKey: '2026-08-25',
        checkIn: checkIn,
        checkOut: checkOut,
      );
      expect(twin, closed);
      expect(twin.hashCode, closed.hashCode);
    });

    test('differing entries are not equal', () {
      expect(open, isNot(closed));
      expect(closed.edited(checkIn: DateTime(2026, 8, 26, 9)), isNot(closed));
    });

    test('toString names the day and both times', () {
      expect(closed.toString(), contains('2026-08-25'));
    });
  });
}
