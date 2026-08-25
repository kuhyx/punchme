import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/logic/day_state.dart';
import 'package:punchme/models/day_entry.dart';

void main() {
  final now = DateTime(2026, 8, 25, 12);
  final today = DayEntry(
    dateKey: '2026-08-25',
    checkIn: DateTime(2026, 8, 25, 9),
  );
  final yesterday = DayEntry(
    dateKey: '2026-08-24',
    checkIn: DateTime(2026, 8, 24, 9),
    checkOut: DateTime(2026, 8, 24, 17),
  );

  group('entryForDay', () {
    test('finds today among several days', () {
      expect(entryForDay(<DayEntry>[yesterday, today], now), today);
    });

    test('is null when today has no entry', () {
      expect(entryForDay(<DayEntry>[yesterday], now), isNull);
    });

    test('is null for an empty history', () {
      expect(entryForDay(const <DayEntry>[], now), isNull);
    });

    test("does not claim yesterday's overnight session as today's", () {
      final overnight = DayEntry(
        dateKey: '2026-08-24',
        checkIn: DateTime(2026, 8, 24, 22),
        checkOut: DateTime(2026, 8, 25, 2),
      );
      expect(entryForDay(<DayEntry>[overnight], now), isNull);
    });
  });

  group('stateFor', () {
    test('no entry means the button checks in', () {
      expect(stateFor(null), DayState.readyToCheckIn);
    });

    test('an open entry means the button checks out', () {
      expect(stateFor(today), DayState.checkedIn);
    });

    test('a closed entry seals the day', () {
      expect(
        stateFor(today.closedAt(DateTime(2026, 8, 25, 17))),
        DayState.checkedOut,
      );
    });

    test('Undo returns a sealed day to the checked-in state', () {
      final sealed = today.closedAt(DateTime(2026, 8, 25, 17));
      expect(stateFor(sealed.reopened()), DayState.checkedIn);
    });
  });
}
