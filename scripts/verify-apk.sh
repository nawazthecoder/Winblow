#!/usr/bin/env bash
set -euo pipefail

apk="$1"
sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
tools="${sdk:?Set ANDROID_HOME}/build-tools/34.0.0"

"$tools/apksigner" verify --verbose "$apk"

python3 - "$apk" "$tools/aapt" <<'PY'
import struct
import subprocess
import sys
from zipfile import ZipFile

badging = subprocess.check_output([sys.argv[2], "dump", "badging", sys.argv[1]], text=True)
lines = {line.rstrip() for line in badging.splitlines()}
package = "package: name='com.winblowx' versionCode='1' versionName='0.1.0'"
if not any(line.startswith(package) for line in lines):
    raise SystemExit("Unexpected Winblow package name or version")
if "application-label:'Winblow'" not in lines or "native-code: 'arm64-v8a'" not in lines:
    raise SystemExit("Unexpected Winblow label or ABI")

with ZipFile(sys.argv[1]) as apk:
    bad = apk.testzip()
    if bad is not None:
        raise SystemExit(f"Corrupt APK member: {bad}")
    for name in (
        "assets/rootfs.tzst",
        "assets/rootfs_patches.tzst",
        "assets/container_pattern.tzst",
        "assets/box64/box64-0.4.4.tzst",
        "assets/graphics_driver/virgl-23.1.9.tzst",
        "classes.dex",
    ):
        if apk.getinfo(name).file_size == 0:
            raise SystemExit(f"Empty APK member: {name}")
    for lib in ("winlator", "vortekrenderer", "virglrenderer", "gladiorenderer"):
        with apk.open(f"lib/arm64-v8a/lib{lib}.so") as elf:
            header = elf.read(20)
            if header[:6] != b"\x7fELF\x02\x01" or struct.unpack_from("<H", header, 18)[0] != 183:
                raise SystemExit(f"Wrong ELF architecture: {lib}")
    if any(n.startswith("assets/wincomponents/") and n.endswith(".tzst") for n in apk.namelist()):
        raise SystemExit("The APK contains native Windows component archives")
    print("Winblow APK package, arm64 libraries and runtime assets verified.")
PY
