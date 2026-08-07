from __future__ import annotations

import contextlib
import io
import os
import pathlib
import shutil
import subprocess
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

    def test_rejects_lf_only_batch_file(self) -> None:
        archive = self.make_archive({"SETUP.bat": b"@echo off\necho bad\n"})
        self.assertEqual(self.run_audit(archive), 1)

    def test_rejects_non_ascii_batch_file(self) -> None:
        archive = self.make_archive({"SETUP.bat": "@echo off\r\necho Γ\r\n".encode("utf-8")})
        self.assertEqual(self.run_audit(archive), 1)

    @unittest.skipUnless(shutil.which("pwsh"), "PowerShell is unavailable")
    def test_setup_auto_detects_disc1_beside_disc2(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            setup = pathlib.Path(__file__).parents[1] / "release" / "SETUP.ps1"
            shutil.copy2(setup, root / "SETUP.ps1")
            disc1 = root / "Syphon Filter 2 (USA) (Disc 1).cue"
            disc2 = root / "Syphon Filter 2 (USA) (Disc 2).cue"
            disc1.write_text("FILE disc1.bin BINARY\n", encoding="ascii")
            disc2.write_text("FILE disc2.bin BINARY\n", encoding="ascii")
            result = subprocess.run(
                ["pwsh", "-NoProfile", "-File", str(root / "SETUP.ps1"),
                 "-ResolveCueOnly"],
                check=True, text=True, stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            # Windows runners can expose the temporary directory through its
            # 8.3 alias while PowerShell reports the corresponding long path.
            # The selected filename is the behavior this regression protects.
            self.assertIn(disc1.name, result.stdout)
            self.assertNotIn(disc2.name, result.stdout)

    @unittest.skipUnless(os.name == "nt" and shutil.which("pwsh"),
                         "Windows PowerShell is unavailable")
    def test_setup_preflight_accepts_py_launcher_without_python_on_path(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            setup = pathlib.Path(__file__).parents[1] / "release" / "SETUP.ps1"
            shutil.copy2(setup, root / "SETUP.ps1")
            fake_bin = root / "toolchain" / "bin"
            fake_bin.mkdir(parents=True)
            for name in ("git", "cmake", "gcc", "g++", "ninja", "py"):
                body = "@echo off\r\nexit /b 0\r\n"
                if name == "py":
                    body = "@echo off\r\nif not \"%PYTHONUTF8%\"==\"1\" exit /b 9\r\nexit /b 0\r\n"
                (fake_bin / f"{name}.cmd").write_text(body, encoding="ascii")
            env = os.environ.copy()
            env["PATH"] = str(fake_bin) + os.pathsep + os.environ["SystemRoot"] + "\\System32"
            env["SF2_SETUP_DISABLE_STANDARD_DISCOVERY"] = "1"
            result = subprocess.run(
                [shutil.which("pwsh"), "-NoProfile", "-File", str(root / "SETUP.ps1"),
                 "-PreflightOnly", "-NoInstallDependencies"],
                check=True, text=True, stdout=subprocess.PIPE,
                stderr=subprocess.PIPE, env=env,
            )
            self.assertIn("Python:", result.stdout)
            self.assertIn("py.cmd -3", result.stdout)
            self.assertIn("Visual Studio is not required", result.stdout)

    @unittest.skipUnless(os.name == "nt" and shutil.which("pwsh"),
                         "Windows PowerShell is unavailable")
    def test_setup_preflight_names_missing_python(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            setup = pathlib.Path(__file__).parents[1] / "release" / "SETUP.ps1"
            shutil.copy2(setup, root / "SETUP.ps1")
            fake_bin = root / "toolchain" / "bin"
            fake_bin.mkdir(parents=True)
            for name in ("git", "cmake", "gcc", "g++", "ninja"):
                (fake_bin / f"{name}.cmd").write_text(
                    "@echo off\r\nexit /b 0\r\n", encoding="ascii"
                )
            env = os.environ.copy()
            env["PATH"] = str(fake_bin) + os.pathsep + os.environ["SystemRoot"] + "\\System32"
            env["SF2_SETUP_DISABLE_STANDARD_DISCOVERY"] = "1"
            result = subprocess.run(
                [shutil.which("pwsh"), "-NoProfile", "-File", str(root / "SETUP.ps1"),
                 "-PreflightOnly", "-NoInstallDependencies"],
                check=False, text=True, stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT, env=env,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Missing: Python 3.10+", result.stdout)
            self.assertIn("Run SETUP.bat for automatic installation", result.stdout)

    @unittest.skipUnless(os.name == "nt" and shutil.which("pwsh"),
                         "Windows PowerShell is unavailable")
    def test_setup_rejects_non_ascii_launcher_path_before_tool_discovery(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp) / "Γιώργος"
            root.mkdir()
            setup = pathlib.Path(__file__).parents[1] / "release" / "SETUP.ps1"
            shutil.copy2(setup, root / "SETUP.ps1")
            cue = root / "Syphon Filter 2 (USA) (Disc 1).cue"
            cue.write_text("FILE disc1.bin BINARY\n", encoding="ascii")
            env = os.environ.copy()
            env["SF2_SETUP_DISABLE_STANDARD_DISCOVERY"] = "1"
            result = subprocess.run(
                [shutil.which("pwsh"), "-NoProfile", "-File", str(root / "SETUP.ps1"),
                 "-CuePath", str(cue), "-NoInstallDependencies"],
                check=False, text=True, encoding="utf-8", errors="replace",
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT, env=env,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("ASCII-only path", result.stdout)
            self.assertNotIn("== 0/7 prepare build tools ==", result.stdout)


if __name__ == "__main__":
    unittest.main()
