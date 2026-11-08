#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
: "${sdk:?Set ANDROID_HOME to your Android SDK directory}"
export ANDROID_HOME="$sdk"

source_dir="$(bash "$repo/scripts/prepare-source.sh")"
(
    cd "$source_dir"
    bash ./gradlew --no-daemon --console=plain \
        "-Dorg.gradle.jvmargs=${WINBLOW_GRADLE_JVM_ARGS:--Xmx2048m -Dfile.encoding=UTF-8}" \
        :app:assembleDebug "$@"
)

mkdir -p "$repo/dist"
apk="$repo/dist/Winblow-0.3.0-arm64.apk"
cp "$source_dir/app/build/outputs/apk/debug/app-debug.apk" "$apk"
bash "$repo/scripts/verify-apk.sh" "$apk"
printf '\n%s\n' "$apk"
