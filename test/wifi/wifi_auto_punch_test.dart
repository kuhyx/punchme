import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/logic/punch_coordinator.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/settings.dart';
import 'package:punchme/wifi/wifi_auto_punch.dart';
import 'package:punchme/wifi/wifi_observation_store.dart';

import '../support/fake_day_repository.dart';

void main() {
  late Directory dir;
  late WifiObservationStore observations;
  const settings = Settings(workWifiSsids: <String>{'Office'});

  setUp(() {
    dir = Directory.systemTemp.createTempSync('punchme_wifi_auto_test');
    observations = WifiObservationStore(File('${dir.path}/wifi.json'));
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('the first connection of the day checks in', () async {
    final repo = FakeDayRepository();
    final now = DateTime(2026, 8, 25, 9);

    await runWifiCheck(
      coordinator: PunchCoordinator(repository: repo, now: () => now),
      observations: observations,
      settings: settings,
      currentSsid: 'Office',
      now: now,
    );

    expect(repo.savedDays.single.checkIn, now);
    expect(repo.savedDays.single.checkOut, isNull);
    expect((await observations.load())['2026-08-25'], now);
  });

  test('a network not configured as work does nothing', () async {
    final repo = FakeDayRepository();
    await runWifiCheck(
      coordinator: PunchCoordinator(repository: repo),
      observations: observations,
      settings: settings,
      currentSsid: 'Coffee Shop',
      now: DateTime(2026, 8, 25, 9),
    );
    expect(repo.savedDays, isEmpty);
    expect(await observations.load(), isEmpty);
  });

  test('no current network does nothing but is not an error', () async {
    final repo = FakeDayRepository();
    await runWifiCheck(
      coordinator: PunchCoordinator(repository: repo),
      observations: observations,
      settings: settings,
      currentSsid: null,
      now: DateTime(2026, 8, 25, 9),
    );
    expect(repo.savedDays, isEmpty);
  });

  test('a reconnect the same day does not check in again', () async {
    final checkIn = DateTime(2026, 8, 25, 9);
    final repo = FakeDayRepository(
      days: <DayEntry>[DayEntry(dateKey: '2026-08-25', checkIn: checkIn)],
    );
    final reconnect = DateTime(2026, 8, 25, 13, 30);

    await runWifiCheck(
      coordinator: PunchCoordinator(repository: repo),
      observations: observations,
      settings: settings,
      currentSsid: 'Office',
      now: reconnect,
    );

    // No new punch was written -- the entry the fake started with is the
    // only thing it has ever saved.
    expect(repo.savedDays, isEmpty);
    expect((await observations.load())['2026-08-25'], reconnect);
  });

  test('a lunch trip only pushes last-seen forward, not a checkout', () async {
    final repo = FakeDayRepository(
      days: <DayEntry>[
        DayEntry(dateKey: '2026-08-25', checkIn: DateTime(2026, 8, 25, 9)),
      ],
    );
    final coordinator = PunchCoordinator(repository: repo);

    // Out to lunch: no observation call happens while disconnected.
    // Back from lunch:
    final backFromLunch = DateTime(2026, 8, 25, 13);
    await runWifiCheck(
      coordinator: coordinator,
      observations: observations,
      settings: settings,
      currentSsid: 'Office',
      now: backFromLunch,
    );
    // Later the same afternoon:
    final afternoon = DateTime(2026, 8, 25, 16);
    await runWifiCheck(
      coordinator: coordinator,
      observations: observations,
      settings: settings,
      currentSsid: 'Office',
      now: afternoon,
    );

    final day = (await repo.loadDays()).single;
    expect(day.isOpen, isTrue);
    expect((await observations.load())['2026-08-25'], afternoon);
  });

  test('rollover closes an open day at its last-seen instant', () async {
    final checkIn = DateTime(2026, 8, 25, 9);
    final lastSeen = DateTime(2026, 8, 25, 17, 45);
    final repo = FakeDayRepository(
      days: <DayEntry>[DayEntry(dateKey: '2026-08-25', checkIn: checkIn)],
    );
    await observations.save(<String, DateTime>{'2026-08-25': lastSeen});

    // Next morning, not on any work network yet.
    await runWifiCheck(
      coordinator: PunchCoordinator(repository: repo),
      observations: observations,
      settings: settings,
      currentSsid: null,
      now: DateTime(2026, 8, 26, 7),
    );

    final day = (await repo.loadDays()).single;
    expect(day.checkOut, lastSeen);
    expect(await observations.load(), isEmpty);
  });

  test('rollover leaves a manually-closed day untouched', () async {
    final checkIn = DateTime(2026, 8, 25, 9);
    final manualCheckOut = DateTime(2026, 8, 25, 18);
    final repo = FakeDayRepository(
      days: <DayEntry>[
        DayEntry(
          dateKey: '2026-08-25',
          checkIn: checkIn,
          checkOut: manualCheckOut,
        ),
      ],
    );
    await observations.save(<String, DateTime>{
      '2026-08-25': DateTime(2026, 8, 25, 12),
    });

    await runWifiCheck(
      coordinator: PunchCoordinator(repository: repo),
      observations: observations,
      settings: settings,
      currentSsid: null,
      now: DateTime(2026, 8, 26, 7),
    );

    expect(repo.savedDays, isEmpty);
    expect((await repo.loadDays()).single.checkOut, manualCheckOut);
  });

  test('rollover with no recorded day for that date is a no-op', () async {
    final repo = FakeDayRepository();
    await observations.save(<String, DateTime>{
      '2026-08-25': DateTime(2026, 8, 25, 12),
    });

    await runWifiCheck(
      coordinator: PunchCoordinator(repository: repo),
      observations: observations,
      settings: settings,
      currentSsid: null,
      now: DateTime(2026, 8, 26, 7),
    );

    expect(repo.savedDays, isEmpty);
    expect(await observations.load(), isEmpty);
  });

  test(
    'a stale date is finalized before a fresh check-in is written',
    () async {
      final repo = FakeDayRepository(
        days: <DayEntry>[
          DayEntry(dateKey: '2026-08-25', checkIn: DateTime(2026, 8, 25, 9)),
        ],
      );
      await observations.save(<String, DateTime>{
        '2026-08-25': DateTime(2026, 8, 25, 17),
      });

      await runWifiCheck(
        coordinator: PunchCoordinator(repository: repo),
        observations: observations,
        settings: settings,
        currentSsid: 'Office',
        now: DateTime(2026, 8, 26, 9),
      );

      final days = await repo.loadDays();
      expect(days, hasLength(2));
      expect(
        days.firstWhere((d) => d.dateKey == '2026-08-25').checkOut,
        DateTime(2026, 8, 25, 17),
      );
      expect(
        days.firstWhere((d) => d.dateKey == '2026-08-26').checkIn,
        DateTime(2026, 8, 26, 9),
      );
    },
  );
}
