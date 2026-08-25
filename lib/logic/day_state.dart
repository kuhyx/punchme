/// The home button's state, derived from today's entry.
library;

import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/local_date.dart';

/// What the big button should currently offer.
enum DayState {
  /// Nothing recorded today: the button checks in.
  readyToCheckIn,

  /// Checked in, still running: the button checks out.
  checkedIn,

  /// Both times recorded: the day is sealed, and only Undo reopens it.
  checkedOut,
}

/// Returns today's entry from [entries], or null when there is none.
///
/// "Today" is the check-in date, so an overnight session started yesterday is
/// deliberately *not* today's entry — it stays filed under the day it began.
DayEntry? entryForDay(Iterable<DayEntry> entries, DateTime now) {
  final key = localDateKey(now);
  for (final entry in entries) {
    if (entry.dateKey == key) {
      return entry;
    }
  }
  return null;
}

/// Derives the button state from [entry] (today's entry, or null).
DayState stateFor(DayEntry? entry) {
  if (entry == null) {
    return DayState.readyToCheckIn;
  }
  return entry.isOpen ? DayState.checkedIn : DayState.checkedOut;
}
