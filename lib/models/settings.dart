/// User-configurable work expectations.
library;

/// How much work is expected, and on which days.
class Settings {
  /// Creates settings; defaults are a conventional 8h Mon-Fri.
  const Settings({
    this.requiredPerDay = const Duration(hours: 8),
    this.workingWeekdays = defaultWorkingWeekdays,
    this.freeDays = const <String>{},
    this.workWifiSsids = const <String>{},
  });

  /// Rebuilds settings from a [json] map, falling back to defaults per field.
  ///
  /// Tolerant by design: a settings file that has lost a field should leave
  /// the app usable rather than refuse to start.
  factory Settings.fromJson(Map<String, dynamic> json) {
    final minutes = json['requiredMinutesPerDay'];
    final weekdays = json['workingWeekdays'];
    final free = json['freeDays'];
    final wifi = json['workWifiSsids'];
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
      workWifiSsids: wifi is List
          ? wifi.whereType<String>().toSet()
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

  /// SSIDs of Wi-Fi networks that count as "at work".
  ///
  /// The first connection to any of these on a given day auto-punches a
  /// check-in; the last time the phone is confirmed still connected to one
  /// becomes that day's check-out once the day rolls over. Empty means the
  /// feature is inert -- there is no separate on/off switch to drift out of
  /// sync with this.
  final Set<String> workWifiSsids;

  /// This settings object with the given fields replaced.
  Settings copyWith({
    Duration? requiredPerDay,
    Set<int>? workingWeekdays,
    Set<String>? freeDays,
    Set<String>? workWifiSsids,
  }) => Settings(
    requiredPerDay: requiredPerDay ?? this.requiredPerDay,
    workingWeekdays: workingWeekdays ?? this.workingWeekdays,
    freeDays: freeDays ?? this.freeDays,
    workWifiSsids: workWifiSsids ?? this.workWifiSsids,
  );

  /// These settings as a JSON-encodable map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'requiredMinutesPerDay': requiredPerDay.inMinutes,
    // Sorted so the on-disk file is stable across writes.
    'workingWeekdays': workingWeekdays.toList()..sort(),
    'freeDays': freeDays.toList()..sort(),
    'workWifiSsids': workWifiSsids.toList()..sort(),
  };
}
