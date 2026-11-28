#!/bin/bash

# ============================================================================
# CI mirror: reproduce what CI runs, locally, before push.
#
# `flutter clean` first, for the same reason the Python repos build a throwaway
# venv: a stale incremental build can hide a real failure, and a pre-push gate
# that only passes on an already-warm tree is not a gate.
#
# One check here has no equivalent in the sibling Flutter repos:
#   * `flutter build apk --release --flavor daily`, the shipping artefact.
#     Flavor-explicit since the sandbox split: a bare `build apk` writes
#     app-daily-release.apk and then fails looking for app-release.apk. This
#     repo is Android-only, so there is no web build to guard `dart:io` with
#     -- and no need for one, since dart:io is legal in lib/ here.
# ============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_DIR

# shellcheck disable=SC2034  # read by ci_mirror_shards.sh
readonly GATE_SHARDS=6

log() { printf '==> %s\n' "$1"; }

# shellcheck source=/dev/null
source "$REPO_DIR/scripts/ci_mirror_shards.sh"
# shellcheck source=/dev/null
source "$REPO_DIR/scripts/ci_mirror_build.sh"

phase_setup() {
    log "flutter clean"
    flutter clean
    ensure_deps
}

ensure_deps() {
    log "flutter pub get"
    flutter pub get
}

phase_format() {
    log "dart format --set-exit-if-changed"
    dart format --set-exit-if-changed lib/ test/
}

# `--flavor daily`: a bare `build apk` fails looking for app-release.apk. CI runs
# the same line; a gate that builds differently is not a gate.
phase_build() {
    ensure_deps
    log "flutter build apk --release --flavor daily"
    flutter build apk --release --flavor daily
}

main() {
    cd "$REPO_DIR"

    case "${1:-all}" in
        all)
            phase_setup
            phase_format
            log "flutter test"
            flutter test
            phase_build
            ;;
        setup) phase_setup ;;
        format) phase_format ;;
        test)
            [[ "${2:-}" == "--shard" ]] || die "usage: ci_mirror.sh test --shard I/N"
            ensure_deps
            test_shard "${3:-}"
            ;;
        build) phase_build ;;
        build-stage) build_stage "${2:-}" ;;
        *) die "unknown phase '$1' (all|setup|format|test --shard I/N|build|build-stage config|dart|kotlin|plugins|shrink|assemble)" ;;
    esac

    echo "CI mirror ${1:-all} passed."
}

main "$@"
