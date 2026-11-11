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

/// A weekday drawn as a strip of seven dots with its own dot filled.
///
/// textgate: position in the week instead of a name. Weekend dots are
/// squares, so Saturday and Sunday read apart from the working days.
class WeekdayGlyph extends StatelessWidget {
  /// Creates the glyph for [weekday] (`DateTime.monday`..`DateTime.sunday`).
  const WeekdayGlyph(this.weekday, {this.color, super.key});

  /// The day, 1 = Monday.
  final int weekday;

  /// Tint; ambient icon colour when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? IconTheme.of(context).color ?? Colors.grey;
    return Semantics(
      container: true,
      label: weekdayLabels[weekday - 1],
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var d = DateTime.monday; d <= DateTime.sunday; d++)
            Container(
              key: d == weekday ? const Key('weekday-dot-on') : null,
              width: 4,
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 0.5),
              decoration: BoxDecoration(
                color: d == weekday ? tint : tint.withValues(alpha: 0.25),
                shape: d >= DateTime.saturday
                    ? BoxShape.rectangle
                    : BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

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
          label: WeekdayGlyph(weekday),
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
