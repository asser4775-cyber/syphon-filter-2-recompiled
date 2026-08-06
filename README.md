# Syphon Filter 2 Recompiled

An experimental Windows static recompilation of **Syphon Filter 2 Disc 1
(USA, SCUS-94451)**, built with
[PSXRecomp](https://github.com/Alexbeav/psxrecomp).

The release runs the original retail game logic as a native x64 program over
a PlayStation hardware runtime. It adds native 16:9 presentation, PGXP-assisted
geometry, 4x supersampling, and direct mouse camera control while keeping the
retail gameplay, scripts, collision, saves, AI, and 20 Hz world update.

This is a **recompilation, not a decompilation**, and `v0.1.0-alpha` is not a
finished PC port. The project does not contain or distribute the game disc, a
Sony BIOS, extracted assets, generated game C, saves, or overlay captures.

## Download and play

The downloadable artifact is an **owned-input setup kit**, not a prebuilt
game. It contains the compiler/runtime tools and this project's verified
recipe, but no executable containing SF2 code.

1. Download `syphon-filter-2-recompiled-kit-windows-x64.zip` from Releases.
2. Extract it and provide your legally obtained SCUS-94451 Disc 1 `.cue`/`.bin`
   dump. The kit uses the framework's MIT-licensed OpenBIOS.
3. Run the included setup command:

```powershell
pwsh -File SETUP.ps1 `
  -CuePath "D:\PS1\Syphon Filter 2 (USA) (Disc 1).cue"
```

4. Run the generated `play.bat`.

Extraction, hash verification, game/BIOS recompilation, and the native build
all occur locally from your files. Never redistribute the setup output.

## Current status

| Area | Status |
|---|---|
| Boot, title, menus, FMV, Mission 1 | Deterministic routes and human play verified |
| Retail gameplay and timing | Preserved |
| Native 16:9 | Accepted in Mission 1; broader campaign coverage wanted |
| PGXP | Accepted in Mission 1; deliberately falls back when provenance is incomplete |
| Mouse camera | Chase and manual aim accepted; scripted cameras retain ownership |
| Controller and keyboard | Available through the retail PAD path |
| Saves | Local memory cards; full campaign save/load coverage still wanted |
| Disc 2 | Not yet qualified |
| High refresh / 60 FPS | Architecturally parked; requires partial decompilation or an equivalent semantic world interface |
| Native code coverage | Resident executable native; uncovered overlays use interpreter fallback |

The alpha launcher deliberately keeps streamed overlays interpreter-owned.
Automatic overlay compilation is disabled because warmed native shards have a
separate promotion/qualification contract and are not part of this release.

The rejected high-refresh experiments produced smooth host presentation
counters but visibly remained one-third-rate and introduced severe rendering
artifacts. They were removed rather than advertised. The pure recomp pipeline
sees flattened GPU packets after retail code has already combined camera,
object, bone, and projection state; it cannot reconstruct a coherent in-between
world from that boundary. True 60 FPS is therefore unattainable within this
project without at least partial matching decompilation—or an equivalent
semantic camera/object/bone snapshot and render-at-will interface. SF-PC-Port
gets smooth presentation from that higher-level semantic architecture.

## Controls

The release includes a keyboard profile:

- Move: `W/Q/S/E`
- Camera: mouse
- Fire / Square: `Left Ctrl`
- Aim / L1: `Left Alt`
- Crouch / Circle: `Space`
- Interact / Cross: `C`
- Triangle: `F`
- Strafe: `A` / `D`
- Pause / Start: `Escape`

Xbox-style controllers remain supported through the normal PSX controller
path. Edit `keybinds.ini` for keyboard changes.

## What to test

Playthrough reports are especially useful for:

- later Disc 1 missions, checkpoints, deaths, and restarts;
- memory-card save/load across clean launches;
- FMVs, letterboxing, fades, scopes, night vision, menus, and HUD placement;
- scenes where wide geometry appears or disappears at screen edges;
- mouse behavior during scripted cameras and manual aim;
- locations that are unusually slow because an overlay is interpreted.

When filing an issue, include the release version, Windows version, GPU,
renderer, mission/checkpoint, exact reproduction steps, and whether the issue
also occurs in 4:3. Never upload your disc, BIOS, save, generated code,
`overlay_captures.json`, or crash dump without first checking that it contains
no retail bytes or private paths.

## Building from source

The release kit is the supported build route. Its setup script pins framework
commit `34dcc23dd51005bd5a3c1b399ea2189e9e9b4f7e`, extracts and verifies
`SCUS_944.51` (SHA-256
`75a360bf7465dfdec85c14f9ba93862aae2531b48d83fd8d82ba8c9fffa13d33`),
regenerates the BIOS and game backends, and builds with MinGW/Ninja.

CI builds and tests only the redistributable compiler/tooling kit. It never
receives retail inputs and cannot produce the game executable. Local `input/`,
`generated/`, `psxrecomp-src/`, `out/`, and `play.bat` outputs are ignored and
must never be committed or shared.

## Development and provenance

Development was AI-assisted and human-directed. Acceptance is based on
machine-checkable executable identity, deterministic routes, bounded runtime
telemetry, repeated clean-process comparisons, and human visual testing.
Generated game C is never hand-edited; fixes belong in source-owned
recompiler/runtime code or verified configuration.

The framework source is PolyForm Noncommercial 1.0.0. This project is for
noncommercial research, preservation, and private play with legally obtained
inputs. Syphon Filter and its assets remain the property of their respective
rights holders. See [LICENSE](LICENSE) and the notices bundled with each
release.
