/// The home app bar's navigation buttons.
library;

import 'package:flutter/material.dart';
import 'package:punchme/data/day_repository.dart';
import 'package:punchme/export/save_target.dart';
import 'package:punchme/ui/history/history_screen.dart';
import 'package:punchme/ui/settings/settings_screen.dart';
import 'package:punchme/ui/stats/stats_screen.dart';

/// Opens the statistics, history and settings screens.
class HomeNavActions extends StatelessWidget {
  /// Creates the navigation actions.
  const HomeNavActions({
    required this.repository,
    required this.now,
    required this.share,
    required this.onReturn,
    super.key,
  });

  /// Passed to each pushed screen.
  final DayRepository repository;

  /// The clock, passed to each pushed screen.
  final DateTime Function() now;

  /// How an exported file reaches the user.
  final ShareFile share;

  /// Called after a pushed screen pops, since it may have edited data.
  final Future<void> Function() onReturn;

  Future<void> _open(BuildContext context, Widget screen) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => screen));
    await onReturn();
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      IconButton(
        key: const Key('nav-stats'),
        icon: const Icon(Icons.insights_outlined, semanticLabel: 'Statistics'),
        onPressed: () =>
            _open(context, StatsScreen(repository: repository, now: now)),
      ),
      IconButton(
        key: const Key('nav-history'),
        icon: const Icon(Icons.history, semanticLabel: 'History'),
        onPressed: () =>
            _open(context, HistoryScreen(repository: repository, now: now)),
      ),
      IconButton(
        key: const Key('nav-settings'),
        icon: const Icon(Icons.settings_outlined, semanticLabel: 'Settings'),
        onPressed: () => _open(
          context,
          SettingsScreen(repository: repository, now: now, share: share),
        ),
      ),
    ],
  );
}
