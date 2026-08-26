import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/local_date.dart';
import 'package:punchme/nfc/punch_tag.dart';
import 'package:punchme/ui/home/check_button.dart';
import 'package:punchme/ui/home/home_punch_handlers.dart';
import 'package:punchme/ui/home/home_screen.dart';
import 'package:punchme/ui/home/punch_banner.dart';

import '../../support/fake_day_repository.dart';

/// A tap that arrived while the app was not in front.
///
/// The distinguishing behaviours, versus a foreground tap: it commits at once
/// rather than opening the 3s cancel window, it never raises the alarm dialog,
/// and its banner waits for the next resume when nobody was looking.
void main() {
  late DateTime clock;
  DateTime now() => clock;

  setUp(() => clock = DateTime(2026, 8, 25, 9, 3, 12));

  /// Waits out a banner so no dismiss animation survives into teardown.
  ///
  /// The bar's timer starts only once its entrance animation finishes, so a
  /// single pump of [kPunchBannerDuration] leaves it still on screen -- and a
  /// bar still live at teardown asserts into the next test's first frame.
  Future<void> drainBanner(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(kPunchBannerDuration);
    await tester.pumpAndSettle();
  }

  Future<HomePunchHandlers> pumpHome(
    WidgetTester tester,
    FakeDayRepository repo,
  ) async {
    late HomePunchHandlers handlers;
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          repository: repo,
          now: now,
          onReady: (ready) => handlers = ready,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return handlers;
  }

  testWidgets('commits at once, with no cancel window', (tester) async {
    final repo = FakeDayRepository();
    final handlers = await pumpHome(tester, repo);

    await handlers.onBackgroundPunch!(const PunchTag(label: 'desk'));
    await tester.pump();

    // No window: the phone may relock before 3s elapses, so waiting would
    // risk losing the punch entirely.
    expect(find.text('tap again to cancel'), findsNothing);
    expect(repo.savedDays.single.checkIn, clock);
    expect(find.text('CHECK OUT'), findsOneWidget);
  });

  testWidgets('never raises the alarm dialog', (tester) async {
    // A working day with a target: the same check-in through the foreground
    // path does offer an alarm, so this pins the difference.
    final repo = FakeDayRepository();
    final handlers = await pumpHome(tester, repo);

    await handlers.onBackgroundPunch!(const PunchTag(label: 'desk'));
    await tester.pumpAndSettle();

    expect(find.text('Set alarm'), findsNothing);
    expect(repo.savedDays, hasLength(1));
  });

  testWidgets('checks out a day that is already open', (tester) async {
    final repo = FakeDayRepository(
      days: <DayEntry>[
        DayEntry(
          dateKey: localDateKey(clock),
          checkIn: DateTime(2026, 8, 25, 8),
        ),
      ],
    );
    final handlers = await pumpHome(tester, repo);

    await handlers.onBackgroundPunch!(const PunchTag(label: 'desk'));
    await tester.pumpAndSettle();

    expect(repo.savedDays.single.checkOut, clock);
    expect(find.text('CHECKED OUT'), findsOneWidget);
  });

  testWidgets('holds the banner until the app is resumed', (tester) async {
    final repo = FakeDayRepository();
    final handlers = await pumpHome(tester, repo);

    // The test binding reports a null lifecycle state, which is exactly the
    // "not in front" case: the punch commits, but nothing is shown yet.
    await handlers.onBackgroundPunch!(const PunchTag(label: 'desk'));
    await tester.pumpAndSettle();

    expect(repo.savedDays, hasLength(1));
    expect(find.textContaining('Checked IN'), findsNothing);

    handlers.onResume();
    await tester.pump();

    expect(find.textContaining('Checked IN'), findsOneWidget);
    expect(find.textContaining('via desk tag'), findsOneWidget);

    // Let it time out: a bar still on screen at teardown leaves a pending
    // dismiss animation that asserts into the *next* test's first frame.
    await drainBanner(tester);
  });

  testWidgets('shows the banner at once when the app is already up', (
    tester,
  ) async {
    final repo = FakeDayRepository();
    final handlers = await pumpHome(tester, repo);
    // The cold-start case: Dart drains the launch payload with the app
    // already resumed, so there is somebody there to read the banner.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    await handlers.onBackgroundPunch!(const PunchTag(label: 'desk'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Checked IN'), findsOneWidget);

    // Nothing was held back, so a later resume adds no second bar. Counted
    // rather than waited out: what matters is that one banner exists, not
    // how long the first takes to fade.
    handlers.onResume();
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
    await drainBanner(tester);
  });

  testWidgets('a resume with nothing held shows nothing', (tester) async {
    final repo = FakeDayRepository();
    final handlers = await pumpHome(tester, repo);

    handlers.onResume();
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(repo.savedDays, isEmpty);
  });

  testWidgets('a held banner is shown once, not on every resume', (
    tester,
  ) async {
    final repo = FakeDayRepository();
    final handlers = await pumpHome(tester, repo);

    await handlers.onBackgroundPunch!(const PunchTag(label: 'desk'));
    await tester.pumpAndSettle();

    handlers.onResume();
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);

    // Coming forward again must not replay it: the held result was cleared
    // when it was first shown.
    handlers.onResume();
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
    await drainBanner(tester);
  });

  testWidgets('the guard refuses a tap moments after the last one', (
    tester,
  ) async {
    final repo = FakeDayRepository(
      days: <DayEntry>[
        DayEntry(
          dateKey: localDateKey(clock),
          checkIn: clock.subtract(const Duration(seconds: 20)),
        ),
      ],
    );
    final handlers = await pumpHome(tester, repo);

    await handlers.onBackgroundPunch!(const PunchTag(label: 'desk'));
    await tester.pumpAndSettle();

    expect(repo.savedDays, isEmpty);
    handlers.onResume();
    await tester.pump();
    expect(find.text('Ignored: you punched moments ago'), findsOneWidget);
    await drainBanner(tester);
  });

  testWidgets('a punch landing after disposal writes but shows nothing', (
    tester,
  ) async {
    final repo = FakeDayRepository();
    final handlers = await pumpHome(tester, repo);

    final punch = handlers.onBackgroundPunch!(const PunchTag(label: 'desk'));
    // The screen goes away mid-write, as it does when Android tears down an
    // activity that was only ever brought forward to service the tap.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await punch;
    await tester.pumpAndSettle();

    expect(repo.savedDays, hasLength(1));
    expect(find.byType(SnackBar), findsNothing);
  });
}
