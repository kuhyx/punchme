/// The statistics screen: where you stand this week, month and year.
library;

import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:punchme/data/day_repository.dart';
import 'package:punchme/logic/balance.dart';
import 'package:punchme/logic/periods.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/settings.dart';
import 'package:punchme/ui/stats/balance_card.dart';

/// Shows the worked-vs-expected balance over three periods.
class StatsScreen extends StatefulWidget {
  /// Creates the statistics screen backed by [repository].
  const StatsScreen({
    required this.repository,
    this.now = DateTime.now,
    super.key,
  });

  /// Where days and settings are read from.
  final DayRepository repository;

  /// The clock. Injected so tests can pin the period boundaries.
  final DateTime Function() now;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<DayEntry> _days = <DayEntry>[];
  Settings _settings = const Settings();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final days = await widget.repository.loadDays();
    final settings = await widget.repository.loadSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _days = days;
      _settings = settings;
      _loading = false;
    });
  }

  Balance _balanceFrom(DateTime from) => computeBalance(
    entries: _days,
    settings: _settings,
    from: from,
    now: widget.now(),
  );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final now = widget.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          BalanceCard(
            title: 'This week',
            balance: _balanceFrom(startOfWeek(now)),
          ),
          const SizedBox(height: AppSpacing.md),
          BalanceCard(
            title: 'This month',
            balance: _balanceFrom(startOfMonth(now)),
          ),
          const SizedBox(height: AppSpacing.md),
          BalanceCard(
            title: 'This year',
            balance: _balanceFrom(startOfYear(now)),
          ),
        ],
      ),
    );
  }
}
