"""Extract SCUS_944.51 from a user-supplied Syphon Filter 2 Disc 1 dump."""

from __future__ import annotations

import hashlib
import io
import pathlib
import re
import sys


EXPECTED_SHA256 = "75a360bf7465dfdec85c14f9ba93862aae2531b48d83fd8d82ba8c9fffa13d33"
BOOT_PATH = "/SCUS_944.51;1"
RAW_SECTOR = 2352
DATA_OFFSET = 24
DATA_SIZE = 2048


def data_track_bin(cue: pathlib.Path) -> pathlib.Path:
    text = cue.read_text(encoding="utf-8", errors="replace")
    match = re.search(r'FILE\s+"([^"]+)"\s+BINARY', text, re.IGNORECASE)
    if not match:
        raise SystemExit("no BINARY FILE entry found in CUE")
    path = cue.parent / match.group(1)
    if not path.is_file():
        raise SystemExit(f"CUE data track not found: {path}")
    return path


def iso_view(bin_path: pathlib.Path) -> io.BytesIO:
    out = io.BytesIO()
    with bin_path.open("rb") as source:
        while sector := source.read(RAW_SECTOR):
            if len(sector) != RAW_SECTOR:
                raise SystemExit("truncated MODE2/2352 sector in data track")
            out.write(sector[DATA_OFFSET:DATA_OFFSET + DATA_SIZE])
    out.seek(0)
    return out


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: extract_boot_exe.py <disc1.cue> <output-directory>")
        return 2
    cue = pathlib.Path(sys.argv[1]).resolve()
    output = pathlib.Path(sys.argv[2]).resolve()
    output.mkdir(parents=True, exist_ok=True)

    import pycdlib

    image = pycdlib.PyCdlib()
    image.open_fp(iso_view(data_track_bin(cue)))
    extracted = io.BytesIO()
    image.get_file_from_iso_fp(extracted, iso_path=BOOT_PATH)
    image.close()

    data = extracted.getvalue()
    digest = hashlib.sha256(data).hexdigest()
    target = output / "SCUS_944.51"
    target.write_bytes(data)
    print(f"extracted {target} ({len(data)} bytes)")
    print(f"sha256 {digest}")
    if digest != EXPECTED_SHA256:
        print("WARNING: executable differs from the verified USA revision; "
              "this recipe is revision-specific.")
        return 1
    print("hash matches the verified SCUS-94451 revision")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
