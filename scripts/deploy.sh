#!/bin/bash

# ============================================================================
# Deploy punchme for real (the CLAUDE.md deploy line pulls ~/src/punchme
# with --ff-only first; one network step, not two): release-build the
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
# Ship and systemd-run do not source ~/.zshenv, where ANDROID_HOME lives;
# without it phone_deploy cannot find apksigner and refuses (exit 41).
# Outside a Claude session each phone_lease call falls back to its own
# pid:<n> owner, so phone_deploy's launch step blocked on phone_deploy's own
# package lease (exit 35). A fixed owner (no pid) also lets a rerun reuse
# the previous run's still-live lease instead of waiting it out (exit 40).
export PHONE_LEASE_OWNER="${PHONE_LEASE_OWNER:-deploy:punchme}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/sdk/foss-android-sdk}"
# phone_deploy refuses (exit 48) above PHONE_DEPLOY_MAX_LOAD; Ship runs this
# right after a push, often while other builds still load the box, so wait
# for headroom (bounded) instead of failing on a transient spike.
readonly MAX_LOAD="${PHONE_DEPLOY_MAX_LOAD:-40}"
readonly LOAD_WAIT_SECS="${DEPLOY_LOAD_WAIT_SECS:-1200}"

wait_for_load() {
    local waited=0 load
    while :; do
        read -r load _ </proc/loadavg
        awk -v l="$load" -v m="$MAX_LOAD" 'BEGIN { exit !(l < m) }' && return 0
        (( waited >= LOAD_WAIT_SECS )) && return 0  # let phone_deploy refuse loudly
        sleep 15
        waited=$((waited + 15))
    done
}

wait_for_load

ADB_SERIAL="$SERIAL" bash "$HOME/.claude/scripts/phone_deploy.sh" "$REPO" --release --flavor daily

pid=$(adb -s "$SERIAL" shell pidof "$PKG" | tr -d '\r' || true)
if [[ -z $pid ]]; then
    echo "deploy: $PKG is not running after launch (exit $HEALTH_EXIT)" >&2
    exit "$HEALTH_EXIT"
fi
echo "deploy: $PKG running (pid $pid) at $(git -C "$REPO" rev-parse --short HEAD)"
