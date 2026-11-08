#!/usr/bin/env bash
set -euo pipefail

apk="$1"
sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
tools="${sdk:?Set ANDROID_HOME}/build-tools/34.0.0"

"$tools/apksigner" verify --verbose "$apk"

python3 - "$apk" "$tools/aapt" <<'PY'
import io
import json
import struct
import tarfile
import subprocess
import sys
from zipfile import ZipFile

badging = subprocess.check_output([sys.argv[2], "dump", "badging", sys.argv[1]], text=True)
lines = {line.rstrip() for line in badging.splitlines()}
package = "package: name='com.winblowx' versionCode='34' versionName='0.2.0'"
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
        "assets/graphics_driver/gladio-1.1.tzst",
        "assets/graphics_driver/vortek-2.1.tzst",
        "assets/graphics_driver/zink-22.2.5.tzst",
        "assets/graphics_driver/turnip-24.1.0.tzst",
        "assets/graphics_driver/turnip-25.0.0.tzst",
        "assets/graphics_driver/turnip-26.0.3.tzst",
        "assets/graphics_driver/turnip-26.2.0.tzst",
        "assets/dxwrapper/dxvk-3.1.1.tzst",
        "assets/dxwrapper/vkd3d-3.1.tzst",
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
    for driver, version, name in (
        ("turnip", "24.1.0", "freedreno"), ("turnip", "25.0.0", "freedreno"),
        ("turnip", "26.0.3", "freedreno"), ("turnip", "26.2.0", "freedreno"),
        ("vortek", "2.1", "vortek"),
    ):
        archive = subprocess.check_output(["zstd", "-dc"],
            input=apk.read(f"assets/graphics_driver/{driver}-{version}.tzst"))
        with tarfile.open(fileobj=io.BytesIO(archive), mode="r:") as files:
            header = files.extractfile(f"./usr/lib/libvulkan_{name}.so").read(20)
            manifest = files.extractfile(f"./usr/share/vulkan/icd.d/{name}_icd.aarch64.json")
            library_path = json.load(manifest)["ICD"]["library_path"]
            if header[:6] != b"\\x7fELF\\x02\\x01" or struct.unpack_from("<H", header, 18)[0] != 183:
                raise SystemExit(f"Wrong ARM64 ELF architecture in {driver} {version}")
            if library_path != f"/data/data/com.winblowx/files/rootfs/lib/libvulkan_{name}.so":
                raise SystemExit(f"Invalid Winblow driver path in {driver} {version}")
    print("Winblow APK package, arm64 libraries and runtime assets verified.")
PY
