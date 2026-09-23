/// Turning Wi-Fi connectivity observations into automatic punches.
library;

import 'package:punchme/logic/punch_coordinator.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/local_date.dart';
import 'package:punchme/models/settings.dart';
import 'package:punchme/wifi/wifi_observation_store.dart';

/// Turns one Wi-Fi observation into whatever punches it implies.
///
/// Called from three places -- the periodic worker, the instant network
/// callback, and the app's own resume hook -- so this is the one place the
/// actual rule lives: the first connection to a work network on a day checks
/// in, and the last confirmed-still-connected instant becomes that day's
/// check-out once the day rolls over. A reconnect later the same day (a
/// lunch trip, say) only pushes "last seen" forward -- it never checks out
/// mid-day.
///
/// A day already touched by hand blocks both automatically, with no extra
/// state to track: [PunchCoordinator.handlePunch] only checks in when no
/// entry exists yet for that date, and only checks out while the entry is
/// still open.
Future<void> runWifiCheck({
  required PunchCoordinator coordinator,
  required WifiObservationStore observations,
  required Settings settings,
  required String? currentSsid,
  required DateTime now,
}) async {
  final today = localDateKey(now);
  final stored = await observations.load();
  final days = await coordinator.repository.loadDays();

  // Finalize every past date before touching today, so a connection made
  // right after midnight is never mistaken for closing out yesterday.
  var changed = false;
  for (final dateKey in stored.keys.toList()..sort()) {
    if (dateKey.compareTo(today) >= 0) {
      continue;
    }
    final entry = _entryForDateKey(days, dateKey);
    if (entry != null && entry.isOpen) {
      await coordinator.handlePunch(
        source: PunchSource.wifiAuto,
        at: stored[dateKey],
      );
    }
    stored.remove(dateKey);
    changed = true;
  }

  final onWorkWifi =
      currentSsid != null && settings.workWifiSsids.contains(currentSsid);
  if (onWorkWifi) {
    if (_entryForDateKey(days, today) == null) {
      await coordinator.handlePunch(source: PunchSource.wifiAuto, at: now);
    }
    stored[today] = now;
    changed = true;
  }

  if (changed) {
    await observations.save(stored);
  }
}

DayEntry? _entryForDateKey(List<DayEntry> days, String dateKey) {
  for (final day in days) {
    if (day.dateKey == dateKey) {
      return day;
    }
  }
  return null;
}
