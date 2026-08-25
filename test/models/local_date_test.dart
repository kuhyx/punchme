import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/models/local_date.dart';

void main() {
  group('localDateKey', () {
    test('zero-pads month and day', () {
      expect(localDateKey(DateTime(2026, 2, 3)), '2026-02-03');
    });

    test('uses local wall-clock date, so a late evening stays on its day', () {
      expect(localDateKey(DateTime(2026, 8, 25, 23, 59)), '2026-08-25');
      expect(localDateKey(DateTime(2026, 8, 26, 0, 1)), '2026-08-26');
    });
  });

  group('dateFromKey', () {
    test('round-trips with localDateKey', () {
      const key = '2026-08-25';
      expect(localDateKey(dateFromKey(key)), key);
    });

    test('rejects a malformed key', () {
      expect(() => dateFromKey('25-08-2026'), throwsFormatException);
      expect(() => dateFromKey('2026-8-5'), throwsFormatException);
      expect(() => dateFromKey('nonsense'), throwsFormatException);
    });

    test('rejects a date that does not exist rather than normalising it', () {
      // DateTime(2026, 2, 31) silently becomes 3 March; that must not pass.
      expect(() => dateFromKey('2026-02-31'), throwsFormatException);
      expect(() => dateFromKey('2026-13-01'), throwsFormatException);
    });
  });

  group('nextDay', () {
    test('advances one calendar day', () {
      expect(nextDay(DateTime(2026, 8, 25)), DateTime(2026, 8, 26));
    });

    test('rolls over month and year boundaries', () {
      expect(nextDay(DateTime(2026, 8, 31)), DateTime(2026, 9));
      expect(nextDay(DateTime(2026, 12, 31)), DateTime(2027));
    });

    test('handles a leap day', () {
      expect(nextDay(DateTime(2028, 2, 28)), DateTime(2028, 2, 29));
      expect(nextDay(DateTime(2028, 2, 29)), DateTime(2028, 3));
    });

    test('lands on local midnight even across a DST boundary', () {
      // Europe/Warsaw falls back on 2026-10-25. add(Duration(days: 1)) would
      // land at 23:00 on the 25th; the constructor normalises correctly.
      final stepped = nextDay(DateTime(2026, 10, 25));
      expect(stepped.hour, 0);
      expect(localDateKey(stepped), '2026-10-26');
    });
  });

  group('isoWithOffset / parseLocal', () {
    test('writes an offset that toIso8601String would have dropped', () {
      final text = isoWithOffset(DateTime(2026, 8, 25, 9, 3, 12));
      expect(text, matches(r'^2026-08-25T09:03:12\.000[+-]\d{2}:\d{2}$'));
    });

    test('round-trips back to the same wall-clock instant', () {
      final original = DateTime(2026, 8, 25, 9, 3, 12);
      expect(parseLocal(isoWithOffset(original)), original);
    });

    test('round-trips a winter timestamp too', () {
      final original = DateTime(2026, 12, 25, 9, 3, 12);
      expect(parseLocal(isoWithOffset(original)), original);
    });
  });
}
