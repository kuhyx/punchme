/// The home screen: the big button, and today at a glance.
library;

import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:punchme/data/day_repository.dart';
import 'package:punchme/export/share_target.dart';
import 'package:punchme/logic/day_state.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/local_date.dart';
import 'package:punchme/ui/home/check_button.dart';
import 'package:punchme/ui/home/home_nav_actions.dart';
import 'package:punchme/ui/home/today_summary.dart';

/// The app's landing screen.
class HomeScreen extends StatefulWidget {
  /// Creates the home screen backed by [repository].
  const HomeScreen({
    required this.repository,
    this.now = DateTime.now,
    this.share = shareTextFile,
    super.key,
  });

  /// Where days are read from and written to.
  final DayRepository repository;

  /// The clock. Injected so tests can assert on exact timestamps.
  final DateTime Function() now;

  /// How an exported file reaches the user. Passed through to Settings.
  final ShareFile share;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<DayEntry> _days = <DayEntry>[];
  bool _loading = true;

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
    if (!mounted) {
      return;
    }
    setState(() {
      _days = days;
      _loading = false;
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
    final entry = today == null
        ? DayEntry(dateKey: localDateKey(at), checkIn: at)
        : today.closedAt(at);
    await widget.repository.saveDay(entry);
    await _reload();
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
                onUndo: state == DayState.checkedOut ? _undo : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
