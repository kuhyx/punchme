/// Offering an alarm for today's target check-out time.
library;

import 'package:flutter/material.dart';
import 'package:punchme/logic/target_time.dart';
import 'package:punchme/ui/home/today_summary.dart';

/// Asks whether to set a phone alarm for the target check-out time.
class CheckOutAlarmDialog extends StatelessWidget {
  /// Creates the dialog for [target].
  const CheckOutAlarmDialog({required this.target, super.key});

  /// Today's computed target.
  final TargetToday target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Checked in'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Work ${durationLabel(target.share)} today, '
            'until ${clockLabel(target.checkOutAt)}.',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${durationLabel(target.remainingThisWeek)} left this week over '
            '${target.workingDaysLeft} '
            '${target.workingDaysLeft == 1 ? "day" : "days"}.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Set alarm'),
        ),
      ],
    );
  }
}
