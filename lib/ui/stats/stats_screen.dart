/// The statistics screen: where you stand this week, month and year.
library;

import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:punchme/data/day_repository.dart';
import 'package:punchme/logic/balance.dart';
import 'package:punchme/logic/periods.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/horizon.dart';
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

  Balance _balanceFor(DateTime from, DateTime to) => computeBalance(
    entries: _days,
    settings: _settings,
    from: from,
    to: to,
    now: widget.now(),
  );

  DateTime _periodStart(Horizon horizon, DateTime now) => switch (horizon) {
    Horizon.week => startOfWeek(now),
    Horizon.month => startOfMonth(now),
    Horizon.year => startOfYear(now),
  };

  DateTime _periodEnd(Horizon horizon, DateTime now) => switch (horizon) {
    Horizon.week => endOfWeek(now),
    Horizon.month => endOfMonth(now),
    Horizon.year => endOfYear(now),
  };

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final now = widget.now();
    return Scaffold(
      appBar: AppBar(),
      // Scaled down to fit rather than scrolled: the three cards always
      // share one screen, whatever the text size.
      body: LayoutBuilder(
        builder: (context, box) => FittedBox(
          alignment: Alignment.topCenter,
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: box.maxWidth,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final horizon in <Horizon>[
                    Horizon.week,
                    Horizon.month,
                    Horizon.year,
                  ]) ...<Widget>[
                    BalanceCard(
                      horizon: horizon,
                      balance: _balanceFor(
                        _periodStart(horizon, now),
                        _periodEnd(horizon, now),
                      ),
                      infoOnly: !_settings.countedHorizons.contains(horizon),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
