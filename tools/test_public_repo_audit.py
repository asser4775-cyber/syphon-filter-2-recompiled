from __future__ import annotations

import contextlib
import io
import pathlib
import tempfile
import unittest
import zipfile

import public_repo_audit as audit


class ReleaseAuditTests(unittest.TestCase):
    def make_archive(self, extra: dict[str, bytes] | None = None) -> pathlib.Path:
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        path = pathlib.Path(temp.name) / "release.zip"
        files = {name: b"safe" for name in audit.ALLOWED_KIT_FILES}
        if extra:
            files.update(extra)
        with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as zf:
            for name, data in files.items():
                zf.writestr(name, data)
        return path

    def run_audit(self, path: pathlib.Path) -> int:
        with contextlib.redirect_stdout(io.StringIO()), \
             contextlib.redirect_stderr(io.StringIO()):
            return audit.audit_archive(path)

    def test_minimal_release_passes(self) -> None:
        self.assertEqual(self.run_audit(self.make_archive()), 0)

    def test_rejects_capture_payload(self) -> None:
        archive = self.make_archive({"overlay_captures.json": b"retail bytes"})
        self.assertEqual(self.run_audit(archive), 1)

    def test_rejects_private_path(self) -> None:
        archive = self.make_archive({"README.md": b"I:/Projects/private"})
        self.assertEqual(self.run_audit(archive), 1)

    def test_rejects_prebuilt_game_executable(self) -> None:
        archive = self.make_archive({
            "SyphonFilter2Recompiled.exe": b"MZ...retail-derived game",
        })
        self.assertEqual(self.run_audit(archive), 1)

    def test_rejects_zip_traversal(self) -> None:
        archive = self.make_archive({"../escape.txt": b"bad"})
        self.assertEqual(self.run_audit(archive), 1)


if __name__ == "__main__":
    unittest.main()
