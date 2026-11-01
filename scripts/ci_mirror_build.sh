#!/bin/bash
# Sourced by ci_mirror.sh: the release build split into persisted gradle stages
# (pattern: ~/.claude/scripts/lib/phone_deploy_stages.sh).

readonly BUILD_FLAVOR=daily
readonly BUILD_VARIANT=DailyRelease
readonly BUILD_ABIS=android-arm,android-arm64,android-x64

# Plain ./gradlew would take the system JDK, whose jlink rejects AGP's transform.
flutter_jdk() {
    jq -r '."jdk-dir" // empty' "${XDG_CONFIG_HOME:-$HOME/.config}/flutter/settings" 2> /dev/null || true
}

build_config() {
    ensure_deps
    log "flutter build apk --config-only --release --flavor $BUILD_FLAVOR"
    env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE \
        flutter build apk --config-only --release --flavor "$BUILD_FLAVOR"
}

build_gradle() {
    local jdk
    jdk="$(flutter_jdk)"
    log "gradle $*"
    (cd "$REPO_DIR/android" && JAVA_HOME="${jdk:-${JAVA_HOME:-}}" ./gradlew --no-daemon --console=plain -q \
        -Dorg.gradle.jvmargs=-Xmx3G -Pkotlin.compiler.execution.strategy=in-process \
        "-Ptarget-platform=$BUILD_ABIS" -Ptarget=lib/main.dart \
        -Pbase-application-name=android.app.Application \
        -Pdart-obfuscation=false -Ptrack-widget-creation=false -Ptree-shake-icons=true "$@")
}

build_stage() {
    case "${1:-}" in
        config) build_config ;;
        dart) build_gradle ":app:compileFlutterBuild$BUILD_VARIANT" ;;
        kotlin) build_gradle ":app:compile${BUILD_VARIANT}Kotlin" ;;
        plugins) build_gradle compileReleaseJavaWithJavac ;;
        shrink) build_gradle ":app:minify${BUILD_VARIANT}WithR8" ;;
        assemble) build_gradle ":app:assemble$BUILD_VARIANT" -x ":app:lintVital$BUILD_VARIANT" ;;
        *) die "usage: ci_mirror.sh build-stage config|dart|kotlin|plugins|shrink|assemble" ;;
    esac
}
