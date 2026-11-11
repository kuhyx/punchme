/// What the user is told after a punch.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:punchme/logic/punch_coordinator.dart';
import 'package:punchme/nfc/punch_tag.dart';
import 'package:punchme/ui/glyphs.dart';
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

/// The pictograms for a refused punch: what was refused, and why.
List<IconData> refusalIcons(PunchRefusal refusal) => switch (refusal) {
  PunchRefusal.tooSoon => const <IconData>[Icons.block, Icons.timer_outlined],
  PunchRefusal.dayAlreadyClosed => const <IconData>[
    Icons.block,
    Icons.task_alt,
  ],
};

/// Builds the bar announcing [result].
///
/// Required rather than decorative: a background tap can invert the day's
/// state while the phone is locked, so the next thing the user sees has to say
/// what happened and offer a way straight back out of it. Said in pictograms
/// (textgate); the sentence is the spoken label.
SnackBar punchBanner({
  required PunchResult result,
  required VoidCallback onUndo,
}) {
  final refusal = result.refusal;
  final label = result.tagLabel;
  final what = refusal != null
      ? Cue(
          key: const Key('snack-refused'),
          icons: refusalIcons(refusal),
          spoken: refusalMessage(refusal),
        )
      : Semantics(
          container: true,
          label: committedMessage(result),
          excludeSemantics: true,
          child: Wrap(
            spacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              IconValue(
                key: const Key('snack-committed'),
                icon: result.checkedIn ? Icons.login : Icons.logout,
                value: clockLabel(result.at),
                spoken: committedMessage(result),
              ),
              // The tag's label is the user's own word, so it stays; the
              // fallback written for an empty label is not, so it is hidden.
              if (label != null && label != kDefaultTagLabel)
                IconValue(icon: Icons.nfc, value: label, spoken: label),
            ],
          ),
        );
  return SnackBar(
    content: Row(
      children: <Widget>[
        Expanded(
          child: Align(alignment: Alignment.centerLeft, child: what),
        ),
        IconButton(
          key: const Key('snack-undo'),
          onPressed: onUndo,
          icon: const Icon(Icons.undo, semanticLabel: 'Undo'),
        ),
      ],
    ),
    duration: kPunchBannerDuration,
  );
}

/// The bar for a tag with no punch payload on it.
SnackBar blankTagBanner() => const SnackBar(
  content: Cue(
    key: Key('snack-blank-tag'),
    icons: <IconData>[Icons.nfc, Icons.help_outline],
    spoken: kBlankTagMessage,
  ),
);

/// The bar for a tag written by a newer app version.
SnackBar unknownTagVersionBanner() => const SnackBar(
  content: Cue(
    key: Key('snack-new-tag'),
    icons: <IconData>[Icons.nfc, Icons.system_update],
    spoken: kUnknownTagVersionMessage,
  ),
);
