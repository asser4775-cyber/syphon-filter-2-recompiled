"""Extract SCUS_944.51 from a user-supplied Syphon Filter 2 Disc 1 dump.

This intentionally uses only Python's standard library so the owned-input kit
does not need pip or a package-index download during setup.
"""

from __future__ import annotations

import hashlib
import pathlib
import re
import sys


EXPECTED_SHA256 = "75a360bf7465dfdec85c14f9ba93862aae2531b48d83fd8d82ba8c9fffa13d33"
BOOT_PATH = "SCUS_944.51;1"
RAW_SECTOR = 2352
DATA_OFFSET = 24
DATA_SIZE = 2048


def data_track_bin(cue: pathlib.Path) -> pathlib.Path:
    text = cue.read_text(encoding="utf-8", errors="replace")
    match = re.search(r'FILE\s+"([^"]+)"\s+BINARY', text, re.IGNORECASE)
    if not match:
        raise SystemExit("no quoted BINARY FILE entry found in CUE")
    path = cue.parent / match.group(1)
    if not path.is_file():
        raise SystemExit(f"CUE data track not found: {path}")
    return path


def read_user_sector(source, lba: int) -> bytes:
    source.seek(lba * RAW_SECTOR + DATA_OFFSET)
    data = source.read(DATA_SIZE)
    if len(data) != DATA_SIZE:
        raise SystemExit(f"truncated MODE2/2352 data track at LBA {lba}")
    return data


def directory_extent(record: bytes) -> tuple[int, int]:
    if len(record) < 34 or record[0] < 34:
        raise SystemExit("invalid ISO9660 directory record")
    return (
        int.from_bytes(record[2:6], "little"),
        int.from_bytes(record[10:14], "little"),
    )


def find_root_file(source, filename: str) -> tuple[int, int]:
    pvd = read_user_sector(source, 16)
    if pvd[:7] != b"\x01CD001\x01":
        raise SystemExit("Disc 1 data track does not contain an ISO9660 primary volume descriptor")
    root_length = pvd[156]
    root_lba, root_size = directory_extent(pvd[156:156 + root_length])

    directory = bytearray()
    for offset in range(0, root_size, DATA_SIZE):
        directory.extend(read_user_sector(source, root_lba + offset // DATA_SIZE))
    directory = directory[:root_size]

    wanted = filename.upper().encode("ascii")
    offset = 0
    while offset < len(directory):
        record_length = directory[offset]
        if record_length == 0:
            offset = ((offset // DATA_SIZE) + 1) * DATA_SIZE
            continue
        record = bytes(directory[offset:offset + record_length])
        if len(record) != record_length or record_length < 34:
            raise SystemExit("truncated ISO9660 root directory record")
        name_length = record[32]
        name = record[33:33 + name_length].upper()
        if name == wanted:
            return directory_extent(record)
        offset += record_length
    raise SystemExit(f"{filename} was not found in the Disc 1 root directory")


def extract_iso_file(cue: pathlib.Path, filename: str) -> bytes:
    with data_track_bin(cue).open("rb") as source:
        file_lba, file_size = find_root_file(source, filename)
        result = bytearray()
        for offset in range(0, file_size, DATA_SIZE):
            result.extend(read_user_sector(source, file_lba + offset // DATA_SIZE))
        return bytes(result[:file_size])


def main(argv: list[str] | None = None) -> int:
    args = sys.argv[1:] if argv is None else argv
    if len(args) != 2:
        print("usage: extract_boot_exe.py <disc1.cue> <output-directory>")
        return 2
    cue = pathlib.Path(args[0]).resolve()
    output = pathlib.Path(args[1]).resolve()
    output.mkdir(parents=True, exist_ok=True)

    data = extract_iso_file(cue, BOOT_PATH)
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
