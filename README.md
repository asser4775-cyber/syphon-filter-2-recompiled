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

1. Download the Windows x64 ZIP from this repository's Releases page.
2. Extract the whole ZIP and run `SyphonFilter2Recompiled.exe`.
3. On first launch, select your legally obtained **Syphon Filter 2 Disc 1
   (USA, SCUS-94451)** image. Choose the `.cue` when your dump has `.cue` plus
   `.bin` tracks.
4. The selected disc path is saved locally in `disc.cfg`. Memory cards are
   created in `saves/`.

The package includes the MIT-licensed OpenBIOS from PCSX-Redux, so a Sony BIOS
dump is not required. Supported input containers in this alpha are `.cue`,
`.bin`, and `.iso`.

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
| High refresh / 60 FPS | Not shipped; three visual candidates were rejected |
| Native code coverage | Resident executable native; uncovered overlays use interpreter fallback |

The rejected high-refresh experiments produced smooth host presentation
counters but visibly remained one-third-rate and introduced severe rendering
artifacts. They were removed rather than advertised. A future high-refresh
attempt needs semantic world-state reconstruction from matching decompilation
or an equivalent complete snapshot boundary.

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

The repository pins the framework as a submodule and contains only
game-specific metadata and build glue. A local build requires your own exact
SCUS-94451 executable (SHA-256
`75a360bf7465dfdec85c14f9ba93862aae2531b48d83fd8d82ba8c9fffa13d33`)
extracted to `input/SCUS_944.51` and a matching Disc 1 image at the relative
path in `game.toml`.

```powershell
git clone --recurse-submodules https://github.com/Alexbeav/syphon-filter-2-recompiled.git
cd syphon-filter-2-recompiled

cmake -S psxrecomp/recompiler -B psxrecomp/recompiler/build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build psxrecomp/recompiler/build --target psxrecomp-game
psxrecomp/recompiler/build/psxrecomp-game.exe --config game.toml

cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DPSX_DEBUG_TOOLS=OFF
cmake --build build --target psx-runtime --parallel
```

`input/` and `generated/` are ignored and must never be committed or shared.
The release itself is produced locally from those user-owned inputs, then a
GitHub workflow audits the ZIP, writes its SHA-256, and publishes the draft.
CI cannot and does not regenerate SF2 code.

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
