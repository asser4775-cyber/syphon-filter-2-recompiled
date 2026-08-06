# Reddit draft — r/decomps

## Suggested title

Syphon Filter 2 Recompiled — experimental Windows static recomp with native 16:9, PGXP and mouse camera (v0.1 alpha)

## Body

I have an early public playtest build of **Syphon Filter 2 Recompiled** for the
USA Disc 1 release (SCUS-94451).

This is a **static recompilation, not a matching decompilation**. The resident
PS1 executable is translated ahead of time and compiled into a native Windows
x64 program over the PSXRecomp hardware runtime. Streamed overlays that do not
yet have native coverage use a bounded interpreter fallback, so I am not
claiming 100% native execution.

What is in this alpha:

- native 16:9 world presentation;
- PGXP-assisted geometry;
- 4x supersampling and OpenGL output;
- direct mouse control for chase camera and manual aim;
- normal keyboard/controller input through the retail PAD path;
- memory cards and the game's original progression, AI, collision and timing;
- bundled open-source OpenBIOS (you supply your own legal game disc image).

What is **not** in it: 60 FPS gameplay. I tried three high-refresh presentation
candidates and rejected all three after visual testing—the counters looked
good, but motion still read at one-third rate and the later candidates caused
serious rendering artifacts. The release stays at the authentic world-update
cadence instead of shipping a broken checkbox.

Validation so far includes repeated clean-process Mission 1 routes, executable
hash checks, deterministic input/state comparisons, software/OpenGL checks,
and human A/B testing. It is still `v0.1.0-alpha`: Disc 2 is not qualified and
the complete Disc 1 campaign needs playthrough coverage, especially later
FMVs, fullscreen effects, saves/checkpoints, and overlay-heavy areas.

Development was AI-assisted and human-directed. Generated game code is never
hand-edited; the project uses automated regressions and explicit human visual
acceptance gates, including recording rejected attempts instead of presenting
them as finished features.

[VIDEO LINK]

[GITHUB RELEASE LINK]

The repository and release contain no game disc, Sony BIOS, extracted assets,
generated game C, saves, or overlay captures. You need your own legally
obtained Syphon Filter 2 Disc 1 (USA, SCUS-94451) image.

I would especially appreciate reports from full Disc 1 playthroughs. Please
include the mission/checkpoint, GPU, and exact reproduction steps, and do not
upload copyrighted inputs or `overlay_captures.json`.
