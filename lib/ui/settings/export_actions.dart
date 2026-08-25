/// The three export buttons.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:punchme/data/day_repository.dart';
import 'package:punchme/export/csv_export.dart';
import 'package:punchme/export/ics_export.dart';
import 'package:punchme/export/json_export.dart';
import 'package:punchme/export/share_target.dart';

/// Offers CSV, JSON and iCalendar exports of the recorded days.
class ExportActions extends StatelessWidget {
  /// Creates the export buttons backed by [repository].
  const ExportActions({
    required this.repository,
    required this.share,
    required this.now,
    super.key,
  });

  /// Where days and settings are read from.
  final DayRepository repository;

  /// How the produced file reaches the user.
  final ShareFile share;

  /// The clock, used for the iCalendar DTSTAMP.
  final DateTime Function() now;

  Future<void> _exportCsv() async {
    await share(
      fileName: 'punchme.csv',
      contents: toCsv(await repository.loadDays()),
      subject: 'punchme hours (CSV)',
    );
  }

  Future<void> _exportJson() async {
    await share(
      fileName: 'punchme.json',
      contents: toJsonExport(
        days: await repository.loadDays(),
        settings: await repository.loadSettings(),
      ),
      subject: 'punchme hours (JSON)',
    );
  }

  Future<void> _exportIcs() async {
    await share(
      fileName: 'punchme.ics',
      contents: toIcs(await repository.loadDays(), generatedAt: now()),
      subject: 'punchme hours (calendar)',
    );
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: <Widget>[
      OutlinedButton.icon(
        onPressed: _exportCsv,
        icon: const Icon(Icons.table_chart_outlined),
        label: const Text('CSV'),
      ),
      OutlinedButton.icon(
        onPressed: _exportJson,
        icon: const Icon(Icons.data_object),
        label: const Text('JSON'),
      ),
      OutlinedButton.icon(
        onPressed: _exportIcs,
        icon: const Icon(Icons.event_outlined),
        label: const Text('Calendar'),
      ),
    ],
  );
}
