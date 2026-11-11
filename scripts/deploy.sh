#!/bin/bash

# ============================================================================
# Deploy punchme for real: fast-forward kuhy's checkout, release-build the
# shipping (daily) flavor, install it over the existing app on the Pixel and
# launch it. phone_deploy.sh never uninstalls or clears data and exits
# non-zero on any device, whitelist, signing or install problem. The health
# check here then demands a live process: an app that crashes on start fails
# the deploy instead of passing on "Success" from the installer.
# Idempotent: a rerun reinstalls the same build over the same data.
# ============================================================================

set -euo pipefail

readonly REPO="${PUNCHME_REPO:-$HOME/src/punchme}"
readonly PKG="com.kuhy.punchme"
readonly SERIAL="${ADB_SERIAL:-23181JEGR08034}"
readonly HEALTH_EXIT=50

git -C "$REPO" pull --ff-only
ADB_SERIAL="$SERIAL" bash "$HOME/.claude/scripts/phone_deploy.sh" "$REPO" --release --flavor daily

pid=$(adb -s "$SERIAL" shell pidof "$PKG" | tr -d '\r' || true)
if [[ -z $pid ]]; then
    echo "deploy: $PKG is not running after launch (exit $HEALTH_EXIT)" >&2
    exit "$HEALTH_EXIT"
fi
echo "deploy: $PKG running (pid $pid) at $(git -C "$REPO" rev-parse --short HEAD)"
