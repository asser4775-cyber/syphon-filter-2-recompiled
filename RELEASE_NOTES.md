# v0.1.1-alpha

Initial public playtest release for the complete two-disc Syphon Filter 2
(USA) campaign, bootstrapped from SCUS-94451. Both discs and the connected
campaign have been played and verified.

This revision adds the shared PSXRecomp graphical launcher and a double-click
setup path. `SETUP.bat` auto-detects a neighboring Disc 1 CUE even when Disc 2
is also present, auto-detects PATH/MSYS2 MinGW toolchains, builds locally, and
opens the launcher. Later runs use `play.bat`.

Mouse Look, Widescreen (16:9), and PGXP are now independent Mods and all
default to disabled. The Controls page supports two bindings per retail PAD
control, Mouse1--Mouse5, and immediate same-launch persistence.

Included:

- statically recompiled resident executable;
- compatibility interpreter for uncovered streamed overlays;
- optional native 16:9 world presentation with authored 4:3 handling;
- optional PGXP geometry with atomic fallback when provenance is incomplete;
- optional direct mouse chase/aim camera with retail camera ownership;
- keyboard and controller input through the retail PAD path;
- 4x supersampling and OpenGL presentation;
- memory-card persistence;
- bundled MIT-licensed OpenBIOS.

Known limitations:

- broader public regression coverage across both discs is still wanted;
- high-refresh interpolation is not included; gameplay uses retail cadence;
- true 60 FPS is parked because the pure recomp boundary lacks semantic
  camera/object/bone state; it requires partial decompilation or an equivalent
  render-at-will interface;
- overlay execution coverage is incomplete and some areas may be slower;
- late-game HUD, FMV, fullscreen effects, and save/load transitions need more
  public playthrough coverage.

The downloadable artifact is an owned-input setup kit. It does not contain a
game executable: the player supplies SCUS-94451 Disc 1 as the build input and
their Disc 2 for the second half of the game, while the kit uses the
MIT-licensed OpenBIOS and extracts, verifies, recompiles, and builds locally.

Release qualification includes a clean-room setup from the packaged kit and a
rapid-start route with repeated movie skips, immediate briefing exit, player
ownership, and movement. Framework tests pass 54/54.
