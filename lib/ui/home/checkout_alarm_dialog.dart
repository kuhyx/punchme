/// Offering an alarm for today's target check-out time.
library;

import 'package:flutter/material.dart';
import 'package:punchme/logic/target_time.dart';
import 'package:punchme/ui/home/today_summary.dart';

/// Explains where today's [target] comes from, in one sentence.
///
/// Names the red card being repaid and how the shortfall is split, so the
/// number in the dialog can be checked against the statistics screen.
String targetReason(TargetToday target) {
  final behind = durationLabel(target.deficit);
  final reason = switch (target.level) {
    DeficitLevel.none => 'On track, nothing to make up.',
    DeficitLevel.week => '$behind behind this week — all today.',
    DeficitLevel.month =>
      '$behind behind this month — ${_spread(target.spreadOver)}.',
    DeficitLevel.year =>
      '$behind behind this year — ${_spread(target.spreadOver)}.',
  };
  if (!target.isCapped) {
    return reason;
  }
  return '$reason Capped at 23:59, '
      '${durationLabel(target.uncovered)} still uncovered.';
}

String _spread(int days) => days == 1 ? 'all today' : 'spread over $days days';

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
            targetReason(target),
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
