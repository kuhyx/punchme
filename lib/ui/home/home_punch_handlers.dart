/// The seam between the NFC layer and the home screen.
library;

import 'package:flutter/widgets.dart';
import 'package:punchme/nfc/punch_tag.dart';

/// Delivers a tag read to the screen.
typedef PunchHandler = Future<void> Function(PunchTag);

/// The entry points the NFC layer needs once the screen exists.
class HomePunchHandlers {
  /// Creates the pair.
  const HomePunchHandlers({required this.onPunch, required this.onBlankTag});

  /// Called with each punchme tag read.
  final PunchHandler onPunch;

  /// Called when a tag is readable but is not a clock tag.
  final VoidCallback onBlankTag;
}
