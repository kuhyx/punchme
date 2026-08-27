import 'package:crdt_sync/crdt_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/settings.dart';
import 'package:punchme/sync/crdt_day_repository.dart';
import 'package:punchme/sync/day_record_codec.dart';

import 'fake_log_persistence.dart';

/// Exercises the CRDT backend against the same contract the JSON store meets.
///
/// The interface is what the whole app above depends on, so a divergence here
/// is a behaviour change for every screen -- which is exactly what swapping a
/// backend must not cause.
void main() {
  DayEntry openDay(String key) =>
      DayEntry(dateKey: key, checkIn: DateTime(2026, 8, 25, 10, 29));

  test('starts empty, with default settings', () async {
    final repository = CrdtDayRepository(store: await openFakeStore());

    expect(await repository.loadDays(), isEmpty);
    expect(
      (await repository.loadSettings()).requiredPerDay,
      const Duration(hours: 8),
    );
  });

  test('round-trips a saved day', () async {
    final repository = CrdtDayRepository(store: await openFakeStore());
    final day = openDay('2026-08-25');

    await repository.saveDay(day);

    final days = await repository.loadDays();
    expect(days, hasLength(1));
    expect(days.single.dateKey, '2026-08-25');
    expect(days.single.checkIn, day.checkIn);
  });

  test('replaces the day with the same key rather than appending', () async {
    final repository = CrdtDayRepository(store: await openFakeStore());
    final day = openDay('2026-08-25');

    await repository.saveDay(day);
    await repository.saveDay(day.closedAt(DateTime(2026, 8, 25, 18, 52)));

    final days = await repository.loadDays();
    expect(days, hasLength(1));
    expect(days.single.checkOut, DateTime(2026, 8, 25, 18, 52));
  });

  test(
    'returns days ascending by key whatever order they were saved',
    () async {
      final repository = CrdtDayRepository(store: await openFakeStore());

      await repository.saveDay(openDay('2026-08-26'));
      await repository.saveDay(openDay('2026-08-25'));

      expect(
        (await repository.loadDays()).map((d) => d.dateKey),
        <String>['2026-08-25', '2026-08-26'],
      );
    },
  );

  test('stamps each write with a strictly later clock', () async {
    final store = await openFakeStore();
    final repository = CrdtDayRepository(store: store);

    await repository.saveDay(openDay('2026-08-25'));
    final first = store.get('2026-08-25')!.fields[kCheckInField]!.$2;
    await repository.saveDay(
      openDay('2026-08-25').closedAt(DateTime(2026, 8, 25, 18, 52)),
    );
    final second = store.get('2026-08-25')!.fields[kCheckInField]!.$2;

    // Without this a re-save loses to its own predecessor under merge.
    expect(second.compareTo(first), greaterThan(0));
  });

  group('deleteDay', () {
    test('tombstones the day so a peer cannot resurrect it', () async {
      final store = await openFakeStore();
      final repository = CrdtDayRepository(store: store);
      await repository.saveDay(openDay('2026-08-25'));

      await repository.deleteDay('2026-08-25');

      expect(await repository.loadDays(), isEmpty);
      // Present but tombstoned, rather than gone: a merge with a peer that
      // still holds the day must not bring it back.
      expect(store.get('2026-08-25')!.deleted, isTrue);
    });

    test('is not an error for a key that was never stored', () async {
      final repository = CrdtDayRepository(store: await openFakeStore());

      await expectLater(repository.deleteDay('2026-01-01'), completes);
      expect(await repository.loadDays(), isEmpty);
    });
  });

  group('a stale open day and a peer check-out', () {
    test('a fresh open day does not clear a check-out it never saw', () async {
      // The data-loss case: this device has not merged, so it sees no day at
      // all, creates one, and stamps it at a LATER clock than the peer's.
      // Stamping a null check-out there would win under last-writer-wins and
      // erase a real recorded check-out.
      final store = await openFakeStore(nodeId: 'mine');
      await CrdtDayRepository(store: store).saveDay(openDay('2026-08-25'));

      expect(
        store.get('2026-08-25')!.fields.containsKey(kCheckOutField),
        isFalse,
      );
    });

    test('the peer check-out survives the merge', () async {
      const peer = Hlc(wallTimeMs: 1000, counter: 0, nodeId: 'peer');
      final peerLog = <String, Record>{
        '2026-08-25': dayToRecord(
          openDay('2026-08-25').closedAt(DateTime(2026, 8, 25, 17)),
          peer,
        ),
      };
      final store = await openFakeStore(nodeId: 'mine');
      await CrdtDayRepository(store: store).saveDay(openDay('2026-08-25'));

      final merged = mergeLogs(store.snapshot(), peerLog);

      expect(
        recordToDay(merged['2026-08-25']!)!.checkOut,
        DateTime(2026, 8, 25, 17),
      );
    });

    test('Undo still clears a check-out this device knows about', () async {
      final store = await openFakeStore();
      final repository = CrdtDayRepository(store: store);
      final closed = openDay('2026-08-25').closedAt(
        DateTime(2026, 8, 25, 18, 52),
      );
      await repository.saveDay(closed);

      // What `undoPunch` does for a sealed day.
      await repository.saveDay(closed.reopened());

      expect((await repository.loadDays()).single.checkOut, isNull);
      // Explicitly stamped null, so the reopen beats the earlier close on a
      // peer too rather than silently losing to it.
      expect(
        store.get('2026-08-25')!.fields[kCheckOutField]!.$1,
        isNull,
      );
    });
  });

  group('settings', () {
    test('round-trips saved settings', () async {
      final repository = CrdtDayRepository(store: await openFakeStore());
      const settings = Settings(
        requiredPerDay: Duration(hours: 7),
        freeDays: <String>{'2026-08-25'},
      );

      await repository.saveSettings(settings);

      final back = await repository.loadSettings();
      expect(back.requiredPerDay, const Duration(hours: 7));
      expect(back.freeDays, <String>{'2026-08-25'});
    });

    test('does not appear among the days', () async {
      final repository = CrdtDayRepository(store: await openFakeStore());

      await repository.saveSettings(
        const Settings(requiredPerDay: Duration(hours: 7)),
      );

      expect(await repository.loadDays(), isEmpty);
    });
  });

  group('onWrite', () {
    test('fires after every committed write', () async {
      var pushes = 0;
      final repository = CrdtDayRepository(
        store: await openFakeStore(),
        onWrite: () => pushes++,
      );

      await repository.saveDay(openDay('2026-08-25'));
      await repository.saveSettings(const Settings());
      await repository.deleteDay('2026-08-25');

      expect(pushes, 3);
    });

    test('does not fire for a delete that wrote nothing', () async {
      var pushes = 0;
      final repository = CrdtDayRepository(
        store: await openFakeStore(),
        onWrite: () => pushes++,
      );

      await repository.deleteDay('2026-01-01');

      expect(pushes, isZero);
    });

    test(
      'defaults to doing nothing, so a punch never waits on a network',
      () async {
        final repository = CrdtDayRepository(store: await openFakeStore());

        await expectLater(repository.saveDay(openDay('2026-08-25')), completes);
      },
    );
  });
}
