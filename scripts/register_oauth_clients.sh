#!/bin/bash

# ============================================================================
# Walks the one step that cannot be automated -- registering punchme's Android
# OAuth clients -- and runs everything around it that can be.
#
# Why a human has to click: an OAuth client is a credential, and Google
# exposes no create API for one. `gcloud` has no command, the Firebase CLI has
# no command, and the console is the only path. Everything either side of that
# click is done here.
#
# What this does for you:
#   * derives the SHA-1 from the real keystore, so the value pasted into the
#     console cannot be a stale copy of one;
#   * opens the console on the right page and puts each field on the clipboard
#     in the order the form asks for it;
#   * waits, then verifies on the phone -- taps Connect, reads the tile, and
#     checks the record actually landed in the database.
# ============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_DIR
readonly CONSOLE_URL="https://console.cloud.google.com/auth/clients?project=kuhy-syncs"
readonly PACKAGE="com.kuhy.punchme"
readonly SANDBOX_PACKAGE="com.kuhy.punchme.sandbox"
readonly DEVICE="23181JEGR08034"

log() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
step() { printf '   %s\n' "$1"; }

# Copies to the clipboard when a tool is available; prints regardless, so the
# script still works over ssh with no X display.
clip() {
    if command -v xclip >/dev/null 2>&1; then
        printf '%s' "$1" | xclip -selection clipboard 2>/dev/null || true
        printf '   \033[32m[copied]\033[0m %s\n' "$1"
    else
        printf '   %s\n' "$1"
    fi
}

# Waits for the user to press Enter before moving to the next field.
pause() { read -rp "   ...press Enter when that field is filled " _; }

# Reads the release signing fingerprint out of the keystore itself.
#
# Derived rather than hardcoded: a fingerprint copied into a doc goes stale
# silently, and the failure it causes (UNREGISTERED_ON_API_CONSOLE) looks
# nothing like "you pasted the wrong SHA-1".
release_sha1() {
    local properties="$REPO_DIR/android/key.properties"
    if [[ ! -f "$properties" ]]; then
        echo "error: $properties not found; cannot derive the SHA-1" >&2
        return 1
    fi
    local store password alias
    store="$(grep -E '^storeFile=' "$properties" | cut -d= -f2-)"
    password="$(grep -E '^storePassword=' "$properties" | cut -d= -f2-)"
    alias="$(grep -E '^keyAlias=' "$properties" | cut -d= -f2-)"
    # key.properties may hold a path relative to android/.
    [[ "$store" = /* ]] || store="$REPO_DIR/android/$store"
    keytool -list -v -keystore "$store" -alias "$alias" \
        -storepass "$password" 2>/dev/null |
        grep -E '^\s*SHA1:' | head -1 | sed 's/.*SHA1: //' | tr -d ' \r'
}

# Taps "Connect Google account" in Settings, from the accessibility tree.
#
# Coordinates are looked up rather than hardcoded: `adb shell screencap` is
# downscaled on this device, so a tap aimed at a screenshot pixel lands at
# roughly double the intended y and has hit the punch button before now.
tap_connect() {
    step "opening Settings and tapping Connect"
    adb shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1 \
        >/dev/null 2>&1
    sleep 5
    adb shell input tap 1017 206 >/dev/null 2>&1   # the Settings gear
    sleep 3

    # Scroll until the tile is on screen rather than a fixed number of times:
    # the free-days calendar grows with the month, so a count that works in
    # August is short in a month with more rows.
    local xml=/tmp/punch_ui.xml coords="" _attempt
    for _attempt in 1 2 3 4 5 6; do
        adb shell uiautomator dump /sdcard/punch_ui.xml >/dev/null 2>&1
        adb pull /sdcard/punch_ui.xml "$xml" >/dev/null 2>&1
        coords="$(python3 "$REPO_DIR/scripts/find_tile.py" "$xml" 2>/dev/null || true)"
        [[ -n "$coords" ]] && break
        adb shell input swipe 540 1800 540 700 400 >/dev/null 2>&1
        sleep 2
    done
    if [[ -z "$coords" ]]; then
        step "could not find the Connect tile; tap it by hand, then rerun"
        return 1
    fi
    step "found the tile at ($coords)"
    # Two arguments, so split deliberately rather than passed as one string.
    local tile_x tile_y
    read -r tile_x tile_y <<<"$coords"
    adb shell input tap "$tile_x" "$tile_y" >/dev/null 2>&1
    sleep 5
    step "account picker should be open — pick 321krzychu@gmail.com on the phone"
    read -rp "   ...press Enter once you have picked the account " _
}

# Verifies on the phone: taps Connect, then asks the device whether it synced.
verify_on_phone() {
    log "Verifying on the phone"
    if ! adb devices | grep -q "^$DEVICE"; then
        step "phone not attached; reconnect it and rerun with --verify-only"
        return 1
    fi
    tap_connect || true
    step "running the sync check"
    adb shell am broadcast -a com.kuhy.punchme.SYNCCHECK \
        -p "$PACKAGE" -f 0x01000000 >/dev/null 2>&1
    sleep 8
    local out="/tmp/punch_sync_check.json"
    adb pull "/sdcard/Android/data/$PACKAGE/files/punch_sync_check.json" \
        "$out" >/dev/null 2>&1
    printf '\n'
    cat "$out"
    printf '\n'
    if grep -q '"present": true' "$out"; then
        log "SYNCED — a record is present in the database."
    else
        log "NOT SYNCED YET — tap 'Connect Google account' in Settings, then"
        step "rerun: bash scripts/register_oauth_clients.sh --verify-only"
    fi
}

main() {
    if [[ "${1:-}" == "--verify-only" ]]; then
        verify_on_phone
        return
    fi

    local sha1
    sha1="$(release_sha1)"

    log "Register two Android OAuth clients in project kuhy-syncs"
    step "Google has no API for this. Two forms, four fields each."
    printf '\n'

    step "Opening the console..."
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$CONSOLE_URL" >/dev/null 2>&1 &
    else
        step "$CONSOLE_URL"
    fi
    sleep 2

    printf '\n\033[1m--- CLIENT 1 of 2: the daily build ---\033[0m\n'
    step "Click '+ CREATE CLIENT', set Application type = Android."
    printf '\n'
    step "Field 'Name':"
    clip "punchme daily"
    pause
    step "Field 'Package name':"
    clip "$PACKAGE"
    pause
    step "Field 'SHA-1 certificate fingerprint':"
    clip "$sha1"
    pause
    step "Click CREATE."
    pause

    printf '\n\033[1m--- CLIENT 2 of 2: the sandbox build ---\033[0m\n'
    step "Click '+ CREATE CLIENT' again, Application type = Android."
    printf '\n'
    step "Field 'Name':"
    clip "punchme sandbox"
    pause
    step "Field 'Package name':"
    clip "$SANDBOX_PACKAGE"
    pause
    step "Field 'SHA-1 certificate fingerprint' (same as before):"
    clip "$sha1"
    pause
    step "Click CREATE."
    pause

    log "Done in the console. Do NOT touch the existing Web client."
    step "It is already the audience punchme's tokens are minted for."

    printf '\n'
    read -rp "   Registration can take a minute to propagate. Enter to verify: " _
    verify_on_phone
}

main "$@"
