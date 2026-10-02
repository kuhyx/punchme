/// The home screen's snack bars: where they go, and the tag warnings.
library;

import 'package:flutter/material.dart';
import 'package:punchme/ui/home/punch_banner.dart';

/// Holds the [ScaffoldMessengerState] the home screen reports through.
///
/// Split from `home_screen.dart` to keep that file to punch orchestration.
/// Also supplies the two tag warnings `CommitWindow` asks for, which are
/// nothing but snack bars.
mixin HomeSnacks<T extends StatefulWidget> on State<T> {
  ScaffoldMessengerState? _messenger;

  /// The messenger captured while the element tree was still reachable.
  ScaffoldMessengerState? get messenger => _messenger;

  @override
  void dispose() {
    // A snack bar outlives the widget that showed it, and its dismiss timer
    // would still be pending after the tree is gone.
    _messenger?.clearSnackBars();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Captured because dispose() must not touch the element tree.
    _messenger = ScaffoldMessenger.of(context);
  }

  /// Satisfies `CommitWindow`: a tag written by a newer app version.
  void warnUnknownTagVersion() =>
      showSnack(const SnackBar(content: Text(kUnknownTagVersionMessage)));

  /// Satisfies `CommitWindow`: a tag with no punch payload on it.
  void warnBlankTag() =>
      showSnack(const SnackBar(content: Text(kBlankTagMessage)));

  /// Queues [bar].
  ///
  /// Deliberately neither clears nor hides first: the punch banner is often
  /// followed by the alarm flow raising its own message, and dismissing the
  /// current bar here takes that queued message down with it.
  void showSnack(SnackBar bar) => _messenger?.showSnackBar(bar);
}
