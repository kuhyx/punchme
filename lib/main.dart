/// punchme: check in, check out, and know where you stand.
library;

import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:punchme/data/day_repository.dart';
import 'package:punchme/export/export_channel.dart';
import 'package:punchme/nfc/background_punch_channel.dart';
import 'package:punchme/sync/session_dump.dart';
import 'package:punchme/sync/sync_bootstrap.dart';
import 'package:punchme/sync/sync_check.dart';
import 'package:punchme/sync/sync_service.dart';
import 'package:punchme/ui/home/home_with_nfc.dart';

// coverage:ignore-line — flutter_test never invokes a Dart entry point, so
// this one-line delegate is unreachable from the suite. Everything it calls
// (runPunchme, bootstrap, PunchmeApp) is covered.
Future<void> main() async => runPunchme();

/// How the built widget tree is handed to the engine.
///
/// Injectable purely so [runPunchme] is reachable from a test: the real
/// `runApp` attaches to an engine that `flutter_test` does not provide.
typedef RunApp = void Function(Widget app);

/// Boots the app and runs it.
Future<void> runPunchme({RunApp run = runApp}) async => run(await bootstrap());

/// Opens the on-disk store and builds the widget tree to run.
///
/// Split from [main] so the bootstrap is testable: everything except the
/// `runApp` call, which only a real engine can perform.
Future<Widget> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Before anything can read or write a tag: the sandbox flavor must not
  // interpret the daily build's tags, nor write ones it would accept.
  await BackgroundPunchChannel().adoptPunchMime();
  // After the MIME is adopted, never before: the sync path is derived from
  // it, so building the store first would put the sandbox flavor's records on
  // the daily build's path.
  final synced = await openSyncedStore();
  final repository = synced.repository;
  // Pull whatever the other device recorded while this one was closed. Not
  // awaited: a cold start must not wait on the network to show the day.
  unawaited(synced.sync().catchError((_) => SyncOutcome.notConfigured));
  // Answers headless export broadcasts. Registered on the shared entry point
  // so a request works whether this engine is the UI one or the short-lived
  // one an ExportReceiver spins up with the app closed.
  // The same entry point answers the verification broadcast. It reports
  // whether a tick actually synced and what the remote now holds for this
  // device -- never a credential, which is shared across every sibling app
  // and must not leave the phone.
  ExportChannel(
    repository: repository,
    syncCheck: () => reportSyncCheck(synced),
    // Hands over the shared kuhy-syncs credential, at the owner's explicit
    // request. See session_dump.dart for what that token actually covers.
    sessionDump: dumpSession,
  ).listen();
  return PunchmeApp(repository: repository);
}

/// Runs one verification of [synced] and renders it as JSON.
///
/// A named function rather than a closure inside [bootstrap] so the report is
/// reachable from a test without a platform message -- the wiring above is
/// then one expression with nothing hidden inside it.
Future<String> reportSyncCheck(SyncedStore synced) async => (await runSyncCheck(
  sync: synced.sync,
  openClient: synced.openClient,
  deviceId: synced.deviceId,
)).toJson();

/// The application root.
class PunchmeApp extends StatelessWidget {
  /// Creates the app backed by [repository].
  const PunchmeApp({required this.repository, super.key});

  /// Where days are read from and written to.
  final DayRepository repository;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'punchme',
    theme: buildLightTheme(),
    darkTheme: buildDarkTheme(),
    home: HomeWithNfc(repository: repository),
  );
}
