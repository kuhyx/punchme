import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/export/csv_export.dart';
import 'package:punchme/models/day_entry.dart';

DayEntry closed(String key, {int hours = 8}) {
  final checkIn = DateTime.parse('${key}T09:00:00');
  return DayEntry(
    dateKey: key,
    checkIn: checkIn,
    checkOut: checkIn.add(Duration(hours: hours)),
  );
}

void main() {
  group('toCsv', () {
    test('starts with the header row', () {
      final csv = toCsv(<DayEntry>[closed('2026-08-25')]);
      expect(csv.split('\n').first, 'date,check_in,check_out,hours');
    });

    test('writes one row per day and a trailing newline', () {
      final csv = toCsv(<DayEntry>[closed('2026-08-24'), closed('2026-08-25')]);
      expect(csv, endsWith('\n'));
      expect(csv.trimRight().split('\n'), hasLength(3)); // header + 2
    });

    test('renders times as HH:MM and hours as decimals', () {
      final csv = toCsv(<DayEntry>[closed('2026-08-25')]);
      expect(csv, contains('2026-08-25,09:00,17:00,8.00'));
    });

    test('rounds a part-hour day to two decimal places', () {
      final checkIn = DateTime(2026, 8, 25, 9);
      final day = DayEntry(
        dateKey: '2026-08-25',
        checkIn: checkIn,
        checkOut: checkIn.add(const Duration(hours: 7, minutes: 30)),
      );
      expect(toCsv(<DayEntry>[day]), contains(',7.50'));
    });

    test('leaves check-out and hours empty for an open day', () {
      final open = DayEntry(
        dateKey: '2026-08-25',
        checkIn: DateTime(2026, 8, 25, 9),
      );
      expect(toCsv(<DayEntry>[open]), contains('2026-08-25,09:00,,\n'));
    });

    test('sorts rows by date regardless of input order', () {
      final csv = toCsv(<DayEntry>[closed('2026-08-26'), closed('2026-08-24')]);
      expect(csv.indexOf('2026-08-24'), lessThan(csv.indexOf('2026-08-26')));
    });

    test('an empty history is just the header', () {
      expect(toCsv(const <DayEntry>[]), 'date,check_in,check_out,hours\n');
    });

    test('an overnight day reports its real length, not a negative', () {
      final night = DayEntry(
        dateKey: '2026-08-24',
        checkIn: DateTime(2026, 8, 24, 22),
        checkOut: DateTime(2026, 8, 25, 2),
      );
      expect(toCsv(<DayEntry>[night]), contains('2026-08-24,22:00,02:00,4.00'));
    });

    test('zero-pads single-digit hours and minutes', () {
      final day = DayEntry(
        dateKey: '2026-08-25',
        checkIn: DateTime(2026, 8, 25, 9, 5),
        checkOut: DateTime(2026, 8, 25, 17, 8),
      );
      expect(toCsv(<DayEntry>[day]), contains(',09:05,17:08,'));
    });
  });

  group('decimalHours', () {
    test('formats whole and part hours to two places', () {
      expect(decimalHours(const Duration(hours: 8)), '8.00');
      expect(decimalHours(const Duration(hours: 7, minutes: 30)), '7.50');
      expect(decimalHours(Duration.zero), '0.00');
      expect(decimalHours(const Duration(minutes: 20)), '0.33');
    });
  });

  group('csvHeader', () {
    test('names the four columns in order', () {
      expect(csvHeader, <String>['date', 'check_in', 'check_out', 'hours']);
    });
  });

  group('escaping', () {
    test('quotes and doubles a value containing a quote', () {
      // The date key is machine-generated, so drive escaping through a
      // hand-built entry whose key contains the reserved characters.
      final day = DayEntry(
        dateKey: 'a"b,c',
        checkIn: DateTime(2026, 8, 25, 9),
        checkOut: DateTime(2026, 8, 25, 17),
      );
      expect(toCsv(<DayEntry>[day]), contains('"a""b,c"'));
    });

    test('quotes a value containing a comma', () {
      final day = DayEntry(
        dateKey: 'x,y',
        checkIn: DateTime(2026, 8, 25, 9),
        checkOut: DateTime(2026, 8, 25, 17),
      );
      expect(toCsv(<DayEntry>[day]), contains('"x,y"'));
    });

    test('leaves an ordinary date key unquoted', () {
      expect(toCsv(<DayEntry>[closed('2026-08-25')]), contains('2026-08-25,'));
    });
  });
}
