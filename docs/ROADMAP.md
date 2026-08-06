# Roadmap and declared limits

## Accepted enhanced baseline

- SCUS-94451 resident executable identity verified.
- Retail boot, frontend, FMV transition, Mission 1 ownership and gameplay.
- Native 16:9 world presentation with the frozen 4:3 compatibility oracle.
- PGXP-assisted geometry with conservative all-or-nothing fallback.
- Keyboard/controller input through the retail PAD path.
- Direct mouse chase/manual-aim camera with scripted-camera ownership gates.

## Architecturally parked: true 60 FPS

High refresh is not an active milestone in the pure recompilation project.
R1 whole-frame blending produced ghosting without perceptual smoothness. R2
post-projection packet matching cracked shared geometry and disturbed visible
timing. R3 sparse transform replay remained one-third-rate and mixed moved
geometry with persistent prior-world pixels, producing severe brightness and
coverage artifacts.

The missing information is semantic: stable camera, actor, model, bone,
projectile, and world identity before projection, plus a render-at-will path.
The flattened GP0 stream cannot recover that ownership reliably. Resuming true
60 FPS requires at least partial matching decompilation of the world-update and
render-submission path, or an equivalent complete semantic interface. This is
the class of interface used by SF-PC-Port. Cadence counters or endpoint hashes
alone cannot reopen the milestone.

## Remaining release deltas

1. Run the complete connected Disc 1 campaign: checkpoints, damage/death,
   restart, save/load across clean launches, ending, and return to frontend.
2. Qualify Disc 2 and the disc-transition seam, even though the resident
   executable identity is shared.
3. Exercise later HUD, FMV, scope, night-vision, fade, matte, menu, and
   fullscreen-effect presentation in both 4:3 and 16:9.
4. Attribute and warm streamed-overlay execution. The accepted Mission 1
   route uses substantial interpreter fallback; playability is not 100%
   native coverage.
5. Run controller and keyboard/mouse together, long-session stability,
   frame-pacing/audio, memory growth, clean exit, and release performance.

The CI-owned-input kit and a clean-room `SETUP.ps1` build are complete. The
exact clean-room output also passed the rapid-start Mission 1 ownership and
movement route. Public playthrough coverage is now the release gate for the
remaining items above.

Until those gates pass, the honest label is an experimental enhanced alpha,
not a campaign-complete port or fully native recompilation.
