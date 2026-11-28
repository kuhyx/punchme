# CLAUDE.md

punchme: offline-first Flutter (Android-only) check-in app, Firebase-synced.
Pinned SDK in `.fvmrc`; use the `flutter` on PATH (git-env wrapper) or `fvm flutter`.
Hard bar: 100% line coverage (`scripts/ci_mirror.sh --coverage-only`).
Phone deploy: use the `phone-deploy` skill, never a hand-picked build number.

## Commands

- run: `flutter run --flavor daily` | needs an Android device
- test: `flutter test --reporter=failures-only`
- test-changed: `scripts/test_changed.sh`
- lint: n/a: dropped (kuhy, 2026-11-27)
- coverage: n/a: dropped (kuhy, 2026-11-27)
- coverage-gaps: n/a: dropped (kuhy, 2026-11-27)
- deploy: `git -C ~/src/punchme pull --ff-only && bash ~/src/punchme/scripts/deploy.sh` (Ship runs it after the push; release build of the `daily` flavor, `adb install -r` to the Pixel, launch, exits non-zero unless the app is running)
