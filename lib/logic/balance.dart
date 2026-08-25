/// Work-hours balance: how far ahead of, or behind, the expectation you are.
library;

import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/local_date.dart';
import 'package:punchme/models/settings.dart';

/// The worked-vs-expected picture for one period.
class Balance {
  /// Creates a balance summary.
  const Balance({
    required this.worked,
    required this.expected,
    required this.todaySoFar,
  });

  /// Time worked across the period's *completed* days.
  final Duration worked;

  /// Time owed across the period's *completed* working days.
  final Duration expected;

  /// Time on today's still-open session, excluded from [worked].
  ///
  /// Shown separately so a day in progress never reads as a deficit.
  final Duration todaySoFar;

  /// [worked] minus [expected]: positive is surplus, negative is a shortfall.
  Duration get difference => worked - expected;

  /// Whether the period is at or above its expectation.
  bool get isPositive => !difference.isNegative;
}

/// Whether [dateKey] is a day work is expected on, per [settings].
bool isWorkingDay(String dateKey, Settings settings) {
  if (settings.freeDays.contains(dateKey)) {
    return false;
  }
  return settings.workingWeekdays.contains(dateFromKey(dateKey).weekday);
}

/// Counts working days in `[from, to)` — i.e. today is excluded.
///
/// Expectation accrues only for days that are *over*. Counting today would
/// make Monday 09:00 read as a full day's shortfall the moment you arrive.
int completedWorkingDays({
  required DateTime from,
  required DateTime to,
  required Settings settings,
}) {
  var count = 0;
  var cursor = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day);
  while (cursor.isBefore(end)) {
    if (isWorkingDay(localDateKey(cursor), settings)) {
      count++;
    }
    cursor = nextDay(cursor);
  }
  return count;
}

/// Computes the balance over `[from, now]` for [entries].
///
/// Only days strictly before [now]'s date contribute to `worked`/`expected`;
/// today's open session is reported as [Balance.todaySoFar]. A *past* day with
/// no check-out contributes zero — a forgotten check-out must never be
/// extrapolated into hours that were not worked.
///
/// Expectation accrues no earlier than the first recorded day, so a fresh
/// install reads zero rather than owing every working day since 1 January.
Balance computeBalance({
  required Iterable<DayEntry> entries,
  required Settings settings,
  required DateTime from,
  required DateTime now,
}) {
  final todayKey = localDateKey(now);
  final fromKey = localDateKey(from);
  var worked = Duration.zero;
  var todaySoFar = Duration.zero;

  for (final entry in entries) {
    if (entry.dateKey.compareTo(fromKey) < 0) {
      continue;
    }
    if (entry.dateKey.compareTo(todayKey) > 0) {
      continue;
    }
    if (entry.dateKey == todayKey) {
      final closed = entry.worked;
      if (closed == null) {
        // Still running: shown separately so a day in progress never reads
        // as a deficit.
        todaySoFar = now.difference(entry.checkIn);
      } else {
        // Checked out: those hours are banked, so they count as worked and
        // today joins the expected days below. Leaving a finished day in
        // todaySoFar made the whole week read "0h 00m of 0h 00m".
        todaySoFar = closed;
        worked += closed;
      }
      continue;
    }
    // Past day: an open entry is a data gap, worth zero, not elapsed time.
    worked += entry.worked ?? Duration.zero;
  }

  final start = _effectiveStart(entries, from);
  // A day that has been checked out is over, so it is expected too: count up
  // to tomorrow rather than to today.
  final countTo = _todayIsClosed(entries, todayKey) ? nextDay(now) : now;
  final days = start == null
      ? 0
      : completedWorkingDays(from: start, to: countTo, settings: settings);
  return Balance(
    worked: worked,
    expected: settings.requiredPerDay * days,
    todaySoFar: todaySoFar,
  );
}

/// The later of [from] and the earliest recorded day, or null when nothing
/// has ever been recorded.
///
/// Without this, a brand-new install would report the whole year to date as a
/// deficit -- technically true, and useless.
DateTime? _effectiveStart(Iterable<DayEntry> entries, DateTime from) {
  String? earliest;
  for (final entry in entries) {
    if (earliest == null || entry.dateKey.compareTo(earliest) < 0) {
      earliest = entry.dateKey;
    }
  }
  if (earliest == null) {
    return null;
  }
  final first = dateFromKey(earliest);
  return first.isAfter(from) ? first : from;
}

/// Whether today's entry exists and has been checked out.
bool _todayIsClosed(Iterable<DayEntry> entries, String todayKey) {
  for (final entry in entries) {
    if (entry.dateKey == todayKey) {
      return !entry.isOpen;
    }
  }
  return false;
}
