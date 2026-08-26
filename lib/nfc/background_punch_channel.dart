/// The Dart end of the platform channel that carries background tag taps.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:punchme/nfc/punch_tag.dart';

/// The channel MainActivity.kt talks over.
///
/// Kotlin is transport only: it forwards the NDEF payload it was launched
/// with and nothing else. Which way the day toggles, and whether the guard
/// refuses the tap, stays with the Dart coordinator.
const String kNfcChannelName = 'kuhy.punchme/nfc';

/// Asks the host for the tap that launched the app, if any.
///
/// Drained rather than pushed: on a cold start the engine finishes booting
/// long after `onCreate` runs, so a push from Kotlin would land before Dart
/// has a handler and be dropped. The host buffers it and hands it over here.
const String kGetLaunchPunchMethod = 'getLaunchPunch';

/// The method Kotlin calls when a tap arrives at an already-running app.
const String kBackgroundPunchMethod = 'onBackgroundPunch';

/// Decodes a channel payload into a tag, or null when there is nothing usable.
///
/// Null covers every shape that is not a tag we can act on: no launch intent
/// at all, a non-string reply, or a payload that claimed our MIME type and
/// then carried something other than a JSON object. None of those is worth
/// interrupting the user over -- there is no punch to report either way.
PunchTag? decodePunchPayload(Object? payload) {
  if (payload is! String || payload.isEmpty) {
    return null;
  }
  try {
    return PunchTag.fromBytes(Uint8List.fromList(utf8.encode(payload)));
  } on FormatException {
    return null;
  }
}

/// Carries taps that arrived while the app was not in the foreground.
///
/// Two directions over one channel: [drainLaunchPunch] pulls the cold-start
/// tap the host buffered, and [listen] registers for the warm taps that
/// `onNewIntent` forwards while the app is alive.
class BackgroundPunchChannel {
  /// Creates a channel, defaulting to the real platform one.
  BackgroundPunchChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(kNfcChannelName);

  final MethodChannel _channel;

  /// Fetches the tap the app was launched by, or null when it was not.
  ///
  /// A [MissingPluginException] is the ordinary answer off Android -- the
  /// host side simply is not there -- and means "no launch tap", not an error.
  Future<PunchTag?> drainLaunchPunch() async {
    final Object? payload;
    try {
      payload = await _channel.invokeMethod<String>(kGetLaunchPunchMethod);
    } on MissingPluginException {
      return null;
    }
    return decodePunchPayload(payload);
  }

  /// Reports each warm background tap to [onPunch].
  ///
  /// Unparseable payloads are dropped here rather than passed on, so callers
  /// only ever see taps they can actually commit.
  void listen(void Function(PunchTag) onPunch) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != kBackgroundPunchMethod) {
        return null;
      }
      final tag = decodePunchPayload(call.arguments);
      if (tag != null) {
        onPunch(tag);
      }
      return null;
    });
  }

  /// Stops listening, so a disposed screen cannot be called back into.
  void stop() => _channel.setMethodCallHandler(null);
}
