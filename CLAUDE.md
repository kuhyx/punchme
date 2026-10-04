# CLAUDE.md

punchme: offline-first Flutter (Android-only) check-in app, Firebase-synced.
Pinned SDK in `.fvmrc`; use the `flutter` on PATH (git-env wrapper) or `fvm flutter`.
Hard bar: 100% line coverage (`scripts/ci_mirror.sh --coverage-only`).
Phone deploy: use the `phone-deploy` skill, never a hand-picked build number.

## Commands

- run: `flutter run --flavor daily` | needs an Android device
- test: `flutter test --reporter=failures-only`
- test-changed: `scripts/test_changed.sh`
- lint: `flutter analyze --fatal-infos --fatal-warnings && dart format --output=none --set-exit-if-changed lib/ test/`
- coverage: `flutter test --coverage -j "$(nproc)" --reporter=failures-only`
- coverage-gaps: `coverage-gaps coverage/lcov.info`
