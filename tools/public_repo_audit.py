#!/usr/bin/env python3
"""Reject proprietary inputs, private paths, and unsafe release layouts."""

from __future__ import annotations

import argparse
import hashlib
import pathlib
import re
import subprocess
import sys
import zipfile


FORBIDDEN_SOURCE_SUFFIXES = {
    ".bin", ".cue", ".iso", ".img", ".chd", ".ccd", ".sub",
    ".exe", ".dll", ".mcd", ".mcr", ".psxstate", ".jsonl",
    ".bmp", ".png", ".wav", ".mp4", ".mkv",
}
FORBIDDEN_PARTS = {
    "input", "generated", "captures", "traces", "cache", "saves",
    "release-stage", "local",
}
TEXT_SUFFIXES = {
    "", ".md", ".txt", ".toml", ".ini", ".py", ".ps1", ".bat", ".yml",
    ".yaml", ".cmake", ".json", ".gitignore", ".gitmodules",
}
PRIVATE_PATH_PATTERNS = (
    re.compile(rb"(?i)[a-z]:[\\/](?:projects|users|emulators)[\\/]"),
)
RELEASE_BINARY_MARKERS = (
    b"alexbeav", b"generated-disc1", b"z:/emulators", b"z:\\emulators",
)
AUDIT_IMPLEMENTATION_FILES = {
    "tools/public_repo_audit.py",
    "tools/test_public_repo_audit.py",
}
ALLOWED_KIT_FILES = {
    "README.md",
    "SETUP.ps1",
    "SETUP.bat",
    "extract_boot_exe.py",
    "game.toml",
    "CMakeLists.txt",
    "settings.toml",
    "keybinds.ini",
    "seeds/functions.txt",
    "src/sf2_mods.c",
    "mods/packages/sf2.enhancements/1.0.0/manifest.toml",
    "LICENSE-psxrecomp",
    "THIRD_PARTY_ATTRIBUTION.md",
    "psxrecomp-cli/psxrecomp.exe",
    "psxrecomp-cli/libexec/psxrecomp-game.exe",
    "psxrecomp-cli/libexec/psxrecomp-bios.exe",
    "psxrecomp-cli/libexec/psxrecomp-toml.exe",
    "psxrecomp-cli/share/phase2_ghidra_seeds.json",
}
MAX_RELEASE_BYTES = 128 * 1024 * 1024


def fail(errors: list[str]) -> int:
    if not errors:
        print("public audit: PASS")
        return 0
    for error in errors:
        print(f"public audit: ERROR: {error}", file=sys.stderr)
    return 1


def private_path_hits(data: bytes) -> list[str]:
    return [pattern.pattern.decode("ascii", "replace")
            for pattern in PRIVATE_PATH_PATTERNS if pattern.search(data)]


def audit_root(root: pathlib.Path) -> int:
    errors: list[str] = []
    root = root.resolve()
    try:
        listed = subprocess.run(
            ["git", "-C", str(root), "ls-files", "--cached", "--others",
             "--exclude-standard", "-z"],
            check=True, stdout=subprocess.PIPE,
        ).stdout.decode("utf-8").split("\0")
        candidates = [root / name for name in listed if name]
    except (OSError, subprocess.CalledProcessError, UnicodeDecodeError):
        candidates = list(root.rglob("*"))

    for path in sorted(candidates):
        rel = path.relative_to(root)
        if ".git" in rel.parts or "psxrecomp" in rel.parts:
            continue
        # A dirty pre-commit audit can contain index entries staged or marked
        # for deletion. Missing paths contribute no public payload.
        if not path.exists() or path.is_dir():
            continue
        if path.suffix.lower() in FORBIDDEN_SOURCE_SUFFIXES:
            errors.append(f"forbidden source file type: {rel.as_posix()}")
            continue
        if any(part.lower() in FORBIDDEN_PARTS for part in rel.parts):
            errors.append(f"forbidden source path: {rel.as_posix()}")
        if path.stat().st_size > 4 * 1024 * 1024:
            errors.append(f"unexpected large source file: {rel.as_posix()}")
        if (path.suffix.lower() in TEXT_SUFFIXES or path.name in {
            "CMakeLists.txt", "LICENSE",
        }) and rel.as_posix() not in AUDIT_IMPLEMENTATION_FILES:
            data = path.read_bytes()
            for hit in private_path_hits(data):
                errors.append(f"private path pattern {hit!r} in {rel.as_posix()}")

    config = root / "game.toml"
    if not config.is_file():
        errors.append("game.toml is missing")
    else:
        text = config.read_text(encoding="utf-8")
        if 'id = "SCUS-94451"' not in text:
            errors.append("game.toml does not identify SCUS-94451")
        disc = re.search(r'^disc\s*=\s*"([^"]+)"', text, re.MULTILINE)
        if not disc or pathlib.PureWindowsPath(disc.group(1)).is_absolute():
            errors.append("game.toml disc path must be present and relative")
    return fail(errors)


def audit_archive(archive: pathlib.Path) -> int:
    errors: list[str] = []
    total = 0
    with zipfile.ZipFile(archive) as zf:
        raw_files = [
            info.filename.replace("\\", "/").lstrip("./")
            for info in zf.infolist()
            if info.filename and not info.filename.endswith("/")
        ]
        first_parts = {pathlib.PurePosixPath(name).parts[0] for name in raw_files}
        has_wrapper = (
            len(first_parts) == 1
            and next(iter(first_parts)).startswith("syphon-filter-2-recompiled-")
            and all(len(pathlib.PurePosixPath(name).parts) > 1 for name in raw_files)
        )
        files: set[str] = set()
        for info in zf.infolist():
            name = info.filename.replace("\\", "/").lstrip("./")
            if not name or name.endswith("/"):
                continue
            pure = pathlib.PurePosixPath(name)
            if pure.is_absolute() or ".." in pure.parts:
                errors.append(f"unsafe archive path: {name}")
                continue
            # A single optional product-named staging directory is allowed.
            rel = "/".join(pure.parts[1:]) if has_wrapper else name
            if rel not in ALLOWED_KIT_FILES:
                errors.append(f"unexpected kit file: {name}")
            files.add(rel)
            total += info.file_size
            if info.file_size > MAX_RELEASE_BYTES:
                errors.append(f"oversized release entry: {name}")
            data = zf.read(info)
            for hit in private_path_hits(data):
                errors.append(f"private path pattern {hit!r} in {name}")
            if rel.endswith(".exe"):
                folded = data.lower()
                for marker in RELEASE_BINARY_MARKERS:
                    if marker in folded:
                        errors.append(
                            f"private build marker {marker!r} in {name}")

        missing = ALLOWED_KIT_FILES - files
        if missing:
            errors.append("missing kit files: " + ", ".join(sorted(missing)))
    if total > MAX_RELEASE_BYTES:
        errors.append(f"release expands to {total} bytes (limit {MAX_RELEASE_BYTES})")
    print(f"release archive: {archive} ({total} uncompressed bytes)")
    return fail(errors)


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--root", type=pathlib.Path)
    group.add_argument("--archive", type=pathlib.Path)
    parser.add_argument("--sha256", action="store_true",
                        help="print SHA-256 after a successful archive audit")
    args = parser.parse_args()
    if args.root:
        return audit_root(args.root)
    result = audit_archive(args.archive)
    if result == 0 and args.sha256:
        digest = hashlib.sha256(args.archive.read_bytes()).hexdigest()
        print(f"{digest}  {args.archive.name}")
    return result


if __name__ == "__main__":
    raise SystemExit(main())
