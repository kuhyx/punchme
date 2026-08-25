/// User-configurable work expectations.
library;

/// How much work is expected, and on which days.
class Settings {
  /// Creates settings; defaults are a conventional 8h Mon-Fri.
  const Settings({
    this.requiredPerDay = const Duration(hours: 8),
    this.workingWeekdays = defaultWorkingWeekdays,
    this.freeDays = const <String>{},
  });

  /// Rebuilds settings from a [json] map, falling back to defaults per field.
  ///
  /// Tolerant by design: a settings file that has lost a field should leave
  /// the app usable rather than refuse to start.
  factory Settings.fromJson(Map<String, dynamic> json) {
    final minutes = json['requiredMinutesPerDay'];
    final weekdays = json['workingWeekdays'];
    final free = json['freeDays'];
    return Settings(
      requiredPerDay: minutes is int
          ? Duration(minutes: minutes)
          : const Duration(hours: 8),
      workingWeekdays: weekdays is List
          ? weekdays.whereType<int>().toSet()
          : defaultWorkingWeekdays,
      freeDays: free is List
          ? free.whereType<String>().toSet()
          : const <String>{},
    );
  }

  /// Monday through Friday, using `DateTime`'s weekday numbering.
  static const Set<int> defaultWorkingWeekdays = <int>{
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  };

  /// Hours owed on each working day.
  final Duration requiredPerDay;

  /// Which weekdays are working days (`DateTime.monday`..`DateTime.sunday`).
  final Set<int> workingWeekdays;

  /// Date keys (`YYYY-MM-DD`) that are off regardless of weekday.
  ///
  /// Keys rather than `DateTime`s: exact-instant equality would make a value
  /// carrying a time component miss the lookup.
  final Set<String> freeDays;

  /// This settings object with the given fields replaced.
  Settings copyWith({
    Duration? requiredPerDay,
    Set<int>? workingWeekdays,
    Set<String>? freeDays,
  }) => Settings(
    requiredPerDay: requiredPerDay ?? this.requiredPerDay,
    workingWeekdays: workingWeekdays ?? this.workingWeekdays,
    freeDays: freeDays ?? this.freeDays,
  );

  /// These settings as a JSON-encodable map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'requiredMinutesPerDay': requiredPerDay.inMinutes,
    // Sorted so the on-disk file is stable across writes.
    'workingWeekdays': workingWeekdays.toList()..sort(),
    'freeDays': freeDays.toList()..sort(),
  };
}
