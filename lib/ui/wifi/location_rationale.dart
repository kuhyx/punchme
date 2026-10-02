/// Explaining why a time tracker asks for location, before Android does.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

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

/// The explanation, as plain stacked paragraphs.
class LocationRationale extends StatelessWidget {
  /// Creates the explanation block.
  const LocationRationale({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(kLocationRationale),
      SizedBox(height: AppSpacing.sm),
      Text(kLocationPromise),
      SizedBox(height: AppSpacing.sm),
      Text(kBackgroundLocationHint),
    ],
  );
}

/// Shows the explanation and reports whether the user chose to continue.
Future<bool> showLocationRationaleDialog(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Why location?'),
        content: const SingleChildScrollView(child: LocationRationale()),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    ) ??
    false;
