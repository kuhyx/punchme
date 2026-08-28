import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/settings.dart';
import 'package:punchme/ui/settings/google_sign_in_result.dart';
import 'package:punchme/ui/settings/settings_screen.dart';

import '../../support/fake_day_repository.dart';

/// A recorded share call.
class SharedFile {
  SharedFile(this.fileName, this.contents, this.subject);
  final String fileName;
  final String contents;
  final String subject;
}

void main() {
  DateTime now() => DateTime(2026, 8, 25, 12);
  late List<SharedFile> shared;

  setUp(() => shared = <SharedFile>[]);

  Future<void> share({
    required String fileName,
    required String contents,
    required String subject,
  }) async => shared.add(SharedFile(fileName, contents, subject));

  Future<void> pump(WidgetTester tester, FakeDayRepository repo) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          repository: repo,
          now: now,
          share: share,
          // Stubbed: the real probe reads the keystore over a platform
          // channel no host answers here, which would hang the whole file.
          syncProbe: () async => false,
          syncConnect: () async => GoogleSignInStatus.cancelled,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The free-days calendar makes the page taller than the test viewport, so
  // anything below it has to be scrolled into range before it can be tapped.
  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  group('hours per day', () {
    testWidgets('shows the current requirement', (tester) async {
      await pump(tester, FakeDayRepository());
      expect(find.text('8h 00m'), findsOneWidget);
    });

    testWidgets('stepping up saves the new value', (tester) async {
      final repo = FakeDayRepository();
      await pump(tester, repo);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();

      expect(find.text('8h 30m'), findsOneWidget);
      expect(
        (await repo.loadSettings()).requiredPerDay,
        const Duration(hours: 8, minutes: 30),
      );
    });

    testWidgets('stepping down saves the new value', (tester) async {
      final repo = FakeDayRepository();
      await pump(tester, repo);

      await tester.tap(find.byTooltip('Less'));
      await tester.pumpAndSettle();

      expect(find.text('7h 30m'), findsOneWidget);
    });
  });

  group('working days', () {
    testWidgets('shows every weekday as a chip', (tester) async {
      await pump(tester, FakeDayRepository());
      for (final label in <String>['Mon', 'Fri', 'Sat', 'Sun']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('toggling a day off saves it', (tester) async {
      final repo = FakeDayRepository();
      await pump(tester, repo);

      await tester.tap(find.text('Mon'));
      await tester.pumpAndSettle();

      expect(
        (await repo.loadSettings()).workingWeekdays,
        isNot(contains(DateTime.monday)),
      );
    });

    testWidgets('toggling a day on saves it', (tester) async {
      final repo = FakeDayRepository();
      await pump(tester, repo);

      await tester.tap(find.text('Sat'));
      await tester.pumpAndSettle();

      expect(
        (await repo.loadSettings()).workingWeekdays,
        contains(DateTime.saturday),
      );
    });
  });

  group('free days', () {
    testWidgets('says so when there are none', (tester) async {
      await pump(tester, FakeDayRepository());
      expect(find.text('No free days yet'), findsOneWidget);
    });

    testWidgets('lists existing free days', (tester) async {
      await pump(
        tester,
        FakeDayRepository(
          settings: const Settings().copyWith(
            freeDays: const <String>{'2026-12-25'},
          ),
        ),
      );
      expect(find.text('2026-12-25'), findsOneWidget);
    });

    testWidgets('removing a free day saves the smaller set', (tester) async {
      final repo = FakeDayRepository(
        settings: const Settings().copyWith(
          freeDays: const <String>{'2026-12-25'},
        ),
      );
      await pump(tester, repo);

      // The delete affordance is the chip's trailing button, whatever glyph
      // the current Material version uses for it.
      await scrollTo(tester, find.byTooltip('Delete'));
      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();

      expect((await repo.loadSettings()).freeDays, isEmpty);
    });
  });

  group('rapid taps', () {
    testWidgets('every tap survives overlapping saves', (tester) async {
      final repo = FakeDayRepository();
      await pump(tester, repo);

      // No settle between taps: each one starts a whole-file write while the
      // previous is still in flight. Without serialising, a later write
      // carrying an older snapshot would drop the days before it.
      for (final key in <String>['2026-08-04', '2026-08-05', '2026-08-06']) {
        await tester.tap(find.byKey(ValueKey<String>('free-day-$key')));
      }
      await tester.pumpAndSettle();

      expect((await repo.loadSettings()).freeDays, <String>{
        '2026-08-04',
        '2026-08-05',
        '2026-08-06',
      });
      expect(repo.savedSettings.length, 3);
    });
  });

  group('exports', () {
    final days = <DayEntry>[
      DayEntry(
        dateKey: '2026-08-24',
        checkIn: DateTime(2026, 8, 24, 9),
        checkOut: DateTime(2026, 8, 24, 17),
      ),
    ];

    testWidgets('CSV shares a .csv file with the header row', (tester) async {
      await pump(tester, FakeDayRepository(days: days));
      await scrollTo(tester, find.text('CSV'));
      await tester.tap(find.text('CSV'));
      await tester.pumpAndSettle();

      expect(shared.single.fileName, 'punchme.csv');
      expect(shared.single.contents, startsWith('date,check_in'));
      expect(shared.single.contents, contains('2026-08-24,09:00,17:00,8.00'));
    });

    testWidgets('JSON shares a .json file with the days', (tester) async {
      await pump(tester, FakeDayRepository(days: days));
      await scrollTo(tester, find.text('JSON'));
      await tester.tap(find.text('JSON'));
      await tester.pumpAndSettle();

      expect(shared.single.fileName, 'punchme.json');
      expect(shared.single.contents, contains('"dateKey": "2026-08-24"'));
    });

    testWidgets('Calendar shares an .ics file with one event', (tester) async {
      await pump(tester, FakeDayRepository(days: days));
      await scrollTo(tester, find.text('Calendar'));
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();

      expect(shared.single.fileName, 'punchme.ics');
      expect(shared.single.contents, contains('BEGIN:VEVENT'));
      expect(shared.single.contents, contains('UID:2026-08-24@'));
    });
  });
}
