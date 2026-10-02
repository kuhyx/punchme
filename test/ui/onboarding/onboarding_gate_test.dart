import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/data/onboarding_store.dart';
import 'package:punchme/models/settings.dart';
import 'package:punchme/ui/onboarding/onboarding_gate.dart';
import 'package:punchme/ui/onboarding/onboarding_screen.dart';

import '../../support/fake_day_repository.dart';

/// Held in memory: real async file writes never complete inside the
/// fake-async zone `testWidgets` runs in.
class _MemoryStore extends OnboardingStore {
  _MemoryStore() : super(File('unused'));

  bool done = false;

  @override
  bool isDone() => done;

  @override
  Future<void> markDone() async => done = true;
}

void main() {
  late _MemoryStore store;

  setUp(() => store = _MemoryStore());

  Widget stubOnboarding(_) => Builder(
    builder: (context) => TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('onboarding'),
    ),
  );

  Future<void> pump(WidgetTester tester, FakeDayRepository repo) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingGate(
          repository: repo,
          openStore: () async => store,
          onboarding: stubOnboarding,
          child: const Text('home'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a first launch with no networks shows onboarding', (
    tester,
  ) async {
    await pump(tester, FakeDayRepository());
    expect(find.text('onboarding'), findsOneWidget);
    expect(store.isDone(), isFalse);

    await tester.tap(find.text('onboarding'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(store.isDone(), isTrue);
  });

  testWidgets('builds the real onboarding screen by default', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingGate(
          repository: FakeDayRepository(),
          openStore: () async => store,
          child: const Text('home'),
        ),
      ),
    );
    // Not settled: the real screen waits on a permission channel with no
    // host here, behind a spinner that never stops animating.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('an install that already has networks skips it', (tester) async {
    final repo = FakeDayRepository(
      settings: const Settings(workWifiSsids: <String>{'Office'}),
    );
    await pump(tester, repo);
    expect(find.text('onboarding'), findsNothing);
    expect(store.isDone(), isTrue);
  });

  testWidgets('never shows twice', (tester) async {
    store.done = true;
    await pump(tester, FakeDayRepository());
    expect(find.text('onboarding'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });
}
