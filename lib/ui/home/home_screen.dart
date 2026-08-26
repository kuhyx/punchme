/// The home screen: the big button, and today at a glance.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:punchme/data/day_repository.dart';
import 'package:punchme/export/share_target.dart';
import 'package:punchme/logic/checkout_alarm.dart';
import 'package:punchme/logic/day_state.dart';
import 'package:punchme/logic/punch_coordinator.dart';
import 'package:punchme/logic/target_time.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/nfc/punch_tag.dart';
import 'package:punchme/ui/home/background_punch.dart';
import 'package:punchme/ui/home/checkout_alarm_offer.dart';
import 'package:punchme/ui/home/commit_window.dart';
import 'package:punchme/ui/home/home_body.dart';
import 'package:punchme/ui/home/home_nav_actions.dart';
import 'package:punchme/ui/home/home_punch_handlers.dart';
import 'package:punchme/ui/home/punch_banner.dart';

/// The app's landing screen.
class HomeScreen extends StatefulWidget {
  /// Creates the home screen backed by [repository].
  const HomeScreen({
    required this.repository,
    this.now = DateTime.now,
    this.share = shareTextFile,
    this.setAlarm = setCheckOutAlarm,
    this.onReady,
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

  /// Handed the callbacks that deliver tag reads, once the state exists.
  ///
  /// The state class is private, so this is how the NFC plumbing -- and the
  /// tests standing in for it -- get hold of the tap entry point.
  final void Function(HomePunchHandlers)? onReady;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with CommitWindow<HomeScreen>, BackgroundPunch<HomeScreen> {
  List<DayEntry> _days = <DayEntry>[];
  bool _loading = true;

  /// Today's target, once checked in. Null before check-in, or when there is
  /// nothing meaningful to aim at (non-working day, week already banked).
  TargetToday? _target;

  ScaffoldMessengerState? _messenger;
  late final PunchCoordinator _coordinator = PunchCoordinator(
    repository: widget.repository,
    now: widget.now,
  );

  @override
  void initState() {
    super.initState();
    widget.onReady?.call(
      HomePunchHandlers(
        onPunch: onNfcPunch,
        onBlankTag: onBlankTag,
        onBackgroundPunch: commitBackgroundPunch,
        onResume: flushPendingPunch,
      ),
    );
    unawaited(_reload());
  }

  @override
  void dispose() {
    // A snack bar outlives the widget that showed it, and its dismiss timer
    // would still be pending after the tree is gone.
    _messenger?.clearSnackBars();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Captured because dispose() must not touch the element tree.
    _messenger = ScaffoldMessenger.of(context);
  }

  Future<void> _reload() async {
    final days = await widget.repository.loadDays();
    final settings = await widget.repository.loadSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _days = days;
      _loading = false;
      _target = openTargetFor(
        entries: days,
        settings: settings,
        now: widget.now(),
      );
    });
  }

  DayEntry? get _today => entryForDay(_days, widget.now());

  @override
  DateTime nowValue() => widget.now();

  void _onPressed() {
    if (pending) {
      cancelPending();
      return;
    }
    arm(source: PunchSource.button, at: widget.now());
  }

  /// Commits through the coordinator and surfaces the outcome.
  ///
  /// Every source funnels through here, so the button and a tag cannot drift
  /// apart: the coordinator owns which way the day toggles and what is
  /// written, and this method owns only what the user is then shown.
  @override
  Future<void> commitPunch({
    required PunchSource source,
    required DateTime at,
    String? tagLabel,
  }) async {
    final result = await _coordinator.handlePunch(
      source: source,
      at: at,
      tagLabel: tagLabel,
    );
    await _reload();
    if (!mounted) {
      return;
    }
    // The banner goes up first so the modal alarm offer draws on top of it.
    // It is deliberately short-lived, so anything the alarm flow reports
    // afterwards is not left queued behind it.
    _showSnack(punchBanner(result: result, onUndo: _undo));
    // The alarm offer stays here rather than in the coordinator: it is a modal
    // dialog, and a background punch has no widget attached to show one from.
    if (result.checkedIn) {
      await _offerCheckOutAlarm(at);
    }
  }

  /// Writes a background tap straight through, with no cancel window.
  @override
  Future<PunchResult> punchInBackground(PunchTag tag) async {
    final result = await _coordinator.handlePunch(
      source: PunchSource.nfcBackground,
      at: widget.now(),
      tagLabel: tag.label,
    );
    await _reload();
    return result;
  }

  @override
  void reportBackgroundPunch(PunchResult result) =>
      _showSnack(punchBanner(result: result, onUndo: _undo));

  /// Offers the alarm, adopting the target when the dialog was shown.
  Future<void> _offerCheckOutAlarm(DateTime checkIn) async {
    final target = await loadAndOfferCheckOutAlarm(
      context: context,
      repository: widget.repository,
      // Clearing the banner is the dialog's job, not the punch's: it only
      // happens when a dialog is actually raised, so a check-in with no
      // target keeps the banner that is its only report.
      beforeDialog: () => _messenger?.hideCurrentSnackBar(),
      checkIn: checkIn,
      entries: _days,
      setAlarm: widget.setAlarm,
    );
    if (target == null || !mounted) {
      return;
    }
    setState(() => _target = target);
  }

  @override
  void warnUnknownTagVersion() =>
      _showSnack(const SnackBar(content: Text(kUnknownTagVersionMessage)));

  @override
  void warnBlankTag() =>
      _showSnack(const SnackBar(content: Text(kBlankTagMessage)));

  // Deliberately neither clears nor hides first: the punch banner is often
  // followed by the alarm flow raising its own message, and dismissing the
  // current bar here takes that queued message down with it.
  void _showSnack(SnackBar bar) => _messenger?.showSnackBar(bar);

  Future<void> _undo() async {
    final today = _today;
    if (today == null) {
      return;
    }
    await _coordinator.undoPunch(today);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
      body: HomeBody(
        entry: today,
        state: state,
        now: widget.now,
        onPressed: _onPressed,
        pending: pending,
        progress: progress,
        target: _target,
        onUndo: _undo,
      ),
    );
  }
}
