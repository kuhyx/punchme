/// The home screen's layout, apart from the punch logic that drives it.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:punchme/logic/day_state.dart';
import 'package:punchme/logic/target_time.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/ui/home/check_button.dart';
import 'package:punchme/ui/home/today_summary.dart';

/// The button and today's summary, stacked.
///
/// Split from `home_screen.dart` so the screen's state class holds punch
/// orchestration only: what the layout needs arrives as plain values, which
/// also makes it pumpable on its own.
class HomeBody extends StatelessWidget {
  /// Creates the body for [entry] in [state].
  const HomeBody({
    required this.entry,
    required this.state,
    required this.now,
    required this.onPressed,
    required this.pending,
    required this.progress,
    this.target,
    this.onUndo,
    super.key,
  });

  /// Today's record, or null before the first punch of the day.
  final DayEntry? entry;

  /// Which way the big button points.
  final DayState state;

  /// The clock the summary counts against.
  final DateTime Function() now;

  /// Runs on a button press.
  final VoidCallback onPressed;

  /// Whether a commit window is running.
  final bool pending;

  /// How far through that window, 0..1.
  final double progress;

  /// Today's target, when there is one worth showing.
  final TargetToday? target;

  /// Reverses the last punch, when there is one to reverse.
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      children: <Widget>[
        Expanded(
          child: CheckButton(
            state: state,
            onPressed: onPressed,
            pending: pending,
            progress: progress,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: TodaySummary(
            entry: entry,
            now: now,
            target: state == DayState.checkedIn ? target : null,
            onUndo: state == DayState.checkedOut ? onUndo : null,
          ),
        ),
      ],
    ),
  );
}
