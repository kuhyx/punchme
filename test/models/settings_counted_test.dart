import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/models/horizon.dart';
import 'package:punchme/models/settings.dart';

/// Settings.countedHorizons: which statistics cards steer today's target.
void main() {
  test('every card counts by default', () {
    expect(const Settings().countedHorizons, Settings.allHorizons);
  });

  test('copyWith replaces the counted cards', () {
    final changed = const Settings().copyWith(
      countedHorizons: const <Horizon>{Horizon.week},
    );
    expect(changed.countedHorizons, const <Horizon>{Horizon.week});
  });

  test('round-trips through JSON in card order', () {
    const settings = Settings(
      countedHorizons: <Horizon>{Horizon.year, Horizon.week},
    );
    final json = settings.toJson();
    expect(json['countedHorizons'], <String>['week', 'year']);
    expect(Settings.fromJson(json).countedHorizons, const <Horizon>{
      Horizon.week,
      Horizon.year,
    });
  });

  test('an empty list means nothing counts', () {
    final settings = Settings.fromJson(<String, dynamic>{
      'countedHorizons': <String>[],
    });
    expect(settings.countedHorizons, isEmpty);
  });

  test('a file from before the option counts every card', () {
    expect(
      Settings.fromJson(<String, dynamic>{}).countedHorizons,
      Settings.allHorizons,
    );
  });

  test('unknown names and non-strings are skipped', () {
    final settings = Settings.fromJson(<String, dynamic>{
      'countedHorizons': <Object>['week', 'decade', 7],
    });
    expect(settings.countedHorizons, const <Horizon>{Horizon.week});
  });

  test('each card has the title Statistics shows', () {
    expect(Horizon.values.map((h) => h.title), <String>[
      'This week',
      'This month',
      'This year',
    ]);
  });
}
