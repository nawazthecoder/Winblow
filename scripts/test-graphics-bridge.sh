#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
source_dir="${WINBLOW_TEST_SOURCE:-$(bash "$repo/scripts/prepare-source.sh")}"
tests="$(mktemp -d)"
trap 'rm -rf -- "$tests"' EXIT
flags=()
[[ -z "${WINBLOW_GL_INCLUDE:-}" ]] || flags+=(-I"$WINBLOW_GL_INCLUDE")
[[ -z "${WINBLOW_GL_LIBDIR:-}" ]] || flags+=(-L"$WINBLOW_GL_LIBDIR" -Wl,-rpath,"$WINBLOW_GL_LIBDIR")
cc -std=c11 -O2 -Wall -Wextra -Werror "${flags[@]}" \
    -I"$source_dir/app/src/main/cpp/winlator/include" \
    "$repo/tests/graphics_bridge_test.c" "$source_dir/app/src/main/cpp/winlator/src/graphics_bridge.c" \
    -l:libEGL.so.1 -l:libGLESv2.so.2 -o "$tests/graphics-bridge-test"
LIBGL_ALWAYS_SOFTWARE=1 EGL_PLATFORM=surfaceless "$tests/graphics-bridge-test"
