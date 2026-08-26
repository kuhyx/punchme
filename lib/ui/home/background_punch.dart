/// Committing taps that arrived while the app was not in front.
library;

import 'package:flutter/widgets.dart';
import 'package:punchme/logic/punch_coordinator.dart';
import 'package:punchme/nfc/punch_tag.dart';

/// Commits background taps immediately and reports them on the next resume.
///
/// Deliberately not routed through `CommitWindow`: the 3s cancel window needs
/// a screen the user is looking at, and a tap made against a locked phone has
/// none -- the phone may relock before the window elapses, taking the punch
/// with it. So the write happens at once, the alarm dialog is skipped, and the
/// result is held back until there is somebody there to see it.
mixin BackgroundPunch<T extends StatefulWidget> on State<T> {
  PunchResult? _pending;

  /// Commits the coordinator write, then refreshes the screen.
  Future<PunchResult> punchInBackground(PunchTag tag);

  /// Shows the outcome of a background punch.
  void reportBackgroundPunch(PunchResult result);

  /// Whether the app is in front, so a banner would actually be seen.
  ///
  /// Overridable because `flutter_test` starts a binding whose lifecycle
  /// state is null rather than resumed, and a test for the held-back path
  /// needs to say which side of this it is exercising.
  bool get isForeground =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  /// Writes the punch [tag] triggered, without offering the alarm.
  Future<void> commitBackgroundPunch(PunchTag tag) async {
    final result = await punchInBackground(tag);
    if (!mounted) {
      return;
    }
    if (isForeground) {
      reportBackgroundPunch(result);
      return;
    }
    // Nobody is looking: hold it rather than raising a banner into a screen
    // that is behind the lock screen and about to be paused again.
    _pending = result;
  }

  /// Shows anything held back, now that the user is looking.
  ///
  /// Cleared before reporting so a second resume cannot show it twice.
  void flushPendingPunch() {
    final held = _pending;
    if (held == null) {
      return;
    }
    _pending = null;
    reportBackgroundPunch(held);
  }
}
