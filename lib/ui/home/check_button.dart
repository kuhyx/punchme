/// The big check-in / check-out button.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:punchme/logic/day_state.dart';

/// How long a tap stays cancellable before it commits.
const Duration commitWindow = Duration(seconds: 3);

/// The full-bleed button that drives the whole app.
///
/// CHECK IN and CHECK OUT are exact inverses of one another: the fill and the
/// foreground swap, drawn from the shared palette rather than invented values.
class CheckButton extends StatelessWidget {
  /// Creates the button for [state].
  const CheckButton({
    required this.state,
    required this.onPressed,
    required this.pending,
    required this.progress,
    super.key,
  });

  /// What the button currently offers.
  final DayState state;

  /// Called on every tap: starts the commit window, or cancels a pending one.
  final VoidCallback onPressed;

  /// Whether a commit window is currently running.
  final bool pending;

  /// How far through the commit window, 0..1. Only meaningful when [pending].
  final double progress;

  /// The label for [state], before any pending-state override.
  static String labelFor(DayState state) {
    switch (state) {
      case DayState.readyToCheckIn:
        return 'CHECK IN';
      case DayState.checkedIn:
        return 'CHECK OUT';
      case DayState.checkedOut:
        return 'CHECKED OUT';
    }
  }

  /// The pictogram painted for [state]: door in, door out, done.
  static IconData iconFor(DayState state) => switch (state) {
    DayState.readyToCheckIn => Icons.login,
    DayState.checkedIn => Icons.logout,
    DayState.checkedOut => Icons.task_alt,
  };

  /// Whether [state] accepts a tap at all.
  static bool isEnabledFor(DayState state) => state != DayState.checkedOut;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = isEnabledFor(state);

    // The inversion: checking IN paints the accent on dark; checking OUT
    // paints dark on the accent. Same two colours, swapped.
    final checkingIn = state == DayState.readyToCheckIn;
    final fill = !enabled
        ? scheme.surfaceContainerHighest
        : checkingIn
        ? scheme.surface
        : scheme.primary;
    final foreground = !enabled
        ? scheme.onSurfaceVariant
        : checkingIn
        ? scheme.primary
        : scheme.onPrimary;

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: pending ? 'Tap again to cancel' : labelFor(state),
      child: Material(
        color: fill,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (pending) _ProgressWash(progress: progress, color: foreground),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        iconFor(state),
                        key: const Key('check-glyph'),
                        color: foreground,
                        size: AppTextSize.display * 3,
                      ),
                      if (pending) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        Icon(
                          Icons.undo,
                          key: const Key('check-cancel-glyph'),
                          color: foreground,
                          size: AppTextSize.display,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A left-to-right wash showing how much of the commit window has elapsed.
class _ProgressWash extends StatelessWidget {
  const _ProgressWash({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: progress.clamp(0, 1),
      child: ColoredBox(color: color.withValues(alpha: 0.15)),
    ),
  );
}
