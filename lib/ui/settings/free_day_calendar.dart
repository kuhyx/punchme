/// The month grid of the free-days calendar.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:punchme/models/local_date.dart';
import 'package:punchme/ui/settings/free_day_cell.dart';
import 'package:punchme/ui/settings/weekday_picker.dart';

/// Number of leading blank cells before the 1st of [month].
///
/// Monday-first, to match [weekdayLabels]: a month starting on Monday needs
/// none, one starting on Sunday needs six.
int leadingBlanks(DateTime month) =>
    DateTime(month.year, month.month).weekday - 1;

/// How many days [month] has.
///
/// Day zero of the following month is the last day of this one, which avoids
/// hand-written leap-year rules.
int daysInMonth(DateTime month) => DateTime(month.year, month.month + 1, 0).day;

/// A tappable month grid of free days.
class FreeDayCalendar extends StatelessWidget {
  /// Creates a grid over [month].
  const FreeDayCalendar({
    required this.month,
    required this.freeDays,
    required this.workingWeekdays,
    required this.onToggle,
    super.key,
  });

  /// The month on display; only its year and month are read.
  final DateTime month;

  /// Date keys (`YYYY-MM-DD`) currently marked free.
  final Set<String> freeDays;

  /// Which weekdays are working days (`DateTime.monday`..`DateTime.sunday`).
  final Set<int> workingWeekdays;

  /// Called with the date key of the tapped day.
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final blanks = leadingBlanks(month);
    final total = daysInMonth(month);
    return Column(
      children: <Widget>[
        // Single letters, not `weekdayLabels` in full: the picker directly
        // above already renders 'Mon'..'Sun', and a duplicate string would
        // make every find-by-text in the tests ambiguous.
        Row(
          children: <Widget>[
            for (final label in weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    label[0],
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: AppTextSize.caption,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        GridView.count(
          crossAxisCount: DateTime.daysPerWeek,
          shrinkWrap: true,
          // The field sits inside the settings ListView, which owns scrolling.
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.xs,
          crossAxisSpacing: AppSpacing.xs,
          children: <Widget>[
            for (var i = 0; i < blanks; i++) const SizedBox.shrink(),
            for (var day = 1; day <= total; day++) _cell(day),
          ],
        ),
      ],
    );
  }

  Widget _cell(int day) {
    final date = DateTime(month.year, month.month, day);
    final key = localDateKey(date);
    final isFree = freeDays.contains(key);
    final isWorkingWeekday = workingWeekdays.contains(date.weekday);
    return FreeDayCell(
      key: ValueKey<String>('free-day-$key'),
      day: day,
      isFree: isFree,
      isWorkingWeekday: isWorkingWeekday,
      // Inert only when the day is neither worked nor already free. A stale
      // free day stays tappable so it can be cleared without first
      // re-enabling its weekday.
      onTap: isWorkingWeekday || isFree ? () => onToggle(key) : null,
    );
  }
}
