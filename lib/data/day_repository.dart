/// Persistence boundary for days and settings.
library;

import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/settings.dart';

/// Stores the recorded days and the user's settings.
///
/// An interface rather than a concrete class so widget tests can inject a
/// fake, and so a second backend (a desktop build, say) stays cheap to add.
abstract class DayRepository {
  /// Every recorded day, ascending by date key.
  Future<List<DayEntry>> loadDays();

  /// Replaces the stored day with the same `dateKey`, or appends it.
  Future<void> saveDay(DayEntry entry);

  /// Removes the day keyed by [dateKey]. A missing key is not an error.
  Future<void> deleteDay(String dateKey);

  /// The stored settings, or defaults when nothing has been saved.
  Future<Settings> loadSettings();

  /// Persists [settings].
  Future<void> saveSettings(Settings settings);
}

/// Returns [days] with [entry] replacing any same-day record, sorted by date.
///
/// Shared by every backend so "one entry per day" and the ordering guarantee
/// cannot drift between implementations.
List<DayEntry> upsertDay(List<DayEntry> days, DayEntry entry) {
  final merged = <DayEntry>[
    for (final day in days)
      if (day.dateKey != entry.dateKey) day,
    entry,
  ]..sort((a, b) => a.dateKey.compareTo(b.dateKey));
  return merged;
}
