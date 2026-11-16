// Release builds only read src/main: without INTERNET there the sync tick
// fails its DNS lookup on the phone while debug builds (which carry their own
// INTERNET in src/debug) work, so no unit test of the sync code catches it.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the release manifest grants INTERNET for Firebase sync', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(
      manifest,
      contains('<uses-permission android:name="android.permission.INTERNET"/>'),
    );
  });
}
