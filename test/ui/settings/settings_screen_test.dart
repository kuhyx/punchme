import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/settings.dart';
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
        home: SettingsScreen(repository: repo, now: now, share: share),
      ),
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
      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();

      expect((await repo.loadSettings()).freeDays, isEmpty);
    });

    testWidgets('adding one through the date picker saves it', (tester) async {
      final repo = FakeDayRepository();
      await pump(tester, repo);

      await tester.tap(find.text('Add free day'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // The picker opens on `now`, so OK accepts today.
      expect((await repo.loadSettings()).freeDays, <String>{'2026-08-25'});
    });

    testWidgets('cancelling the picker changes nothing', (tester) async {
      final repo = FakeDayRepository();
      await pump(tester, repo);

      await tester.tap(find.text('Add free day'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect((await repo.loadSettings()).freeDays, isEmpty);
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
      await tester.tap(find.text('CSV'));
      await tester.pumpAndSettle();

      expect(shared.single.fileName, 'punchme.csv');
      expect(shared.single.contents, startsWith('date,check_in'));
      expect(shared.single.contents, contains('2026-08-24,09:00,17:00,8.00'));
    });

    testWidgets('JSON shares a .json file with the days', (tester) async {
      await pump(tester, FakeDayRepository(days: days));
      await tester.tap(find.text('JSON'));
      await tester.pumpAndSettle();

      expect(shared.single.fileName, 'punchme.json');
      expect(shared.single.contents, contains('"dateKey": "2026-08-24"'));
    });

    testWidgets('Calendar shares an .ics file with one event', (tester) async {
      await pump(tester, FakeDayRepository(days: days));
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();

      expect(shared.single.fileName, 'punchme.ics');
      expect(shared.single.contents, contains('BEGIN:VEVENT'));
      expect(shared.single.contents, contains('UID:2026-08-24@'));
    });
  });
}
