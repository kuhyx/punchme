/// iCalendar (RFC 5545) export of recorded days.
library;

import 'dart:convert';

import 'package:punchme/models/day_entry.dart';

/// Line terminator required by RFC 5545. Not a bare `\n`.
const String crlf = '\r\n';

/// Domain used to build event UIDs. Not resolved; RFC 5545 just wants a
/// globally-unique, stable string.
const String uidDomain = 'punchme.kuhy';

/// Escapes [text] for an iCalendar TEXT value (RFC 5545 s3.3.11).
String escapeText(String text) => text
    .replaceAll(r'\', r'\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll('\n', r'\n');

/// Folds [line] to 75 octets per RFC 5545 s3.1, continuations led by a space.
///
/// Measured in octets, not characters: a multi-byte character must not be
/// split across a fold, or the file is malformed.
String foldLine(String line) {
  if (utf8.encode(line).length <= 75) {
    return line;
  }
  final buffer = StringBuffer();
  final runes = line.runes.toList();
  var index = 0;
  var limit = 75;
  while (index < runes.length) {
    var take = 0;
    var octets = 0;
    while (index + take < runes.length) {
      final size = utf8.encode(String.fromCharCode(runes[index + take])).length;
      if (octets + size > limit) {
        break;
      }
      octets += size;
      take++;
    }
    if (buffer.isNotEmpty) {
      buffer.write('$crlf ');
    }
    buffer.write(String.fromCharCodes(runes.sublist(index, index + take)));
    index += take;
    limit = 74; // a continuation line spends one octet on its leading space
  }
  return buffer.toString();
}

String _stamp(DateTime moment) {
  final utc = moment.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}${two(utc.month)}'
      '${two(utc.day)}T${two(utc.hour)}${two(utc.minute)}'
      '${two(utc.second)}Z';
}

/// The stable UID for [day]'s event.
///
/// Derived from the date, so re-exporting and re-importing updates the same
/// event instead of duplicating the entire history.
String uidFor(DayEntry day) => '${day.dateKey}@$uidDomain';

/// Renders the closed days among [days] as an iCalendar document.
///
/// Open days are skipped: an event needs an end, and inventing one would put
/// a wrong time in the user's calendar.
String toIcs(Iterable<DayEntry> days, {required DateTime generatedAt}) {
  final sorted = days.toList()..sort((a, b) => a.dateKey.compareTo(b.dateKey));
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//kuhy//punchme//EN',
    'CALSCALE:GREGORIAN',
  ];
  for (final day in sorted) {
    final checkOut = day.checkOut;
    if (checkOut == null) {
      continue;
    }
    lines.addAll(<String>[
      'BEGIN:VEVENT',
      'UID:${uidFor(day)}',
      'DTSTAMP:${_stamp(generatedAt)}',
      'DTSTART:${_stamp(day.checkIn)}',
      'DTEND:${_stamp(checkOut)}',
      'SUMMARY:${escapeText('Work')}',
      'END:VEVENT',
    ]);
  }
  lines.add('END:VCALENDAR');
  return '${lines.map(foldLine).join(crlf)}$crlf';
}
