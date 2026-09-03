import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/local_date.dart';

/// A closed day on [key] that lasted [length], checked in at [startHour].
DayEntry logged(String key, Duration length, {int startHour = 9}) {
  final checkIn = DateTime.parse(key).add(Duration(hours: startHour));
  return DayEntry(
    dateKey: key,
    checkIn: checkIn,
    checkOut: checkIn.add(length),
  );
}

/// Five closed days, Monday [mondayKey] to Friday, each lasting [length].
List<DayEntry> week(String mondayKey, Duration length) {
  var day = dateFromKey(mondayKey);
  final entries = <DayEntry>[];
  for (var offset = 0; offset < 5; offset++) {
    entries.add(logged(localDateKey(day), length));
    day = nextDay(day);
  }
  return entries;
}
