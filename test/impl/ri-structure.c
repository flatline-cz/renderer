#include <stdlib.h>
#include "ri-constants.h"
#include "renderer.h"

static const tRendererTileHandle tile_0_children[2] = { 1, 2 };

tRendererTile renderer_tiles[RENDERER_TILES_COUNT] = {
    {
        .parent_tile = RENDERER_NULL_HANDLE, .root_tile = 0,
        .children_tiles = tile_0_children, .children_count = 2,
        .tile_visible = true, .parent_visible = true,
        .position_left = 0, .position_right = 639,
        .position_top = 0, .position_bottom = 479,
        .position_width = 640, .position_height = 480,
        .color = { .red = 0x00, .green = 0x00, .blue = 0x00, .alpha = 0xFF },
    },
    {
        .parent_tile = 0, .root_tile = 0,
        .children_tiles = NULL, .children_count = 0,
        .tile_visible = true, .parent_visible = true,
        .position_left = 10, .position_right = 73,
        .position_top = 10, .position_bottom = 73,
        .position_width = 64, .position_height = 64,
        .color = { .red = 0xff, .green = 0xFF, .blue = 0xff, .alpha = 0xFF },
    },
    {
        .parent_tile = 0, .root_tile = 0,
        .children_tiles = NULL, .children_count = 0,
        .tile_visible = true, .parent_visible = true,
        .position_left = 200, .position_right = 263,
        .position_top = 10, .position_bottom = 73,
        .position_width = 64, .position_height = 64,
        .color = { .red = 0xFF, .green = 0x00, .blue = 0x00, .alpha = 0xFF },
    },
};

const char* renderer_script=
        // define tile names
        " 0 const RENDER_TILE_main "
        " 1 const RENDER_TILE_main_sign1 "
        " 2 const RENDER_TILE_main_sign2 "

        // show screen
        " RENDER_TILE_main show_screen "
        ;


