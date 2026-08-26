/// A single day box in the free-days calendar.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// One day in the free-days calendar.
///
/// The cell is deliberately dumb: it renders the state it is handed and calls
/// [onTap] when tapped. Deciding *which* state a date is in, and whether a tap
/// means "mark" or "unmark", belongs to the calendar above it.
class FreeDayCell extends StatelessWidget {
  /// Creates a cell for [day] of the month.
  const FreeDayCell({
    required this.day,
    required this.isFree,
    required this.isWorkingWeekday,
    required this.onTap,
    super.key,
  });

  /// The day of the month, as shown in the box.
  final int day;

  /// Whether this date is currently a free day.
  final bool isFree;

  /// Whether this date's weekday is a working day.
  final bool isWorkingWeekday;

  /// Called when the cell is tapped, or null when the cell is inert.
  ///
  /// Null exactly when the date is neither a working day nor already free:
  /// there is nothing a tap there could mean.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // A free day on a weekday that is no longer worked keeps its marker, but
    // faded: the record survives, and the user can still tap it away.
    final isStale = isFree && !isWorkingWeekday;
    final foreground = isFree
        ? colors.onPrimary
        : isWorkingWeekday
        ? colors.onSurface
        : colors.onSurface.withValues(alpha: 0.38);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isFree
              ? colors.primary.withValues(alpha: isStale ? 0.38 : 1)
              : null,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          '$day',
          style: TextStyle(
            color: foreground,
            fontSize: AppTextSize.label,
            fontWeight: isFree ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
