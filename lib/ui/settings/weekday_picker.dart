/// Working-weekday selector.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Short labels for `DateTime.monday`..`DateTime.sunday`.
const List<String> weekdayLabels = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

/// Lets the user pick which weekdays are working days.
class WeekdayPicker extends StatelessWidget {
  /// Creates a picker over [selected].
  const WeekdayPicker({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  /// Currently-selected weekdays (`DateTime.monday`..`DateTime.sunday`).
  final Set<int> selected;

  /// Called with the new selection when a day is toggled.
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    children: <Widget>[
      for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
        FilterChip(
          label: Text(weekdayLabels[weekday - 1]),
          selected: selected.contains(weekday),
          onSelected: (isOn) => onChanged(<int>{
            for (final day in selected)
              if (day != weekday) day,
            if (isOn) weekday,
          }),
        ),
    ],
  );
}
