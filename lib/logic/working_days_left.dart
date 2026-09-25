/// Counting the working days still ahead in a period.
library;

import 'package:punchme/logic/balance.dart';
import 'package:punchme/logic/periods.dart';
import 'package:punchme/models/local_date.dart';
import 'package:punchme/models/settings.dart';

/// Counts working days from [now]'s date up to (excluding) [until].
///
/// Today counts when it is a working day, because the point of the split is
/// to decide how long *today* should be.
int workingDaysLeft({
  required DateTime now,
  required DateTime until,
  required Settings settings,
}) {
  var count = 0;
  var cursor = DateTime(now.year, now.month, now.day);
  while (cursor.isBefore(until)) {
    if (isWorkingDay(localDateKey(cursor), settings)) {
      count++;
    }
    cursor = nextDay(cursor);
  }
  return count;
}

/// Working days from [now]'s date to the end of its week, today included.
int workingDaysLeftInWeek({
  required DateTime now,
  required Settings settings,
}) => workingDaysLeft(now: now, until: endOfWeek(now), settings: settings);

/// Working days from [now]'s date to the end of its month, today included.
int workingDaysLeftInMonth({
  required DateTime now,
  required Settings settings,
}) => workingDaysLeft(now: now, until: endOfMonth(now), settings: settings);

/// Working days from [now]'s date to the end of its year, today included.
int workingDaysLeftInYear({
  required DateTime now,
  required Settings settings,
}) => workingDaysLeft(now: now, until: endOfYear(now), settings: settings);
