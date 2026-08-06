# Syphon Filter 2 Recompiled — owned-input player kit

This kit builds the complete two-disc **Syphon Filter 2 (USA)** campaign as a
native Windows x64 program using PSXRecomp, bootstrapped from SCUS-94451. It
contains no game executable, generated game/BIOS code, game assets, Sony BIOS,
saves, or overlay captures.

You must provide your legally obtained Disc 1 `.cue` plus its `.bin` track
files. The runtime uses PSXRecomp's bundled MIT-licensed OpenBIOS backend; a
Sony BIOS dump is not required.

The setup script extracts and hash-checks `SCUS_944.51`, regenerates the game
and OpenBIOS backends locally, builds the runtime and the real PSXRecomp
graphical launcher, and writes `play.bat`.

## Prerequisites

- Windows 10/11 x64 and approximately 6 GiB free space;
- Git and Python 3 on `PATH`;
- [MSYS2](https://www.msys2.org/) installed at `C:\msys64`;
- from the MSYS2 MinGW64 shell:

```sh
pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-cmake mingw-w64-x86_64-ninja mingw-w64-x86_64-python
```

## Easiest setup

Put the extracted kit, the Disc 1 `.cue`, and its `.bin` file(s) in the same
folder. Disc 2 can be there too: setup specifically selects the CUE whose name
contains `Disc 1`. Then double-click:

```text
SETUP.bat
```

The first build downloads pinned source dependencies and can take several
minutes. When it succeeds, the PSXRecomp launcher opens automatically. Future
runs only require `play.bat`; the launcher lets you choose the disc, video,
controller, keyboard, and memory-card settings.

## PowerShell setup

If automatic Disc 1 selection is ambiguous, open PowerShell in the extracted
kit and choose the CUE explicitly:

```powershell
pwsh -File SETUP.ps1 `
  -CuePath "D:\PS1\Syphon Filter 2 (USA) (Disc 1).cue"
```

The script auto-detects MinGW when `gcc` and `ninja` are on `PATH`, including a
WinGet WinLibs installation. You can override it with
`-Mingw "D:\Tools\mingw64"`. Do not move individual files out of the extracted
kit. Memory cards are stored under `out\release\saves`.

## Current state

- Both discs, the connected campaign, and the disc transition have been played
  and verified; public regression reports remain welcome.
- Mouse Look, Widescreen (16:9), and PGXP are independent launcher Mods. All
  three default off; enable only the enhancements you want before Launch.
- The Controls page supports two keyboard/mouse bindings per retail PAD
  control and applies saved edits to the same launch.
- Retail gameplay, scripts, AI, collision, camera ownership, saves, and the
  authentic 20 Hz world update remain game-owned.
- The resident executable is statically recompiled. Uncovered streamed
  overlays use the compatibility interpreter; native overlay promotion is
  deliberately disabled in this alpha and native coverage is incomplete.

True 60 FPS gameplay is not attainable through this project's pure
post-projection recompilation path. Three presentation experiments were
rejected for ghosting, unstable/cracked geometry, or sparse/incoherent replay.
A correct implementation requires at least partial matching decompilation—or
an equivalent semantic camera/object/bone snapshot and render-at-will
interface—like the architecture used by SF-PC-Port. High refresh is therefore
parked, not an active promise for this project.

## License and privacy

PSXRecomp is PolyForm Noncommercial 1.0.0; see `LICENSE-psxrecomp` and
`THIRD_PARTY_ATTRIBUTION.md`. This kit is for noncommercial research and
private play with legally obtained inputs.

Never redistribute the extracted `input/`, `generated/`, `psxrecomp-src/`,
`out/`, `play.bat`, memory cards, `overlay_captures.json`, or any package made
after running setup. Those local outputs may contain retail-derived code or
private paths.
