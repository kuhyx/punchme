/// Offering to set the system alarm after a check-in.
library;

import 'package:flutter/material.dart';
import 'package:punchme/logic/checkout_alarm.dart';
import 'package:punchme/logic/day_state.dart';
import 'package:punchme/logic/target_time.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/settings.dart';
import 'package:punchme/ui/home/checkout_alarm_dialog.dart';

/// Today's target, or null when there is nothing to aim at.
///
/// Recomputed rather than remembered: everything it depends on is persisted,
/// so a day left open keeps showing its target after the app is killed.
TargetToday? openTargetFor({
  required List<DayEntry> entries,
  required Settings settings,
  required DateTime now,
}) {
  final today = entryForDay(entries, now);
  if (today == null || !today.isOpen) {
    return null;
  }
  return targetForToday(
    entries: entries,
    settings: settings,
    checkIn: today.checkIn,
  );
}

/// Offers an alarm for the end of the day [checkIn] started.
///
/// Returns the target when the dialog was actually shown, so the caller can
/// tell whether the user has already been told the day began, and null when
/// there was nothing worth aiming at (a non-working day, or a week already
/// banked). Split out of the home screen to keep it under the length cap.
Future<TargetToday?> offerCheckOutAlarm({
  required BuildContext context,
  required DateTime checkIn,
  required List<DayEntry> entries,
  required Settings settings,
  required SetAlarm setAlarm,
  VoidCallback? beforeDialog,
}) async {
  final target = targetForToday(
    entries: entries,
    settings: settings,
    checkIn: checkIn,
  );
  if (target == null || !context.mounted) {
    return null;
  }
  beforeDialog?.call();
  final wanted = await showDialog<bool>(
    context: context,
    builder: (context) => CheckOutAlarmDialog(target: target),
  );
  if (wanted ?? false) {
    // A missing SET_ALARM permission, or a device with no Clock app, throws
    // rather than returning. The check-in is already saved by this point, so
    // a failed alarm must not take the whole flow down with it.
    try {
      await setAlarm(at: target.checkOutAt, message: 'punchme: check out');
    } on Exception catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not set the alarm')),
        );
      }
    }
  }
  return target;
}
