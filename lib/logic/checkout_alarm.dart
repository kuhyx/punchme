/// Handing the target check-out time to the system Clock app.
library;

import 'package:android_intent_plus/android_intent.dart';
import 'package:platform/platform.dart';

/// Sets a phone alarm for [at], labelled [message].
///
/// Injectable so the widget layer can be tested without a platform channel.
typedef SetAlarm =
    Future<void> Function({
      required DateTime at,
      required String message,
    });

/// The platform the intent believes it is on.
///
/// `AndroidIntent.launch()` silently no-ops off Android, and `flutter test`
/// runs on the host, so a test must be able to say otherwise. Production
/// leaves this at the real local platform.
Platform alarmPlatform = const LocalPlatform();

/// Default [SetAlarm]: opens the system Clock app via `ACTION_SET_ALARM`.
///
/// `SKIP_UI: false` deliberately shows the Clock app's own confirmation, so
/// an alarm is never created behind the user's back.
///
/// android_intent_plus v5 and v6 both use `startActivityForResult` and the
/// Clock app never sends a result, so this times out rather than hanging --
/// the same trap wake_alarm hit.
Future<void> setCheckOutAlarm({
  required DateTime at,
  required String message,
}) async {
  final intent = AndroidIntent(
    platform: alarmPlatform,
    action: 'android.intent.action.SET_ALARM',
    arguments: <String, dynamic>{
      'android.intent.extra.alarm.HOUR': at.hour,
      'android.intent.extra.alarm.MINUTES': at.minute,
      'android.intent.extra.alarm.SKIP_UI': false,
      'android.intent.extra.alarm.MESSAGE': message,
    },
  );
  await intent.launch().timeout(
    const Duration(seconds: 3),
    onTimeout: () {},
  );
}
