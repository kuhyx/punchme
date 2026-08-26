/// The cancellable window between a tap and the punch it commits.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:punchme/logic/punch_coordinator.dart';
import 'package:punchme/nfc/punch_tag.dart';
import 'package:punchme/ui/home/check_button.dart';

/// Runs the commit window for a screen that punches.
///
/// Split out of the home screen so the timer bookkeeping -- which is fiddly,
/// and which leaks pending timers into the test binding when it is wrong --
/// lives apart from the layout it drives.
mixin CommitWindow<T extends StatefulWidget> on State<T> {
  Timer? _commitTimer;
  Timer? _ticker;

  /// The instant of the FIRST tap. The commit window is a mis-tap guard, not
  /// a delay: the time recorded is when the user tapped, never 3s later.
  DateTime? pendingSince;

  /// What armed the pending window, so the commit is attributed correctly.
  PunchSource pendingSource = PunchSource.button;

  /// The tag that armed the pending window, when one did.
  String? pendingTagLabel;

  /// The clock the window measures against.
  DateTime nowValue();

  /// Commits a punch that survived the window.
  Future<void> commitPunch({
    required PunchSource source,
    required DateTime at,
    String? tagLabel,
  });

  /// Whether a window is currently running.
  bool get pending => pendingSince != null;

  /// How far through the window, 0..1. Only meaningful while [pending].
  double get progress {
    final since = pendingSince;
    if (since == null) {
      return 0;
    }
    final elapsed = nowValue().difference(since).inMilliseconds;
    return elapsed / commitWindow.inMilliseconds;
  }

  /// Starts a cancellable window attributed to [source].
  ///
  /// Cancels any window already running first, so a second arm can never
  /// orphan the first one's ticker.
  void arm({
    required PunchSource source,
    required DateTime at,
    String? tagLabel,
  }) {
    _commitTimer?.cancel();
    _ticker?.cancel();
    setState(() {
      pendingSince = at;
      pendingSource = source;
      pendingTagLabel = tagLabel;
    });
    // Redraw a few times a second so the wash animates without a controller.
    _ticker = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => setState(() {}),
    );
    _commitTimer = Timer(commitWindow, _commit);
  }

  /// Handles a tag read while the app is in the foreground.
  ///
  /// A tap respects the same cancel window a press gets. A window already
  /// running belongs to whoever armed it, so an overlapping read is dropped:
  /// a tag is not a cancel gesture, and must not double-commit alongside one.
  Future<void> onNfcPunch(PunchTag tag) async {
    if (pending) {
      return;
    }
    // An odd schema still means "clock me", so this warns once and carries on
    // rather than refusing a punch over a version number.
    if (!tag.isKnownVersion && !_warnedUnknownVersion) {
      _warnedUnknownVersion = true;
      warnUnknownTagVersion();
    }
    arm(
      source: PunchSource.nfcForeground,
      at: nowValue(),
      tagLabel: tag.label,
    );
  }

  bool _warnedUnknownVersion = false;

  /// Tells the user this tag came from a newer build. Called at most once.
  void warnUnknownTagVersion();

  /// Points the user at the write-tag screen after an unwritten tag.
  ///
  /// Only fires while nothing is pending, so a stray read during a window
  /// cannot interrupt a punch the user is already making.
  void onBlankTag() {
    if (!pending) {
      warnBlankTag();
    }
  }

  /// Tells the user this tag needs writing first.
  void warnBlankTag();

  /// Drops the pending window without writing anything.
  void cancelPending() {
    _commitTimer?.cancel();
    _ticker?.cancel();
    _commitTimer = null;
    _ticker = null;
    setState(() {
      pendingSince = null;
      pendingTagLabel = null;
    });
  }

  Future<void> _commit() async {
    // Snapshot before cancelling: cancelPending clears the pending fields,
    // and the label has to survive into the result banner.
    final at = pendingSince;
    final source = pendingSource;
    final tagLabel = pendingTagLabel;
    cancelPending();
    if (at == null) {
      return;
    }
    await commitPunch(source: source, at: at, tagLabel: tagLabel);
  }

  @override
  void dispose() {
    _commitTimer?.cancel();
    _ticker?.cancel();
    super.dispose();
  }
}
