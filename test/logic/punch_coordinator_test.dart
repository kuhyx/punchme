import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/logic/day_state.dart';
import 'package:punchme/logic/punch_coordinator.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/local_date.dart';

import '../support/fake_day_repository.dart';

void main() {
  late DateTime clock;
  DateTime now() => clock;

  setUp(() => clock = DateTime(2026, 8, 25, 9, 3, 12));

  PunchCoordinator coordinatorFor(FakeDayRepository repo) =>
      PunchCoordinator(repository: repo, now: now);

  group('first punch', () {
    test('checks in when nothing is recorded', () async {
      final repo = FakeDayRepository();
      final result = await coordinatorFor(
        repo,
      ).handlePunch(source: PunchSource.button);

      expect(result.committed, isTrue);
      expect(result.checkedIn, isTrue);
      expect(result.state, DayState.checkedIn);
      expect(result.at, clock);
      expect(repo.savedDays.single.checkIn, clock);
      expect(repo.savedDays.single.dateKey, localDateKey(clock));
      expect(repo.savedDays.single.checkOut, isNull);
    });

    test('uses the passed instant, not the clock', () async {
      final repo = FakeDayRepository();
      final tapped = DateTime(2026, 8, 25, 8, 55);
      clock = DateTime(2026, 8, 25, 8, 55, 3);

      final result = await coordinatorFor(
        repo,
      ).handlePunch(source: PunchSource.button, at: tapped);

      expect(result.at, tapped);
      expect(repo.savedDays.single.checkIn, tapped);
    });
  });

  group('second punch', () {
    test('checks out an open day', () async {
      final repo = FakeDayRepository(
        days: <DayEntry>[
          DayEntry(dateKey: localDateKey(clock), checkIn: clock),
        ],
      );
      clock = clock.add(const Duration(hours: 8));

      final result = await coordinatorFor(
        repo,
      ).handlePunch(source: PunchSource.button);

      expect(result.checkedIn, isFalse);
      expect(result.state, DayState.checkedOut);
      expect(repo.savedDays.single.checkOut, clock);
    });

    test('refuses once the day is already closed', () async {
      final start = clock;
      final repo = FakeDayRepository(
        days: <DayEntry>[
          DayEntry(
            dateKey: localDateKey(start),
            checkIn: start,
            checkOut: start.add(const Duration(hours: 8)),
          ),
        ],
      );
      clock = start.add(const Duration(hours: 9));

      final result = await coordinatorFor(
        repo,
      ).handlePunch(source: PunchSource.nfcForeground);

      expect(result.committed, isFalse);
      expect(result.refusal, PunchRefusal.dayAlreadyClosed);
      expect(result.state, DayState.checkedOut);
      expect(repo.savedDays, isEmpty);
    });
  });

  group('double-tap guard', () {
    Future<PunchResult> tapAfter(Duration gap, PunchSource source) async {
      final start = clock;
      final repo = FakeDayRepository(
        days: <DayEntry>[
          DayEntry(dateKey: localDateKey(start), checkIn: start),
        ],
      );
      clock = start.add(gap);
      return coordinatorFor(repo).handlePunch(source: source);
    }

    test('refuses a tap inside the window', () async {
      final result = await tapAfter(
        const Duration(seconds: 8),
        PunchSource.nfcForeground,
      );
      expect(result.committed, isFalse);
      expect(result.refusal, PunchRefusal.tooSoon);
      expect(result.state, DayState.checkedIn);
    });

    test('refuses a background tap inside the window too', () async {
      final result = await tapAfter(
        const Duration(seconds: 8),
        PunchSource.nfcBackground,
      );
      expect(result.refusal, PunchRefusal.tooSoon);
    });

    test('allows a tap once the window has passed', () async {
      final result = await tapAfter(
        punchGuardWindow + const Duration(seconds: 1),
        PunchSource.nfcForeground,
      );
      expect(result.committed, isTrue);
      expect(result.state, DayState.checkedOut);
    });

    test('does not guard the button', () async {
      final result = await tapAfter(
        const Duration(seconds: 8),
        PunchSource.button,
      );
      expect(result.committed, isTrue);
    });

    test('survives a cold start, since it reads persisted times', () async {
      final start = clock;
      final repo = FakeDayRepository(
        days: <DayEntry>[
          DayEntry(dateKey: localDateKey(start), checkIn: start),
        ],
      );
      clock = start.add(const Duration(seconds: 8));

      // A brand-new coordinator, as a launch-by-tag would build.
      final result = await PunchCoordinator(
        repository: repo,
        now: now,
      ).handlePunch(source: PunchSource.nfcBackground);

      expect(result.refusal, PunchRefusal.tooSoon);
    });

    test('measures from the latest time, including a check-out', () async {
      // A late shift that ends just before midnight, so the follow-up tap
      // lands on a *new* calendar day -- otherwise the closed-day rule would
      // answer first and the guard would never be reached.
      final start = DateTime(2026, 8, 25, 16);
      final out = DateTime(2026, 8, 25, 23, 59);
      final repo = FakeDayRepository(
        days: <DayEntry>[
          DayEntry(
            dateKey: localDateKey(start),
            checkIn: start,
            checkOut: out,
          ),
        ],
      );
      // Two minutes later, which is the next day but inside the window.
      clock = DateTime(2026, 8, 26, 0, 1);

      final result = await coordinatorFor(
        repo,
      ).handlePunch(source: PunchSource.nfcForeground);

      expect(result.refusal, PunchRefusal.tooSoon);
    });
  });

  group('undo', () {
    test('deletes a day the punch had just created', () async {
      final repo = FakeDayRepository(
        days: <DayEntry>[
          DayEntry(dateKey: localDateKey(clock), checkIn: clock),
        ],
      );
      final today = (await repo.loadDays()).single;

      await coordinatorFor(repo).undoPunch(today);

      expect(repo.deletedKeys, <String>[localDateKey(clock)]);
      expect(repo.savedDays, isEmpty);
    });

    test('reopens a sealed day rather than deleting it', () async {
      final start = clock;
      final repo = FakeDayRepository(
        days: <DayEntry>[
          DayEntry(
            dateKey: localDateKey(start),
            checkIn: start,
            checkOut: start.add(const Duration(hours: 8)),
          ),
        ],
      );
      final today = (await repo.loadDays()).single;

      await coordinatorFor(repo).undoPunch(today);

      expect(repo.deletedKeys, isEmpty);
      expect(repo.savedDays.single.checkOut, isNull);
      expect(repo.savedDays.single.checkIn, start);
    });
  });

  test('carries the tag label through', () async {
    final repo = FakeDayRepository();
    final result = await coordinatorFor(repo).handlePunch(
      source: PunchSource.nfcForeground,
      tagLabel: 'desk',
    );
    expect(result.tagLabel, 'desk');
  });

  test('defaults to the injected clock', () async {
    final repo = FakeDayRepository();
    final result = await PunchCoordinator(
      repository: repo,
      now: now,
    ).handlePunch(source: PunchSource.button);
    expect(result.at, clock);
  });
}
