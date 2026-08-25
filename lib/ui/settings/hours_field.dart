/// Required-hours-per-day stepper.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:punchme/ui/home/today_summary.dart';

/// The smallest adjustment the stepper makes.
const Duration hoursStep = Duration(minutes: 30);

/// The most hours a day can require.
const Duration maxRequiredPerDay = Duration(hours: 24);

/// Adjusts the hours owed on each working day.
class HoursField extends StatelessWidget {
  /// Creates a stepper over [value].
  const HoursField({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// The current required duration.
  final Duration value;

  /// Called with the new duration when the user steps up or down.
  final ValueChanged<Duration> onChanged;

  @override
  Widget build(BuildContext context) {
    final canDecrease = value > hoursStep;
    final canIncrease = value < maxRequiredPerDay;
    return Row(
      children: <Widget>[
        IconButton(
          onPressed: canDecrease ? () => onChanged(value - hoursStep) : null,
          icon: const Icon(Icons.remove),
          tooltip: 'Less',
        ),
        Expanded(
          child: Text(
            durationLabel(value),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTextSize.subtitle,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        IconButton(
          onPressed: canIncrease ? () => onChanged(value + hoursStep) : null,
          icon: const Icon(Icons.add),
          tooltip: 'More',
        ),
      ],
    );
  }
}
