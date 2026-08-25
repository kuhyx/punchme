/// The home screen: the big button, and today at a glance.
library;

import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:punchme/data/day_repository.dart';
import 'package:punchme/export/share_target.dart';
import 'package:punchme/logic/checkout_alarm.dart';
import 'package:punchme/logic/day_state.dart';
import 'package:punchme/logic/target_time.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/local_date.dart';
import 'package:punchme/ui/home/check_button.dart';
import 'package:punchme/ui/home/checkout_alarm_dialog.dart';
import 'package:punchme/ui/home/home_nav_actions.dart';
import 'package:punchme/ui/home/today_summary.dart';

/// The app's landing screen.
class HomeScreen extends StatefulWidget {
  /// Creates the home screen backed by [repository].
  const HomeScreen({
    required this.repository,
    this.now = DateTime.now,
    this.share = shareTextFile,
    this.setAlarm = setCheckOutAlarm,
    super.key,
  });

  /// Where days are read from and written to.
  final DayRepository repository;

  /// The clock. Injected so tests can assert on exact timestamps.
  final DateTime Function() now;

  /// How an exported file reaches the user. Passed through to Settings.
  final ShareFile share;

  /// How a check-out alarm is scheduled. Injected for tests.
  final SetAlarm setAlarm;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<DayEntry> _days = <DayEntry>[];
  bool _loading = true;

  /// Today's target, once checked in. Null before check-in, or when there is
  /// nothing meaningful to aim at (non-working day, week already banked).
  TargetToday? _target;

  Timer? _commitTimer;
  Timer? _ticker;

  /// The instant of the FIRST tap. The commit window is a mis-tap guard, not
  /// a delay: the time recorded is when the user tapped, never 3s later.
  DateTime? _pendingSince;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  @override
  void dispose() {
    _commitTimer?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    final days = await widget.repository.loadDays();
    final settings = await widget.repository.loadSettings();
    if (!mounted) {
      return;
    }
    // Recompute rather than remember: everything the target depends on is
    // persisted, so a day that is still open keeps showing its target after
    // the app is killed and reopened.
    final today = entryForDay(days, widget.now());
    setState(() {
      _days = days;
      _loading = false;
      _target = today == null || !today.isOpen
          ? null
          : targetForToday(
              entries: days,
              settings: settings,
              checkIn: today.checkIn,
            );
    });
  }

  DayEntry? get _today => entryForDay(_days, widget.now());

  double get _progress {
    final since = _pendingSince;
    if (since == null) {
      return 0;
    }
    final elapsed = widget.now().difference(since).inMilliseconds;
    return elapsed / commitWindow.inMilliseconds;
  }

  void _onPressed() {
    if (_pendingSince != null) {
      _cancelPending();
      return;
    }
    setState(() => _pendingSince = widget.now());
    // Redraw a few times a second so the wash animates without a controller.
    _ticker = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => setState(() {}),
    );
    _commitTimer = Timer(commitWindow, _commit);
  }

  void _cancelPending() {
    _commitTimer?.cancel();
    _ticker?.cancel();
    _commitTimer = null;
    _ticker = null;
    setState(() => _pendingSince = null);
  }

  Future<void> _commit() async {
    final at = _pendingSince;
    _cancelPending();
    if (at == null) {
      return;
    }
    final today = _today;
    final checkingIn = today == null;
    final entry = checkingIn
        ? DayEntry(dateKey: localDateKey(at), checkIn: at)
        : today.closedAt(at);
    await widget.repository.saveDay(entry);
    await _reload();
    if (checkingIn) {
      await _offerCheckOutAlarm(at);
    }
  }

  /// Works out when today should end and offers to set an alarm for it.
  ///
  /// The share is the week's remaining hours split across the working days
  /// left, today included -- so a long day earlier in the week shortens the
  /// ones after it.
  Future<void> _offerCheckOutAlarm(DateTime checkIn) async {
    final settings = await widget.repository.loadSettings();
    final target = targetForToday(
      entries: _days,
      settings: settings,
      checkIn: checkIn,
    );
    if (target == null || !mounted) {
      return;
    }
    setState(() => _target = target);
    final wanted = await showDialog<bool>(
      context: context,
      builder: (context) => CheckOutAlarmDialog(target: target),
    );
    if (wanted ?? false) {
      // A missing SET_ALARM permission, or a device with no Clock app, throws
      // rather than returning. The check-in is already saved by this point,
      // so a failed alarm must not take the whole flow down with it.
      try {
        await widget.setAlarm(
          at: target.checkOutAt,
          message: 'punchme: check out',
        );
      } on Exception catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not set the alarm')),
          );
        }
      }
    }
  }

  Future<void> _undo() async {
    final today = _today;
    if (today == null) {
      return;
    }
    await widget.repository.saveDay(today.reopened());
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final today = _today;
    final state = stateFor(today);
    return Scaffold(
      appBar: AppBar(
        title: const Text('punchme'),
        actions: <Widget>[
          HomeNavActions(
            repository: widget.repository,
            now: widget.now,
            share: widget.share,
            onReturn: _reload,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: CheckButton(
                state: state,
                onPressed: _onPressed,
                pending: _pendingSince != null,
                progress: _progress,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TodaySummary(
                entry: today,
                now: widget.now,
                target: state == DayState.checkedIn ? _target : null,
                onUndo: state == DayState.checkedOut ? _undo : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
