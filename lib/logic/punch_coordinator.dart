/// The one place a punch is committed, whatever triggered it.
library;

import 'package:punchme/data/day_repository.dart';
import 'package:punchme/logic/day_state.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/local_date.dart';

/// How a punch reached the app.
enum PunchSource {
  /// The big home-screen button.
  button,

  /// A tag tapped while the app was open.
  nfcForeground,

  /// A tag tapped while the app was backgrounded or closed.
  nfcBackground,
}

/// How close two NFC punches may be before the second is treated as a slip.
///
/// A phone resting against a tag reads it repeatedly; a person does not clock
/// out eight seconds after clocking in. Three minutes is long enough to cover
/// a fumbled tap and short enough not to block a genuine short errand.
const Duration punchGuardWindow = Duration(minutes: 3);

/// Why a punch was refused.
enum PunchRefusal {
  /// Another punch landed within [punchGuardWindow].
  tooSoon,

  /// The day is already checked out; the schema holds one session per day.
  dayAlreadyClosed,
}

/// What a punch did, or why it did nothing.
class PunchResult {
  /// A punch that was committed.
  const PunchResult.committed({
    required this.state,
    required this.at,
    required this.checkedIn,
    this.tagLabel,
  }) : refusal = null;

  /// A punch that the guard or the day's state refused.
  const PunchResult.refused({
    required this.state,
    required this.at,
    required this.refusal,
    this.tagLabel,
  }) : checkedIn = false;

  /// The state the day is in now.
  final DayState state;

  /// The instant the punch was recorded, or attempted.
  final DateTime at;

  /// Whether this punch *started* a day, so the caller can offer an alarm.
  final bool checkedIn;

  /// Why nothing was written, or null when the punch committed.
  final PunchRefusal? refusal;

  /// The label of the tag that triggered this, when one did.
  final String? tagLabel;

  /// Whether anything was written.
  bool get committed => refusal == null;
}

/// Commits punches from every source against one repository.
///
/// The button, a foreground tap and a background tap all land here, so the
/// rule for "which way does this toggle, and what gets written" exists once.
class PunchCoordinator {
  /// Creates a coordinator over [repository].
  PunchCoordinator({required this.repository, this.now = DateTime.now});

  /// Where days are read from and written to.
  final DayRepository repository;

  /// The clock. Injected so tests can pin exact timestamps.
  final DateTime Function() now;

  /// Records a punch from [source], defaulting to the current time.
  ///
  /// [at] is the instant the *user acted*, not when this was called -- the
  /// button passes its first-tap time so a 3s confirm window never shifts the
  /// recorded minute.
  Future<PunchResult> handlePunch({
    required PunchSource source,
    DateTime? at,
    String? tagLabel,
  }) async {
    final moment = at ?? now();
    final days = await repository.loadDays();
    final today = entryForDay(days, moment);

    // Already sealed: only Undo reopens a day, so a further tap must not
    // silently overwrite the session that is already recorded there.
    if (today != null && !today.isOpen) {
      return PunchResult.refused(
        state: DayState.checkedOut,
        at: moment,
        refusal: PunchRefusal.dayAlreadyClosed,
        tagLabel: tagLabel,
      );
    }

    // The guard covers taps only. The button is a deliberate act on a screen
    // the user is looking at, and it already has its own cancel window.
    if (source != PunchSource.button) {
      final last = _lastPunchAt(days);
      if (last != null && moment.difference(last).abs() < punchGuardWindow) {
        return PunchResult.refused(
          state: stateFor(today),
          at: moment,
          refusal: PunchRefusal.tooSoon,
          tagLabel: tagLabel,
        );
      }
    }

    final checkingIn = today == null;
    final entry = checkingIn
        ? DayEntry(dateKey: localDateKey(moment), checkIn: moment)
        : today.closedAt(moment);
    await repository.saveDay(entry);
    return PunchResult.committed(
      state: checkingIn ? DayState.checkedIn : DayState.checkedOut,
      at: moment,
      checkedIn: checkingIn,
      tagLabel: tagLabel,
    );
  }

  /// Reverses the last punch on [day], whichever half of it was written.
  ///
  /// An open day was *created* by its punch, so undoing that removes the
  /// record rather than leaving behind a check-in nobody made; a sealed day
  /// only loses its check-out.
  Future<void> undoPunch(DayEntry day) async {
    if (day.isOpen) {
      await repository.deleteDay(day.dateKey);
    } else {
      await repository.saveDay(day.reopened());
    }
  }

  /// The most recent recorded instant across every stored day.
  ///
  /// Derived rather than stored: check-in and check-out times are already
  /// persisted, so the guard survives a cold launch with no extra state and
  /// no migration. It tracks committed punches only -- a refused tap does not
  /// extend the window, which is the behaviour we want anyway.
  DateTime? _lastPunchAt(List<DayEntry> days) {
    DateTime? latest;
    for (final day in days) {
      for (final moment in <DateTime?>[day.checkIn, day.checkOut]) {
        if (moment != null && (latest == null || moment.isAfter(latest))) {
          latest = moment;
        }
      }
    }
    return latest;
  }
}
