/// What the user is told after a punch.
library;

import 'package:flutter/material.dart';
import 'package:punchme/logic/punch_coordinator.dart';
import 'package:punchme/ui/home/today_summary.dart';

/// How long a punch banner stays up.
///
/// Deliberately shorter than the 4s default: the check-in flow can raise its
/// own message straight after (a failed alarm, say), and a longer banner would
/// keep that queued behind it for long enough to be missed.
const Duration kPunchBannerDuration = Duration(milliseconds: 1500);

/// Shown when a readable tag is blank, or is not a clock tag we wrote.
const String kBlankTagMessage =
    'That tag is not set up yet. Use Settings > Write clock tag.';

/// Shown once when a tag carries a schema this build does not know.
const String kUnknownTagVersionMessage =
    'This tag was written by a newer version of punchme';

/// The line shown when a punch was refused.
String refusalMessage(PunchRefusal refusal) {
  switch (refusal) {
    case PunchRefusal.tooSoon:
      return 'Ignored: you punched moments ago';
    case PunchRefusal.dayAlreadyClosed:
      return 'Today is already checked out';
  }
}

/// The line shown when a punch was committed, e.g. `Checked OUT 18:02 via
/// desk tag`.
String committedMessage(PunchResult result) {
  final verb = result.checkedIn ? 'Checked IN' : 'Checked OUT';
  final label = result.tagLabel;
  final via = label == null ? '' : ' via $label tag';
  return '$verb ${clockLabel(result.at)}$via';
}

/// Builds the bar announcing [result].
///
/// Required rather than decorative: a background tap can invert the day's
/// state while the phone is locked, so the next thing the user sees has to say
/// what happened and offer a way straight back out of it.
SnackBar punchBanner({
  required PunchResult result,
  required VoidCallback onUndo,
}) {
  final refusal = result.refusal;
  if (refusal != null) {
    return SnackBar(
      content: Text(refusalMessage(refusal)),
      duration: kPunchBannerDuration,
    );
  }
  return SnackBar(
    content: Text(committedMessage(result)),
    duration: kPunchBannerDuration,
    action: SnackBarAction(label: 'Undo', onPressed: onUndo),
  );
}
