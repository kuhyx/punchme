import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/ui/settings/wifi_status_card.dart';
import 'package:punchme/wifi/wifi_channel.dart';
import 'package:punchme/wifi/wifi_observation_store.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('punchme_status_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  WifiObservationStore store() =>
      WifiObservationStore(File('${dir.path}/wifi.json'));

  testWidgets('unarmed shows a hint and touches nothing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WifiStatusCard(
          armed: false,
          status: () async => throw StateError('should not be called'),
          openObservations: () async =>
              throw StateError('should not be called'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add a network above to turn this on.'), findsOneWidget);
  });

  testWidgets('armed with nothing seen yet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WifiStatusCard(
          armed: true,
          status: () async => const WifiPermissionStatus(
            locationGranted: true,
            notificationGranted: true,
            serviceRunning: true,
          ),
          openObservations: () async => store(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not seen on a work network yet'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(3));
    expect(find.byIcon(Icons.error), findsNothing);
  });

  testWidgets('armed with a recorded last-seen instant', (tester) async {
    final backing = store();
    // Real file I/O has to run outside the fake clock `testWidgets` pumps
    // on, including the pumps that let its completion reach the widget's
    // own `_load()` await -- so the whole interaction runs inside one
    // `runAsync` block rather than crossing in and out of it.
    await tester.runAsync(() async {
      await backing.save(<String, DateTime>{
        '2026-08-25': DateTime(2026, 8, 25, 17, 5),
      });
      await tester.pumpWidget(
        MaterialApp(
          home: WifiStatusCard(
            armed: true,
            status: () async => const WifiPermissionStatus(
              locationGranted: false,
              notificationGranted: true,
              serviceRunning: false,
            ),
            openObservations: () async => backing,
          ),
        ),
      );
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    expect(find.text('Last seen at work: 2026-08-25 17:05'), findsOneWidget);
    expect(find.byIcon(Icons.error), findsNWidgets(2));
  });

  testWidgets('reports unavailable when the real channel has no host', (
    tester,
  ) async {
    // Neither `status` nor `openObservations` is injected: `openObservations`
    // defaults to a real file open, which throws with no host behind the
    // channel in this test -- the same failure mode a device with the
    // permission not yet granted would not actually hit, but the catch
    // clause is shared with that case.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const MaterialApp(home: WifiStatusCard(armed: true)),
      );
      // Real I/O, so real time: poll rather than sleep a fixed 50ms, which
      // lost the race under a CPU-capped, parallel test run.
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (find.text('Not seen on a work network yet').evaluate().isEmpty &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });

    expect(find.text('Not seen on a work network yet'), findsOneWidget);
    expect(find.byIcon(Icons.error), findsNWidgets(3));
  });

  testWidgets('reloads when it becomes armed', (tester) async {
    var calls = 0;
    Future<WifiPermissionStatus> status() async {
      calls++;
      return const WifiPermissionStatus(
        locationGranted: true,
        notificationGranted: true,
        serviceRunning: true,
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: WifiStatusCard(
          armed: false,
          status: status,
          openObservations: () async => store(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 0);

    await tester.pumpWidget(
      MaterialApp(
        home: WifiStatusCard(
          armed: true,
          status: status,
          openObservations: () async => store(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(calls, 1);
  });

  testWidgets('builds with the real functions when none are injected', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: WifiStatusCard(armed: false)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add a network above to turn this on.'), findsOneWidget);
  });
}
