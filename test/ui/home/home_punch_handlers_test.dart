import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/nfc/punch_tag.dart';
import 'package:punchme/ui/home/home_punch_handlers.dart';

/// The optional halves of the seam.
///
/// Both defaults exist so a caller wiring only the foreground path does not
/// have to stand up the platform channel; that they are genuinely harmless is
/// what is pinned here.
void main() {
  test('a background handler is absent unless one is supplied', () {
    final handlers = HomePunchHandlers(
      onPunch: (_) async {},
      onBlankTag: () {},
    );
    expect(handlers.onBackgroundPunch, isNull);
  });

  test('the default resume handler does nothing', () {
    final handlers = HomePunchHandlers(
      onPunch: (_) async {},
      onBlankTag: () {},
    );
    // Calling it must be safe: HomeWithNfc fires this on every resume,
    // including for a screen that never opted into background punches.
    expect(handlers.onResume, returnsNormally);
    handlers.onResume();
  });

  test('carries the handlers it was given', () async {
    final punches = <PunchTag>[];
    final background = <PunchTag>[];
    var resumed = 0;
    final handlers = HomePunchHandlers(
      onPunch: (tag) async => punches.add(tag),
      onBlankTag: () {},
      onBackgroundPunch: (tag) async => background.add(tag),
      onResume: () => resumed++,
    );

    await handlers.onPunch(const PunchTag(label: 'desk'));
    await handlers.onBackgroundPunch!(const PunchTag(label: 'door'));
    handlers.onResume();

    expect(punches, <PunchTag>[const PunchTag(label: 'desk')]);
    expect(background, <PunchTag>[const PunchTag(label: 'door')]);
    expect(resumed, 1);
  });
}
