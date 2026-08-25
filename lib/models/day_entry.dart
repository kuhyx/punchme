/// A single workday's check-in / check-out pair.
library;

import 'package:flutter/foundation.dart';
import 'package:punchme/models/local_date.dart';

/// One workday: exactly one check-in and at most one check-out.
///
/// The day is keyed by the *check-in* date, so an overnight session
/// (in 22:00, out 02:00) belongs wholly to the day it started on.
@immutable
class DayEntry {
  /// Creates an entry for [dateKey], started at [checkIn].
  const DayEntry({
    required this.dateKey,
    required this.checkIn,
    this.checkOut,
  });

  /// Rebuilds an entry from its [json] map.
  ///
  /// Throws [FormatException] when a required field is missing or malformed.
  factory DayEntry.fromJson(Map<String, dynamic> json) {
    final dateKey = json['dateKey'];
    final checkIn = json['checkIn'];
    if (dateKey is! String || checkIn is! String) {
      throw const FormatException('DayEntry needs dateKey and checkIn');
    }
    final checkOut = json['checkOut'];
    if (checkOut != null && checkOut is! String) {
      throw const FormatException('DayEntry.checkOut must be a string');
    }
    // Reject a malformed key here rather than letting it reach the balance
    // maths: the repository tolerates a damaged file by skipping unreadable
    // records, so a bad key must be *unreadable*, not merely wrong. Without
    // this it parses fine and then throws inside computeBalance, taking out
    // the statistics screen.
    dateFromKey(dateKey);
    return DayEntry(
      dateKey: dateKey,
      checkIn: parseLocal(checkIn),
      checkOut: checkOut == null ? null : parseLocal(checkOut as String),
    );
  }

  /// The check-in calendar date, `YYYY-MM-DD`. Owns the whole session.
  final String dateKey;

  /// When the day was started.
  final DateTime checkIn;

  /// When the day was ended, or null while the day is still open.
  final DateTime? checkOut;

  /// Whether the day is still running (checked in, not yet out).
  bool get isOpen => checkOut == null;

  /// How long was worked, or null while the day is still open.
  ///
  /// Deliberately null rather than "now minus check-in": for a *past* day an
  /// elapsed-time answer would report a forgotten check-out as days of work.
  /// Callers decide what an open day means in their context.
  Duration? get worked => checkOut?.difference(checkIn);

  /// This entry with [checkOut] set, sealing the day.
  DayEntry closedAt(DateTime moment) => DayEntry(
    dateKey: dateKey,
    checkIn: checkIn,
    checkOut: moment,
  );

  /// This entry with the check-out cleared, reopening the day.
  DayEntry reopened() => DayEntry(dateKey: dateKey, checkIn: checkIn);

  /// This entry with [checkIn] and/or [checkOut] replaced.
  ///
  /// Re-keys the entry to the new check-in date, so correcting a time never
  /// leaves the day filed under a date it no longer starts on. Pass
  /// [clearCheckOut] to drop the check-out rather than replace it.
  DayEntry edited({
    DateTime? checkIn,
    DateTime? checkOut,
    bool clearCheckOut = false,
  }) {
    final newCheckIn = checkIn ?? this.checkIn;
    return DayEntry(
      dateKey: localDateKey(newCheckIn),
      checkIn: newCheckIn,
      checkOut: clearCheckOut ? null : checkOut ?? this.checkOut,
    );
  }

  /// This entry as a JSON-encodable map.
  ///
  /// Timestamps keep their UTC offset, so a DST day (23 or 25 hours long)
  /// still yields the right duration when read back.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'dateKey': dateKey,
    'checkIn': isoWithOffset(checkIn),
    if (checkOut != null) 'checkOut': isoWithOffset(checkOut!),
  };

  @override
  bool operator ==(Object other) =>
      other is DayEntry &&
      other.dateKey == dateKey &&
      other.checkIn == checkIn &&
      other.checkOut == checkOut;

  @override
  int get hashCode => Object.hash(dateKey, checkIn, checkOut);

  @override
  String toString() => 'DayEntry($dateKey, $checkIn -> $checkOut)';
}
