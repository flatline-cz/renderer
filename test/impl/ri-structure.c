#include <stdlib.h>
#include "ri-constants.h"
#include "renderer.h"

static const tRendererTileHandle tile_0_children[1] = { 1 };
static const tRendererTileHandle tile_1_children[1] = { 2 };

tRendererTile renderer_tiles[RENDERER_TILES_COUNT] = {
    {
        .parent_tile = RENDERER_NULL_HANDLE, .root_tile = 0,
        .children_tiles = tile_0_children, .children_count = 1,
        .tile_visible = true, .parent_visible = true,
        .position_left = 0, .position_right = 1023,
        .position_top = 0, .position_bottom = 599,
        .position_width = 1024, .position_height = 600,
        .color = { .red = 0x00, .green = 0x00, .blue = 0x00, .alpha = 0xFF },
    },
    {
        .parent_tile = 0, .root_tile = 0,
        .children_tiles = tile_1_children, .children_count = 1,
        .tile_visible = true, .parent_visible = true,
        .position_left = 100, .position_right = 199,
        .position_top = 100, .position_bottom = 199,
        .position_width = 100, .position_height = 100,
        .color = { .red = 0xFF, .green = 0x00, .blue = 0x00, .alpha = 0xFF },
    },
    {
        .parent_tile = 1, .root_tile = 0,
        .children_tiles = NULL, .children_count = 0,
        .tile_visible = true, .parent_visible = true,
        .position_left = 120, .position_right = 139,
        .position_top = 120, .position_bottom = 139,
        .position_width = 20, .position_height = 20,
        .color = { .red = 0x00, .green = 0xFF, .blue = 0x00, .alpha = 0x80 },
    },
};

