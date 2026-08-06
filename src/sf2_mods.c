#include "mod_plugins.h"

static void enable_mouse_look(void) {
    (void)psx_mod_set_mouse_camera(1);
}

static void enable_widescreen(void) {
    (void)psx_mod_set_fixed_display_aspect(16, 9);
}

static void enable_pgxp(void) {
    (void)psx_mod_set_pgxp(1);
}

PSX_MOD_CONSTRUCTOR(register_sf2_mods) {
    (void)psx_mod_register_activation_plugin(
        "sf2.mouse-look", enable_mouse_look);
    (void)psx_mod_register_activation_plugin(
        "sf2.widescreen", enable_widescreen);
    (void)psx_mod_register_activation_plugin(
        "sf2.pgxp", enable_pgxp);
}
