/// Free-days calendar and the list of days already marked.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:punchme/ui/settings/free_day_calendar.dart';

/// Month names for the calendar header, `DateTime.january`..`december`.
const List<String> monthLabels = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// How far either side of today the calendar can be paged.
///
/// Matches the window the date pickers elsewhere in the app already use, so
/// the reachable range is the same wherever a date is chosen.
const int calendarYearSpan = 5;

/// Whether [month] is inside the window reachable from [now].
bool canShowMonth(DateTime month, DateTime now) {
  final first = DateTime(now.year - calendarYearSpan, now.month);
  final last = DateTime(now.year + calendarYearSpan, now.month);
  return !month.isBefore(first) && !month.isAfter(last);
}

/// Lets the user mark free days by tapping them on a calendar.
class FreeDaysField extends StatefulWidget {
  /// Creates a field over [freeDays], a set of `YYYY-MM-DD` keys.
  const FreeDaysField({
    required this.freeDays,
    required this.workingWeekdays,
    required this.onChanged,
    required this.now,
    super.key,
  });

  /// Date keys (`YYYY-MM-DD`) currently marked free.
  final Set<String> freeDays;

  /// Which weekdays are working days (`DateTime.monday`..`DateTime.sunday`).
  final Set<int> workingWeekdays;

  /// Called with the new set when a day is marked or unmarked.
  final ValueChanged<Set<String>> onChanged;

  /// The clock, deciding which month opens first. Injected for tests.
  final DateTime Function() now;

  @override
  State<FreeDaysField> createState() => _FreeDaysFieldState();
}

class _FreeDaysFieldState extends State<FreeDaysField> {
  late DateTime _month;

  /// The set the next toggle builds on.
  ///
  /// Several taps can land inside one frame, before the parent has rebuilt and
  /// handed down a new [FreeDaysField.freeDays]. Reading the prop directly
  /// would make each of those taps start from the same stale set, so the last
  /// one would win and the earlier days would vanish.
  late Set<String> _pendingFreeDays;

  @override
  void initState() {
    super.initState();
    final now = widget.now();
    _month = DateTime(now.year, now.month);
    _pendingFreeDays = widget.freeDays;
  }

  @override
  void didUpdateWidget(FreeDaysField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The parent is the source of truth whenever it actually changes.
    if (widget.freeDays != oldWidget.freeDays) {
      _pendingFreeDays = widget.freeDays;
    }
  }

  void _step(int months) =>
      setState(() => _month = DateTime(_month.year, _month.month + months));

  /// Adds [key] when it is absent, removes it when present.
  void _toggle(String key) {
    final current = _pendingFreeDays;
    final next = <String>{
      for (final day in current)
        if (day != key) day,
      if (!current.contains(key)) key,
    };
    _pendingFreeDays = next;
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now();
    final previous = DateTime(_month.year, _month.month - 1);
    final next = DateTime(_month.year, _month.month + 1);
    // Keys, not the raw set, so the sort is stable; ISO keys sort correctly as
    // strings, so no parsing (and no FormatException on a hand-edited file).
    final sorted = widget.freeDays.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous month',
              onPressed: canShowMonth(previous, now) ? () => _step(-1) : null,
            ),
            Expanded(
              child: Center(
                child: Text(
                  '${monthLabels[_month.month - 1]} ${_month.year}',
                  style: const TextStyle(fontSize: AppTextSize.body),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next month',
              onPressed: canShowMonth(next, now) ? () => _step(1) : null,
            ),
          ],
        ),
        FreeDayCalendar(
          month: _month,
          freeDays: widget.freeDays,
          workingWeekdays: widget.workingWeekdays,
          onToggle: _toggle,
        ),
        const SizedBox(height: AppSpacing.md),
        // The grid shows one month; the chips are the whole inventory, so a
        // free day in another month is still visible and removable.
        if (sorted.isEmpty)
          const Text('No free days yet')
        else
          Wrap(
            spacing: AppSpacing.sm,
            children: <Widget>[
              for (final day in sorted)
                InputChip(
                  label: Text(day),
                  onDeleted: () => _toggle(day),
                ),
            ],
          ),
      ],
    );
  }
}
