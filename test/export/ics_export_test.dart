import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/export/ics_export.dart';
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
  final generatedAt = DateTime.utc(2026, 8, 25, 12);

  group('document shape', () {
    test('wraps events in a VCALENDAR', () {
      final ics = toIcs(<DayEntry>[
        closed('2026-08-25'),
      ], generatedAt: generatedAt);
      expect(ics, startsWith('BEGIN:VCALENDAR'));
      expect(ics.trimRight(), endsWith('END:VCALENDAR'));
      expect(ics, contains('VERSION:2.0'));
      expect(ics, contains('PRODID:-//kuhy//punchme//EN'));
    });

    test('emits one VEVENT per closed day', () {
      final ics = toIcs(
        <DayEntry>[closed('2026-08-24'), closed('2026-08-25')],
        generatedAt: generatedAt,
      );
      expect('BEGIN:VEVENT'.allMatches(ics), hasLength(2));
      expect('END:VEVENT'.allMatches(ics), hasLength(2));
    });

    test('an empty history still yields a valid empty calendar', () {
      final ics = toIcs(const <DayEntry>[], generatedAt: generatedAt);
      expect(ics, contains('BEGIN:VCALENDAR'));
      expect(ics, isNot(contains('BEGIN:VEVENT')));
    });

    test('skips an open day rather than inventing an end time', () {
      final open = DayEntry(
        dateKey: '2026-08-25',
        checkIn: DateTime(2026, 8, 25, 9),
      );
      final ics = toIcs(<DayEntry>[open], generatedAt: generatedAt);
      expect(ics, isNot(contains('BEGIN:VEVENT')));
    });
  });

  group('RFC 5545 conformance', () {
    test('every line ends with CRLF, not a bare LF', () {
      final ics = toIcs(<DayEntry>[
        closed('2026-08-25'),
      ], generatedAt: generatedAt);
      expect(ics, contains(crlf));
      // No LF may appear that is not preceded by a CR.
      for (var i = 0; i < ics.length; i++) {
        if (ics[i] == '\n') {
          expect(
            i > 0 && ics[i - 1] == '\r',
            isTrue,
            reason: 'bare LF at index $i',
          );
        }
      }
    });

    test('no unfolded line exceeds 75 octets', () {
      final ics = toIcs(
        <DayEntry>[closed('2026-08-25')],
        generatedAt: generatedAt,
      );
      for (final line in ics.split(crlf)) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75), reason: line);
      }
    });

    test('timestamps are UTC with a trailing Z', () {
      final ics = toIcs(<DayEntry>[
        closed('2026-08-25'),
      ], generatedAt: generatedAt);
      expect(ics, contains(RegExp(r'DTSTART:\d{8}T\d{6}Z')));
      expect(ics, contains(RegExp(r'DTEND:\d{8}T\d{6}Z')));
      expect(ics, contains('DTSTAMP:20260825T120000Z'));
    });
  });

  group('UID stability', () {
    test('is derived from the date, so re-import updates not duplicates', () {
      expect(uidFor(closed('2026-08-25')), '2026-08-25@$uidDomain');
    });

    test('is unchanged when the times are edited', () {
      final original = closed('2026-08-25');
      final edited = original.edited(checkOut: DateTime(2026, 8, 25, 19));
      expect(uidFor(edited), uidFor(original));
    });

    test('two exports of the same history are byte-identical', () {
      final days = <DayEntry>[closed('2026-08-24'), closed('2026-08-25')];
      expect(
        toIcs(days, generatedAt: generatedAt),
        toIcs(days, generatedAt: generatedAt),
      );
    });

    test('differs between days', () {
      expect(uidFor(closed('2026-08-24')), isNot(uidFor(closed('2026-08-25'))));
    });
  });

  group('escapeText', () {
    test('escapes the RFC-reserved characters', () {
      expect(escapeText(r'a\b'), r'a\\b');
      expect(escapeText('a;b'), r'a\;b');
      expect(escapeText('a,b'), r'a\,b');
      expect(escapeText('a\nb'), r'a\nb');
    });

    test('leaves ordinary text alone', () {
      expect(escapeText('Work'), 'Work');
    });
  });

  group('foldLine', () {
    test('leaves a short line untouched', () {
      expect(foldLine('SUMMARY:Work'), 'SUMMARY:Work');
    });

    test('a line of exactly 75 octets is not folded', () {
      final line = 'A' * 75;
      expect(foldLine(line), line);
    });

    test('folds a long line with a leading-space continuation', () {
      final folded = foldLine('B' * 200);
      expect(folded, contains('$crlf '));
      for (final part in folded.split(crlf)) {
        expect(utf8.encode(part).length, lessThanOrEqualTo(75));
      }
    });

    test('unfolding restores the original line', () {
      final original = 'C' * 300;
      final unfolded = foldLine(original).replaceAll('$crlf ', '');
      expect(unfolded, original);
    });

    test('never splits a multi-byte character across a fold', () {
      // Each 'ą' is two octets; a naive character-count fold would split one.
      final original = 'SUMMARY:${'ą' * 100}';
      final folded = foldLine(original);
      for (final part in folded.split(crlf)) {
        expect(utf8.encode(part).length, lessThanOrEqualTo(75));
      }
      expect(folded.replaceAll('$crlf ', ''), original);
    });
  });
}
