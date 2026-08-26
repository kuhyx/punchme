/// The seam between the NFC layer and the home screen.
library;

import 'package:flutter/widgets.dart';
import 'package:punchme/nfc/punch_tag.dart';

/// Delivers a tag read to the screen.
typedef PunchHandler = Future<void> Function(PunchTag);

/// The entry points the NFC layer needs once the screen exists.
class HomePunchHandlers {
  /// Creates the set.
  ///
  /// [onBackgroundPunch] is optional so a test exercising only the foreground
  /// path can build these without standing up the platform channel too.
  const HomePunchHandlers({
    required this.onPunch,
    required this.onBlankTag,
    this.onBackgroundPunch,
    this.onResume = _ignore,
  });

  static void _ignore() {}

  /// Called with each punchme tag read while the app is in front.
  final PunchHandler onPunch;

  /// Called when a tag is readable but is not a clock tag.
  final VoidCallback onBlankTag;

  /// Called with a tag tapped while the app was backgrounded or closed.
  ///
  /// Separate from [onPunch] because it commits at once and skips the alarm
  /// dialog -- see `BackgroundPunch` for why the cancel window cannot apply.
  final PunchHandler? onBackgroundPunch;

  /// Called when the app comes back to the front.
  ///
  /// A background punch committed against a locked phone has nothing to show
  /// its banner on, so it is held until this fires. Defaults to a no-op so
  /// tests exercising the foreground path alone need not supply one.
  final VoidCallback onResume;
}
