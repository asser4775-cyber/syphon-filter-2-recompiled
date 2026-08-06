cmake_minimum_required(VERSION 3.20)
project(SyphonFilter2Recompiled C CXX)

set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 17)
set(PSXRECOMP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/psxrecomp" CACHE PATH
    "Path to the pinned PSXRecomp framework")

# This first public alpha intentionally uses the proven minimal launcher path.
# The executable asks for a user-owned SCUS-94451 disc on first launch.
set(PSX_RECOMP_UI OFF CACHE BOOL "" FORCE)
set(PSXRECOMP_BIOS_STEMS "OpenBIOS" CACHE STRING "" FORCE)
include("${PSXRECOMP_ROOT}/runtime/runtime.cmake")

file(GLOB SF2_GENERATED_FULL CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/generated/SCUS_944.51_full.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/generated/SCUS_944.51_full_*.c")
set(SF2_GENERATED_DISPATCH
    "${CMAKE_CURRENT_SOURCE_DIR}/generated/SCUS_944.51_dispatch.c")

if(NOT SF2_GENERATED_FULL)
    # Keep CMake configuration intelligible before local regeneration. The
    # framework's generated-source guard provides the actionable build error.
    set(SF2_GENERATED_FULL
        "${CMAKE_CURRENT_SOURCE_DIR}/generated/SCUS_944.51_full.c")
endif()

psxrecomp_add_runtime_target(psx-runtime
    GAME_GENERATED_FULL_C ${SF2_GENERATED_FULL}
    GAME_GENERATED_DISPATCH_C "${SF2_GENERATED_DISPATCH}"
    WINDOW_TITLE "Syphon Filter 2 Recompiled"
    EXE_NAME "SyphonFilter2Recompiled"
    GAME_VERSION "0.1.0-alpha"
    DEFAULT_GAME_CONFIG_PATH "game.toml"
)
