#!/usr/bin/env python3
"""Package verified upstream graphics releases for offline use in Winblow."""

import argparse
import hashlib
import io
from pathlib import Path
import shutil
import struct
import subprocess
import tarfile

TURNIP_BASE = (
    "https://raw.githubusercontent.com/brunodev85/winlator/"
    "30aafbdb9eea47b92669201621e03cd2cf04540d/installable_components/turnip"
)
TURNIP = {
    "24.1.0": "96989279ac6e440f1c2ae73dbf7bee05b754345fa45dee905822e2a5e97576a4",
    "25.0.0": "4a57d0fe980b3685a0e36326de8bf9d30de86075fa4e934213b8b8cfde8f492e",
    "26.0.3": "085e05496ccf5056249d96f59f51d1ec3521fe52106e7926ad08c00dbe75c9c1",
}
DXVK_URL = "https://github.com/doitsujin/dxvk/releases/download/v3.1.1/dxvk-3.1.1.tar.gz"
DXVK_HASH = "40565b4a724aadc4433fa4e010b4b23916d9b1f1baeee64e17186db94f54e608"
VKD3D_URL = "https://github.com/HansKristian-Work/vkd3d-proton/releases/download/v3.1/vkd3d-proton-3.1.tar.zst"
VKD3D_HASH = "b85ea8219b71093a3924913dd7aae6172333dc0c069983ed510816d67f02120b"


def fetch(cache, url, digest):
    path = cache / url.rsplit("/", 1)[-1]
    if path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() == digest:
        return path
    temporary = path.with_suffix(".part")
    try:
        subprocess.run(["curl", "--fail", "--location", "--retry", "3", "--silent", "--show-error",
                        "--connect-timeout", "15", "--max-time", "120", "--output", str(temporary), url],
                       check=True)
        if hashlib.sha256(temporary.read_bytes()).hexdigest() != digest:
            raise RuntimeError(f"Hash mismatch for {path.name}")
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)
    return path


def dll_bytes(archive, path, machine):
    member = archive.getmember(path)
    if not member.isfile():
        raise RuntimeError(f"Expected a file at {path}")
    with archive.extractfile(member) as stream:
        binary = stream.read()
    if len(binary) < 64 or binary[:2] != b"MZ":
        raise RuntimeError(f"Missing PE header in {path}")
    pe = struct.unpack_from("<I", binary, 0x3C)[0]
    if pe < 64 or pe > len(binary) - 24 or binary[pe:pe + 4] != b"PE\0\0":
        raise RuntimeError(f"Invalid PE header in {path}")
    if struct.unpack_from("<H", binary, pe + 4)[0] != machine:
        raise RuntimeError(f"Wrong Windows architecture in {path}")
    if not struct.unpack_from("<H", binary, pe + 22)[0] & 0x2000:
        raise RuntimeError(f"Expected a DLL at {path}")
    return binary


def pack_dlls(upstream, output, prefix, x86_dir, names):
    with io.BytesIO() as payload:
        with tarfile.open(fileobj=payload, mode="w", format=tarfile.GNU_FORMAT) as archive:
            for arch, target, machine in (("x64", "system32", 0x8664), (x86_dir, "syswow64", 0x014C)):
                directory = tarfile.TarInfo(target)
                directory.type = tarfile.DIRTYPE
                directory.mode = 0o755
                archive.addfile(directory)
                for name in names:
                    data = dll_bytes(upstream, f"{prefix}/{arch}/{name}", machine)
                    member = tarfile.TarInfo(f"{target}/{name}")
                    member.size = len(data)
                    member.mode = 0o644
                    archive.addfile(member, io.BytesIO(data))
        with output.open("wb") as stream:
            subprocess.run(["zstd", "-q", "-12", "-c"], input=payload.getvalue(), stdout=stream, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("assets", type=Path)
    parser.add_argument("cache", type=Path)
    args = parser.parse_args()
    args.cache.mkdir(parents=True, exist_ok=True)
    licenses = args.assets / "licenses"
    licenses.mkdir(exist_ok=True)
    shutil.copyfile(args.assets.parents[3] / "LICENSE", licenses / "Winblow-LGPL-2.1.txt")
    for version, digest in TURNIP.items():
        name = f"turnip-{version}.tzst"
        shutil.copyfile(fetch(args.cache, f"{TURNIP_BASE}/{name}", digest),
                        args.assets / "graphics_driver" / name)
    with tarfile.open(fetch(args.cache, DXVK_URL, DXVK_HASH), "r:gz") as dxvk:
        pack_dlls(dxvk, args.assets / "dxwrapper/dxvk-3.1.1.tzst", "dxvk-3.1.1", "x32",
                  ("d3d8.dll", "d3d9.dll", "d3d10core.dll", "d3d11.dll", "dxgi.dll"))
    payload = subprocess.check_output(["zstd", "-dc", "--", str(fetch(args.cache, VKD3D_URL, VKD3D_HASH))])
    with tarfile.open(fileobj=io.BytesIO(payload), mode="r:") as vkd3d:
        pack_dlls(vkd3d, args.assets / "dxwrapper/vkd3d-3.1.tzst", "vkd3d-proton-3.1", "x86",
                  ("d3d12.dll", "d3d12core.dll"))
    (args.assets / "graphics-source-notices.txt").write_text(
        "Mesa Turnip bundles were packaged by Winlator.\n" + TURNIP_BASE + "\n"
        "Mesa source\nhttps://gitlab.freedesktop.org/mesa/mesa\n\n"
        "DXVK 3.1.1 by the DXVK contributors uses the zlib license.\n"
        "https://github.com/doitsujin/dxvk/tree/v3.1.1\n\n"
        "VKD3D-Proton 3.1 by its contributors uses the LGPL.\n"
        "https://github.com/HansKristian-Work/vkd3d-proton/tree/v3.1\n", encoding="utf-8")
    print("Verified the additional Turnip, DXVK and VKD3D-Proton packages.")


if __name__ == "__main__":
    main()
