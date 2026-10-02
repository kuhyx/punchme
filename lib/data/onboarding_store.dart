/// Remembering, per install, that first-launch onboarding has run.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A marker file in app-support storage, present once onboarding has run.
///
/// Deliberately device-local and NOT part of the synced settings: work SSIDs
/// sync between devices, but location permission is granted per device, so
/// a second phone still has to be walked through asking for it.
class OnboardingStore {
  /// Creates a store backed by [file].
  OnboardingStore(this.file);

  /// Opens the store at the platform's app-support directory.
  static Future<OnboardingStore> open() async {
    final dir = await getApplicationSupportDirectory();
    return OnboardingStore(File(p.join(dir.path, 'onboarding_done')));
  }

  /// The marker file. Injected so tests never touch real app data.
  final File file;

  /// Whether onboarding has already run on this install.
  bool isDone() => file.existsSync();

  /// Records that onboarding has run, so it never shows again.
  Future<void> markDone() async {
    await file.parent.create(recursive: true);
    await file.writeAsString('');
  }
}
