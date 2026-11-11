/// Offering an alarm for today's target check-out time.
library;

import 'package:flutter/material.dart';
import 'package:punchme/logic/surplus.dart';
import 'package:punchme/logic/target_time.dart';
import 'package:punchme/ui/glyphs.dart';
import 'package:punchme/ui/home/today_summary.dart';

/// Explains where today's [target] comes from, in one sentence.
///
/// Names the red card being repaid and how the shortfall is split -- or, when
/// all are green, the card that limits the surplus and how it is spread -- so
/// the number in the dialog can be checked against the statistics screen.
String targetReason(TargetToday target) {
  final behind = durationLabel(target.deficit);
  final reason = switch (target.level) {
    DeficitLevel.none => _aheadReason(target),
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

String _aheadReason(TargetToday target) {
  final tightest = target.tightest;
  if (tightest == null) {
    return 'On track, nothing to make up.';
  }
  final reason =
      '${durationLabel(target.surplus)} ahead (tightest: ${tightest.name}) — '
      '${_spread(target.spreadOver)}.';
  if (!target.surplusCapped) {
    return reason;
  }
  return '$reason Capped at ${durationLabel(maxSurplusSlice)} off a day.';
}

/// [targetReason] in pictograms: trend arrow and amount, the card, how many
/// days it is spread over, and the cap when one bit.
class TargetReason extends StatelessWidget {
  /// Creates the reason row for [target].
  const TargetReason({required this.target, this.style, super.key});

  /// Today's computed target.
  final TargetToday target;

  /// Style of the numbers.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final horizon = switch (target.level) {
      DeficitLevel.none => target.tightest,
      DeficitLevel.week => Horizon.week,
      DeficitLevel.month => Horizon.month,
      DeficitLevel.year => Horizon.year,
    };
    final behind = target.level != DeficitLevel.none;
    final capped = behind ? target.isCapped : target.surplusCapped;
    final children = <Widget>[
      if (horizon == null)
        Icon(
          Icons.check,
          key: const Key('reason-on-track'),
          color: style?.color,
        )
      else ...<Widget>[
        IconValue(
          key: const Key('reason-amount'),
          icon: behind ? Icons.trending_down : Icons.trending_up,
          value: durationLabel(behind ? target.deficit : target.surplus),
          spoken: '',
          style: style,
        ),
        HorizonGlyph(horizon, style: style),
        IconValue(
          key: const Key('reason-spread'),
          icon: Icons.date_range,
          value: '${target.spreadOver}',
          spoken: '',
          style: style,
        ),
      ],
      if (capped)
        IconValue(
          key: const Key('reason-cap'),
          icon: Icons.vertical_align_top,
          value: durationLabel(behind ? target.uncovered : maxSurplusSlice),
          spoken: '',
          style: style,
        ),
    ];
    return Semantics(
      container: true,
      label: targetReason(target),
      excludeSemantics: true,
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    );
  }
}

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
      title: const Icon(
        Icons.check_circle_outline,
        key: Key('alarm-title'),
        semanticLabel: 'Checked in',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            container: true,
            label:
                'Work ${durationLabel(target.share)} today, '
                'until ${clockLabel(target.checkOutAt)}.',
            excludeSemantics: true,
            child: Wrap(
              spacing: 16,
              children: <Widget>[
                IconValue(
                  icon: Icons.work_outline,
                  value: durationLabel(target.share),
                  spoken: durationLabel(target.share),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 18,
                  ),
                ),
                IconValue(
                  icon: Icons.flag_outlined,
                  value: clockLabel(target.checkOutAt),
                  spoken: clockLabel(target.checkOutAt),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TargetReason(
            target: target,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      actions: <Widget>[
        IconButton(
          key: const Key('alarm-not-now'),
          icon: const Icon(Icons.close, semanticLabel: 'Not now'),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        FilledButton(
          key: const Key('alarm-set'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Icon(Icons.alarm_add, semanticLabel: 'Set alarm'),
        ),
      ],
    );
  }
}
