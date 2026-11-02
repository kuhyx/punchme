/// One month of days as a fixed grid, so History never scrolls.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/local_date.dart';
import 'package:punchme/ui/home/today_summary.dart';
import 'package:punchme/ui/settings/weekday_picker.dart';

/// Weeks run Monday to Sunday, as in the Statistics periods.
///
/// Rows share the height they are given, so a month of five or six weeks
/// always fits. A cell holds the day number and what was worked; the times
/// themselves are one tap away in the day editor.
class MonthGrid extends StatelessWidget {
  /// Creates the grid for the month containing [month].
  const MonthGrid({
    required this.month,
    required this.entries,
    required this.onTap,
    super.key,
  });

  /// Any moment in the month to draw.
  final DateTime month;

  /// Recorded days by date key.
  final Map<String, DayEntry> entries;

  /// Called with the entry of a tapped, recorded day.
  final ValueChanged<DayEntry> onTap;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final lead = first.weekday - DateTime.monday;
    final count = DateUtils.getDaysInMonth(month.year, month.month);
    final weeks = ((lead + count) / DateTime.daysPerWeek).ceil();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              for (final label in weekdayLabels)
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: muted,
                        fontSize: AppTextSize.label,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (var week = 0; week < weeks; week++)
            Expanded(
              child: Row(
                children: <Widget>[
                  for (var slot = 0; slot < DateTime.daysPerWeek; slot++)
                    Expanded(
                      child: _cellAt(
                        first,
                        week * DateTime.daysPerWeek + slot - lead,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// The cell [offset] days after [first], blank outside the month.
  Widget _cellAt(DateTime first, int offset) {
    final date = DateTime(first.year, first.month, 1 + offset);
    if (date.month != first.month) {
      return const SizedBox.shrink();
    }
    final key = localDateKey(date);
    final entry = entries[key];
    return _DayCell(
      key: ValueKey<String>('day-$key'),
      day: date.day,
      entry: entry,
      onTap: entry == null ? null : () => onTap(entry),
    );
  }
}

/// One day: its number, and its total or a flag for a missing check-out.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.entry,
    required this.onTap,
    super.key,
  });

  final int day;
  final DayEntry? entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final recorded = entry;
    final worked = recorded?.worked;
    final open = recorded != null && worked == null;
    final fill = open
        ? scheme.errorContainer
        : recorded == null
        ? Colors.transparent
        : scheme.surfaceContainerHighest;
    final ink = open ? scheme.onErrorContainer : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: onTap,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '$day',
                    style: TextStyle(
                      color: recorded == null ? scheme.onSurfaceVariant : ink,
                      fontSize: AppTextSize.body,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (recorded != null)
                    Text(
                      worked == null ? '—' : durationLabel(worked),
                      style: TextStyle(
                        color: open ? ink : scheme.primary,
                        fontSize: AppTextSize.label,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
