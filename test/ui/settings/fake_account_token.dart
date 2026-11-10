import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('dev.kuhy/google_account_token');

/// Stands in for the `google_account_token` native side on Android.
///
/// Pins the platform to Android (the plugin short-circuits elsewhere) and
/// answers the chooser with [token], or null for a dismissed chooser. Returns
/// the arguments the plugin sent, so a test can assert the Web client id.
/// Undone by [resetFakeAccountToken] in a `tearDown`.
List<Object?> fakeAccountToken(String? token) {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  final sent = <Object?>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (call) async {
        sent.add(call.arguments);
        return token;
      });
  return sent;
}

/// Restores the platform and removes the channel handler.
void resetFakeAccountToken() {
  debugDefaultTargetPlatformOverride = null;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, null);
}
