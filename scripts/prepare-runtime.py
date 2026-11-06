#!/usr/bin/env python3
"""Relocate Winlator's pinned glibc runtime to the Winblow Android package."""

import argparse
import io
from pathlib import Path
import subprocess
import tarfile
import tempfile

UPSTREAM_PATH = b"/data/data/com.winlator"
WINBLOW_PATH = b"/data/data/com.winblowx"


def omit_member(archive, name):
    if archive != "rootfs_patches.tzst":
        return False
    path = name.lower()
    return "/drive_c/windows/fonts/" in path or path.endswith("/syswow64/mfc42.dll")


def relocate_archive(path):
    # Several guest ELF binaries contain this prefix in PT_INTERP and RPATH.
    # Keep both paths the same byte length so the ELF offsets stay intact.
    changed = 0
    with tempfile.TemporaryFile() as new_tar:
        with subprocess.Popen(["zstd", "-dc", "--", str(path)], stdout=subprocess.PIPE) as decoder:
            with tarfile.open(fileobj=decoder.stdout, mode="r|") as original, tarfile.open(
                fileobj=new_tar, mode="w|", format=tarfile.PAX_FORMAT
            ) as replacement:
                for member in original:
                    if omit_member(path.name, member.name):
                        changed += 1
                        continue
                    for attr in ("name", "linkname"):
                        value = getattr(member, attr)
                        relocated = value.replace(UPSTREAM_PATH.decode(), WINBLOW_PATH.decode())
                        if value != relocated:
                            changed += 1
                            setattr(member, attr, relocated)
                    for key in ("path", "linkpath"):
                        if key in member.pax_headers:
                            member.pax_headers[key] = member.pax_headers[key].replace(
                                UPSTREAM_PATH.decode(), WINBLOW_PATH.decode()
                            )
                    data = None
                    if member.isfile():
                        with original.extractfile(member) as file:
                            contents = file.read()
                        changed += contents.count(UPSTREAM_PATH)
                        data = io.BytesIO(contents.replace(UPSTREAM_PATH, WINBLOW_PATH))
                    replacement.addfile(member, data)
            decoder.stdout.read()
            if decoder.wait() != 0:
                raise RuntimeError(f"Could not decompress {path}")

        if changed:
            new_tar.seek(0)
            output = path.with_suffix(".new")
            try:
                with output.open("wb") as result:
                    subprocess.run(["zstd", "-q", "-9", "-c"], stdin=new_tar, stdout=result, check=True)
                output.replace(path)
            finally:
                output.unlink(missing_ok=True)
            print(f"{path.name}: {changed} changes")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("assets", type=Path)
    args = parser.parse_args()
    if len(UPSTREAM_PATH) != len(WINBLOW_PATH):
        raise RuntimeError("The guest paths must have identical byte lengths")

    # Winblow uses Wine's built-in DLLs. Installers can supply their own runtimes.
    for archive in (args.assets / "wincomponents").glob("*.tzst"):
        archive.unlink()

    for archive in sorted(args.assets.rglob("*.tzst")):
        relocate_archive(archive)


if __name__ == "__main__":
    main()
