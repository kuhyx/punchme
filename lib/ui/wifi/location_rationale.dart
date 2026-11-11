/// Explaining why a time tracker asks for location, before Android does.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:punchme/ui/glyphs.dart';

/// Why reading a Wi-Fi network name needs location.
const String kLocationRationale =
    'punchme clocks you in automatically when your phone joins your work '
    "Wi-Fi. To read a network's name, Android requires location permission "
    '— a network name can reveal where you are.';

/// What punchme does, and does not do, with that permission.
const String kLocationPromise =
    'GPS and your position are never read. Only the names of the networks '
    'you add are stored, and they sync only to your own devices.';

/// What the prompts that follow will ask for, in order.
const String kBackgroundLocationHint =
    'Next, Android asks for location and for notifications (for the small '
    '"Watching for work Wi-Fi" notice). Then it asks a second time: choose '
    '"Allow all the time" so clocking in also works while punchme is closed.';

/// The explanation, as three rows of pictograms (textgate).
///
/// Each row reads left to right like the sentence it replaces, which stays
/// as the row's spoken label:
/// 1. work Wi-Fi -> auto clock-in; Wi-Fi name -> needs location.
/// 2. no GPS; only the network names, synced to your own devices.
/// 3. the prompts in order: location, notifications, then "all the time".
class LocationRationale extends StatelessWidget {
  /// Creates the explanation block.
  const LocationRationale({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget row(Key key, List<IconData> icons, String spoken) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Cue(key: key, icons: icons, spoken: spoken, size: 40),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        row(const Key('rationale-why'), const <IconData>[
          Icons.wifi,
          Icons.arrow_forward,
          Icons.punch_clock_outlined,
          Icons.add,
          Icons.location_on_outlined,
        ], kLocationRationale),
        Divider(color: muted.withValues(alpha: 0.3)),
        row(const Key('rationale-promise'), const <IconData>[
          Icons.gps_off,
          Icons.wifi,
          Icons.arrow_forward,
          Icons.devices,
        ], kLocationPromise),
        Divider(color: muted.withValues(alpha: 0.3)),
        row(const Key('rationale-next'), const <IconData>[
          Icons.location_on_outlined,
          Icons.notifications_outlined,
          Icons.arrow_forward,
          Icons.all_inclusive,
        ], kBackgroundLocationHint),
      ],
    );
  }
}

/// Shows the explanation and reports whether the user chose to continue.
Future<bool> showLocationRationaleDialog(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Icon(
          Icons.location_on_outlined,
          semanticLabel: 'Why location?',
        ),
        content: const SingleChildScrollView(child: LocationRationale()),
        actions: <Widget>[
          IconButton(
            key: const Key('rationale-not-now'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            icon: const Icon(Icons.close, semanticLabel: 'Not now'),
          ),
          IconButton(
            key: const Key('rationale-continue'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.check, semanticLabel: 'Continue'),
          ),
        ],
      ),
    ) ??
    false;
