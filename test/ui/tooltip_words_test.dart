import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Regression test: icon-only buttons must have a one-word tooltip matching
// the allowed regex, keeping the long-form semanticLabel intact.
void main() {
  const entries = <(String, String)>[
    ('lib/ui/home/punch_banner.dart', 'Undo'),
    ('lib/ui/home/home_nav_actions.dart', 'Statistics'),
    ('lib/ui/home/home_nav_actions.dart', 'History'),
    ('lib/ui/home/home_nav_actions.dart', 'Settings'),
    ('lib/ui/home/checkout_alarm_dialog.dart', 'Later'),
    ('lib/ui/history/history_screen.dart', 'Add'),
    ('lib/ui/history/history_screen.dart', 'Previous'),
    ('lib/ui/history/history_screen.dart', 'Next'),
    ('lib/ui/history/day_editor.dart', 'Delete'),
    ('lib/ui/history/day_editor.dart', 'Cancel'),
    ('lib/ui/history/day_editor.dart', 'Save'),
    ('lib/ui/onboarding/onboarding_screen.dart', 'Settings'),
    ('lib/ui/onboarding/onboarding_screen.dart', 'Skip'),
    ('lib/ui/settings/export_actions.dart', 'CSV'),
    ('lib/ui/settings/export_actions.dart', 'JSON'),
    ('lib/ui/settings/export_actions.dart', 'Calendar'),
    ('lib/ui/settings/free_days_field.dart', 'Previous'),
    ('lib/ui/settings/free_days_field.dart', 'Next'),
    ('lib/ui/settings/hours_field.dart', 'Less'),
    ('lib/ui/settings/hours_field.dart', 'More'),
    ('lib/ui/settings/wifi_ssids_field.dart', 'Add-network'),
    ('lib/ui/settings/wifi_ssids_field.dart', 'Settings'),
    ('lib/ui/settings/sync_actions.dart', 'Retry'),
    ('lib/ui/wifi/location_rationale.dart', 'Later'),
    ('lib/ui/wifi/location_rationale.dart', 'Continue'),
  ];

  final wordPattern = RegExp(r'^[A-Za-z][A-Za-z-]{0,19}$');
  for (final (path, word) in entries) {
    test('$path: $word', () {
      final contents = File(path).readAsStringSync();
      expect(contents, contains("tooltip: '$word'"));
      expect(wordPattern.hasMatch(word), isTrue, reason: word);
    });
  }
}
