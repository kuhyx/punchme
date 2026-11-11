/// Today's times and running total, shown under the button.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:punchme/logic/target_time.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/ui/glyphs.dart';

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
    this.target,
    this.onUndo,
    super.key,
  });

  /// Today's entry, or null when nothing is recorded yet.
  final DayEntry? entry;

  /// The clock, for the running total of an open day.
  final DateTime Function() now;

  /// Today's target check-out, while the day is running. Null otherwise.
  final TargetToday? target;

  /// Reopens a sealed day. Null unless the day is sealed.
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = entry;
    if (current == null) {
      // The button above already offers check-in; nothing to add.
      return const SizedBox.shrink();
    }

    final total = current.worked ?? now().difference(current.checkIn);
    final body = TextStyle(
      color: theme.colorScheme.onSurface,
      fontSize: AppTextSize.body,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        // Flexible: on a narrow phone the line wraps rather than overflowing
        // the Undo button beside it.
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: AppSpacing.md,
                children: <Widget>[
                  IconValue(
                    key: const Key('summary-in'),
                    icon: Icons.login,
                    value: clockLabel(current.checkIn),
                    spoken: 'In ${clockLabel(current.checkIn)}',
                    style: body,
                  ),
                  if (current.checkOut != null)
                    IconValue(
                      key: const Key('summary-out'),
                      icon: Icons.logout,
                      value: clockLabel(current.checkOut!),
                      spoken: 'Out ${clockLabel(current.checkOut!)}',
                      style: body,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              if (target != null)
                IconValue(
                  key: const Key('summary-target'),
                  icon: Icons.flag_outlined,
                  value:
                      '${clockLabel(target!.checkOutAt)} '
                      '(${durationLabel(target!.share)})',
                  spoken:
                      'Until ${clockLabel(target!.checkOutAt)} '
                      '(${durationLabel(target!.share)})',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: AppTextSize.label,
                  ),
                ),
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
        ),
        if (onUndo != null)
          TextButton(
            key: const Key('undo'),
            onPressed: onUndo,
            child: const Icon(Icons.undo, semanticLabel: 'Undo'),
          ),
      ],
    );
  }
}
