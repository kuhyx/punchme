/// Free-day calendar: dates that are off regardless of weekday.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:punchme/models/local_date.dart';

/// Lists the chosen free days and adds new ones from a date picker.
class FreeDaysField extends StatelessWidget {
  /// Creates a field over [freeDays], a set of `YYYY-MM-DD` keys.
  const FreeDaysField({
    required this.freeDays,
    required this.onChanged,
    this.now = DateTime.now,
    super.key,
  });

  /// Currently-chosen free days, as date keys.
  final Set<String> freeDays;

  /// Called with the new set when a day is added or removed.
  final ValueChanged<Set<String>> onChanged;

  /// The clock, used to seed and bound the date picker.
  final DateTime Function() now;

  Future<void> _add(BuildContext context) async {
    final today = now();
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateTime(today.year - 5),
      lastDate: DateTime(today.year + 5),
    );
    if (picked == null) {
      return;
    }
    onChanged(<String>{...freeDays, localDateKey(picked)});
  }

  @override
  Widget build(BuildContext context) {
    final sorted = freeDays.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (sorted.isEmpty)
          Text(
            'No free days yet',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: AppTextSize.label,
            ),
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final key in sorted)
                InputChip(
                  label: Text(key),
                  onDeleted: () => onChanged(<String>{
                    for (final day in freeDays)
                      if (day != key) day,
                  }),
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _add(context),
            icon: const Icon(Icons.add),
            label: const Text('Add free day'),
          ),
        ),
      ],
    );
  }
}
