/// The history screen: every recorded day, and a way to fix them.
library;

import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:punchme/data/day_repository.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/local_date.dart';
import 'package:punchme/ui/history/day_editor.dart';
import 'package:punchme/ui/home/today_summary.dart';

/// Lists recorded days, newest first, and edits them.
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
      _days = days.reversed.toList();
      _loading = false;
    });
  }

  Future<void> _edit(DayEntry entry) async {
    final result = await showDialog<DayEdit>(
      context: context,
      builder: (_) => DayEditor(entry: entry),
    );
    if (result == null) {
      return;
    }
    if (result.delete) {
      await widget.repository.deleteDay(entry.dateKey);
    } else {
      // Re-keying an entry to another day must not leave the old one behind.
      if (result.entry.dateKey != entry.dateKey) {
        await widget.repository.deleteDay(entry.dateKey);
      }
      await widget.repository.saveDay(result.entry);
    }
    await _reload();
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

  @override
  Widget build(BuildContext context) => Scaffold(
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
        : ListView.builder(
            itemCount: _days.length,
            itemBuilder: (context, index) => _DayTile(
              entry: _days[index],
              onTap: () => _edit(_days[index]),
            ),
          ),
  );
}

/// One row in the history list.
class _DayTile extends StatelessWidget {
  const _DayTile({required this.entry, required this.onTap});

  final DayEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final worked = entry.worked;
    final checkOut = entry.checkOut;
    return ListTile(
      title: Text(entry.dateKey),
      subtitle: Text(
        checkOut == null
            ? '${clockLabel(entry.checkIn)} — missing check-out'
            : '${clockLabel(entry.checkIn)} – ${clockLabel(checkOut)}',
      ),
      trailing: Text(
        worked == null ? '—' : durationLabel(worked),
        style: TextStyle(
          color: worked == null
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : Theme.of(context).colorScheme.primary,
          fontSize: AppTextSize.body,
          fontWeight: FontWeight.w700,
        ),
      ),
      onTap: onTap,
    );
  }
}
