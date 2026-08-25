/// Today's times and running total, shown under the button.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:punchme/models/day_entry.dart';

/// Formats [moment] as `HH:MM`.
String clockLabel(DateTime moment) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(moment.hour)}:${two(moment.minute)}';
}

/// Formats [duration] as `Nh MMm`.
String durationLabel(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).abs();
  return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
}

/// Today's check-in, check-out and total, plus the Undo affordance.
class TodaySummary extends StatelessWidget {
  /// Creates the summary for [entry] (today's entry, or null).
  const TodaySummary({
    required this.entry,
    required this.now,
    this.onUndo,
    super.key,
  });

  /// Today's entry, or null when nothing is recorded yet.
  final DayEntry? entry;

  /// The clock, for the running total of an open day.
  final DateTime Function() now;

  /// Reopens a sealed day. Null unless the day is sealed.
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = entry;
    if (current == null) {
      return Text(
        'Not checked in today',
        style: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: AppTextSize.body,
        ),
      );
    }

    final total = current.worked ?? now().difference(current.checkIn);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              current.checkOut == null
                  ? 'In ${clockLabel(current.checkIn)}'
                  : 'In ${clockLabel(current.checkIn)} · '
                        'Out ${clockLabel(current.checkOut!)}',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: AppTextSize.body,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              durationLabel(total),
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: AppTextSize.subtitle,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (onUndo != null)
          TextButton(
            onPressed: onUndo,
            child: const Text('Undo'),
          ),
      ],
    );
  }
}
