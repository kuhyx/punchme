/// The history screen: every recorded day, and a way to fix them.
library;

import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:punchme/data/day_repository.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/local_date.dart';
import 'package:punchme/ui/history/day_editor.dart';
import 'package:punchme/ui/history/month_grid.dart';

/// Height kept free under the grid for the floating add button.
const double _fabClearance = 80;

/// Shows recorded days a month at a time, and edits them.
class HistoryScreen extends StatefulWidget {
  /// Creates the history screen backed by [repository].
  const HistoryScreen({
    required this.repository,
    this.now = DateTime.now,
    super.key,
  });

  /// Where days are read from and written to.
  final DayRepository repository;

  /// The clock, used when adding a missing day.
  final DateTime Function() now;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<DayEntry> _days = <DayEntry>[];
  bool _loading = true;
  late DateTime _month = DateTime(widget.now().year, widget.now().month);

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
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

  Future<void> _edit(DayEntry entry) async {
    if (await editDay(
      context: context,
      repository: widget.repository,
      entry: entry,
    )) {
      await _reload();
    }
  }

  Future<void> _addMissingDay() async {
    final today = widget.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateTime(today.year - 5),
      lastDate: today,
    );
    if (picked == null) {
      return;
    }
    final start = DateTime(picked.year, picked.month, picked.day, 9);
    await _edit(DayEntry(dateKey: localDateKey(start), checkIn: start));
  }

  /// Moves the shown month by [delta] months.
  void _shift(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final current = widget.now();
    final atLatest = !_month.isBefore(DateTime(current.year, current.month));
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addMissingDay,
        tooltip: 'Add a missing day',
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _days.isEmpty
          ? const Center(child: Text('No days recorded yet'))
          : Column(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    IconButton(
                      onPressed: () => _shift(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          localDateKey(_month).substring(0, 7),
                          style: const TextStyle(
                            fontSize: AppTextSize.title,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: atLatest ? null : () => _shift(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                Expanded(
                  // Clear of the add button, which floats over the grid.
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: _fabClearance),
                    child: MonthGrid(
                      month: _month,
                      entries: <String, DayEntry>{
                        for (final day in _days) day.dateKey: day,
                      },
                      onTap: _edit,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
