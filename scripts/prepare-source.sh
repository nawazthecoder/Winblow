#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
build="$repo/.build"
upstream="$build/upstream.git"
revision=2c33741d50c5daab0521a098be5c969f63b9e887
patch="$repo/patches/winblow.patch"
graphics_patch="$repo/patches/graphics.patch"
digest="$( { printf '%s\n' "$revision"; cat "$patch" "$graphics_patch" "$repo/scripts/prepare-runtime.py" "$repo/scripts/prepare-graphics.py"; } | sha256sum | cut -c1-16 )"
source_dir="$build/engine-$digest"

mkdir -p "$build"
exec 9>"$build/prepare.lock"
flock 9
if [[ -d "$source_dir" ]]; then
    printf '%s\n' "$source_dir"
    exit 0
fi

if [[ ! -d "$upstream" ]]; then
    git init -q --bare "$upstream"
fi
if ! git -C "$upstream" cat-file -e "$revision^{commit}" 2>/dev/null; then
    git -C "$upstream" fetch --depth 1 https://github.com/brunodev85/winlator-app.git "$revision" >&2
fi

stage="$(mktemp -d "$build/.engine-XXXXXXXX")"
trap 'rm -rf -- "$stage"' EXIT
git -C "$upstream" archive "$revision" | tar -xf - --no-same-owner -C "$stage"
git -C "$stage" init -q
git -C "$stage" apply --check "$patch"
git -C "$stage" apply "$patch"
git -C "$stage" apply --check "$graphics_patch"
git -C "$stage" apply "$graphics_patch"
python3 "$repo/scripts/prepare-graphics.py" "$stage/app/src/main/assets" "$build/graphics-downloads" >&2
python3 "$repo/scripts/prepare-runtime.py" "$stage/app/src/main/assets" >&2
mv -- "$stage" "$source_dir"
printf '%s\n' "$source_dir"
