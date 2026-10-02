/// Showing onboarding over the home screen on the first launch only.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:punchme/data/day_repository.dart';
import 'package:punchme/data/onboarding_store.dart';
import 'package:punchme/ui/onboarding/onboarding_screen.dart';

/// Builds an onboarding screen over [repository]. Injected for tests.
typedef OnboardingBuilder = Widget Function(DayRepository repository);

Widget _realOnboarding(DayRepository repository) =>
    OnboardingScreen(repository: repository);

/// Wraps [child] and pushes onboarding once, after the first frame.
///
/// The home screen builds underneath regardless, so a background NFC launch
/// still lands while onboarding is up. Skipped outright when work SSIDs are
/// already configured: an install that already auto-punches has nothing to
/// be walked through.
class OnboardingGate extends StatefulWidget {
  /// Creates a gate in front of [child].
  const OnboardingGate({
    required this.repository,
    required this.child,
    this.openStore = OnboardingStore.open,
    this.onboarding = _realOnboarding,
    super.key,
  });

  /// Where settings are read to decide whether onboarding is needed.
  final DayRepository repository;

  /// The screen onboarding sits on top of.
  final Widget child;

  /// Opens the "already onboarded" marker. Injected for tests.
  final Future<OnboardingStore> Function() openStore;

  /// Builds the onboarding screen.
  final OnboardingBuilder onboarding;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_maybeOnboard()),
    );
  }

  Future<void> _maybeOnboard() async {
    final store = await widget.openStore();
    if (store.isDone()) {
      return;
    }
    final settings = await widget.repository.loadSettings();
    if (settings.workWifiSsids.isEmpty && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => widget.onboarding(widget.repository),
        ),
      );
    }
    // Marked whether the user added a network or skipped: skipping is an
    // answer, and Settings is where to change it later.
    await store.markDone();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
