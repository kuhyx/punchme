/// The three stretches of time the statistics cards cover.
library;

/// A statistics card, or the stretch of days a surplus is spread over.
///
/// Declared narrowest first: target logic walks them in this order.
enum Horizon {
  /// This week.
  week,

  /// This month.
  month,

  /// This year.
  year;

  /// The card's title, shared by Statistics and Settings so the switch and
  /// the card it controls can never be named differently.
  String get title => switch (this) {
    week => 'This week',
    month => 'This month',
    year => 'This year',
  };
}
