# v0.1.0-alpha

Initial public playtest release for Syphon Filter 2 Disc 1 (USA, SCUS-94451).

Included:

- statically recompiled resident executable;
- compatibility interpreter for uncovered streamed overlays;
- native 16:9 world presentation with authored 4:3 handling where classified;
- PGXP-assisted geometry with atomic fallback when provenance is incomplete;
- direct mouse chase/aim camera while retail code retains camera ownership;
- keyboard and controller input through the retail PAD path;
- 4x supersampling and OpenGL presentation;
- memory-card persistence;
- bundled MIT-licensed OpenBIOS.

Known limitations:

- full Disc 1 campaign validation is not complete;
- Disc 2 is not yet qualified;
- high-refresh interpolation is not included; gameplay uses retail cadence;
- true 60 FPS is parked because the pure recomp boundary lacks semantic
  camera/object/bone state; it requires partial decompilation or an equivalent
  render-at-will interface;
- overlay execution coverage is incomplete and some areas may be slower;
- late-game HUD, FMV, fullscreen effects, and save/load transitions need more
  public playthrough coverage.

The downloadable artifact is an owned-input setup kit. It does not contain a
game executable: the player supplies SCUS-94451 Disc 1, while the kit uses the
MIT-licensed OpenBIOS and extracts, verifies, recompiles, and builds locally.

Release qualification includes a clean-room setup from the packaged kit and a
rapid-start route with repeated movie skips, immediate briefing exit, player
ownership, and movement. Framework tests pass 54/54.
