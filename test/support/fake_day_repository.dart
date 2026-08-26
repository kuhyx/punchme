import 'package:punchme/data/day_repository.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/settings.dart';

/// An in-memory [DayRepository] for widget tests.
class FakeDayRepository implements DayRepository {
  /// Creates a fake pre-loaded with [days] and [settings].
  FakeDayRepository({
    List<DayEntry> days = const <DayEntry>[],
    Settings settings = const Settings(),
  }) : _days = List<DayEntry>.of(days),
       _settings = settings;

  List<DayEntry> _days;
  Settings _settings;

  /// Days saved via [saveDay], in call order.
  final List<DayEntry> savedDays = <DayEntry>[];

  /// Date keys passed to [deleteDay], in call order.
  final List<String> deletedKeys = <String>[];

  /// Settings saved via [saveSettings], in call order.
  final List<Settings> savedSettings = <Settings>[];

  @override
  Future<List<DayEntry>> loadDays() async =>
      List<DayEntry>.of(_days)..sort((a, b) => a.dateKey.compareTo(b.dateKey));

  @override
  Future<void> saveDay(DayEntry entry) async {
    savedDays.add(entry);
    _days = upsertDay(_days, entry);
  }

  @override
  Future<void> deleteDay(String dateKey) async {
    deletedKeys.add(dateKey);
    _days = <DayEntry>[
      for (final day in _days)
        if (day.dateKey != dateKey) day,
    ];
  }

  @override
  Future<Settings> loadSettings() async => _settings;

  @override
  Future<void> saveSettings(Settings settings) async {
    savedSettings.add(settings);
    _settings = settings;
  }
}
