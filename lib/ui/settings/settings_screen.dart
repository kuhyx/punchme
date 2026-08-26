/// The settings screen: expectations, free days, and exports.
library;

import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:punchme/data/day_repository.dart';
import 'package:punchme/export/share_target.dart';
import 'package:punchme/models/settings.dart';
import 'package:punchme/nfc/nfc_service.dart';
import 'package:punchme/ui/settings/export_actions.dart';
import 'package:punchme/ui/settings/free_days_field.dart';
import 'package:punchme/ui/settings/hours_field.dart';
import 'package:punchme/ui/settings/weekday_picker.dart';
import 'package:punchme/ui/settings/write_tag_screen.dart';

/// Edits the work expectations and offers the three exports.
class SettingsScreen extends StatefulWidget {
  /// Creates the settings screen backed by [repository].
  const SettingsScreen({
    required this.repository,
    this.share = shareTextFile,
    this.now = DateTime.now,
    this.nfc,
    super.key,
  });

  /// Where settings are read from and written to.
  final DayRepository repository;

  /// How an exported file reaches the user. Injected for tests.
  final ShareFile share;

  /// Talks to the NFC hardware for the write-tag screen.
  ///
  /// Null means "build the real one when it is actually needed", so opening
  /// Settings on a device without NFC costs nothing.
  final NfcService? nfc;

  /// The clock, for the date picker and the export timestamps.
  final DateTime Function() now;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Settings _settings = const Settings();
  bool _loading = true;
  Future<void> _pending = Future<void>.value();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final settings = await widget.repository.loadSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  /// Applies [settings] immediately, then queues the write behind any
  /// in-flight one.
  ///
  /// Tapping days on the free-days calendar fires a write per tap with no gap
  /// between them, and `saveSettings` is a read-modify-write of the whole
  /// document. Overlapping calls would each persist the snapshot they were
  /// handed, so the last write to land could drop days the UI already shows.
  Future<void> _update(Settings settings) async {
    setState(() => _settings = settings);
    return _pending = _pending.then(
      (_) => widget.repository.saveSettings(settings),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          const SectionHeader('Hours per working day'),
          HoursField(
            value: _settings.requiredPerDay,
            onChanged: (value) =>
                _update(_settings.copyWith(requiredPerDay: value)),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader('Working days'),
          WeekdayPicker(
            selected: _settings.workingWeekdays,
            onChanged: (value) =>
                _update(_settings.copyWith(workingWeekdays: value)),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader('Free days'),
          FreeDaysField(
            freeDays: _settings.freeDays,
            workingWeekdays: _settings.workingWeekdays,
            now: widget.now,
            onChanged: (value) => _update(_settings.copyWith(freeDays: value)),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader('Clock tag'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Write clock tag'),
            subtitle: const Text(
              'Turn a blank NFC tag into one you can tap to clock in or out.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => WriteTagScreen(
                  service: widget.nfc ?? NfcService(),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader('Export'),
          ExportActions(
            repository: widget.repository,
            share: widget.share,
            now: widget.now,
          ),
        ],
      ),
    );
  }
}
