#include <stdlib.h>
#include "ri-constants.h"
#include "renderer.h"

static const tRendererTileHandle tile_0_children[1] = { 1 };
static const tRendererTileHandle tile_1_children[4] = { 2, 3, 4, 5 };

tRendererTile renderer_tiles[RENDERER_TILES_COUNT] = {
    {
        .parent_tile = RENDERER_NULL_HANDLE, .root_tile = 0,
        .children_tiles = tile_0_children, .children_count = 1,
        .tile_visible = true, .parent_visible = true,
        .position_left = 0, .position_right = 1023,
        .position_top = 0, .position_bottom = 599,
        .position_width = 1024, .position_height = 600,
        .color = { .red = 0xFF, .green = 0xFF, .blue = 0xFF, .alpha = 0xFF },
    },
    {
        .parent_tile = 0, .root_tile = 0,
        .children_tiles = tile_1_children, .children_count = 4,
        .tile_visible = true, .parent_visible = true,
        .position_left = 100, .position_right = 399,
        .position_top = 100, .position_bottom = 199,
        .position_width = 300, .position_height = 100,
        .color = { .red = 0x00, .green = 0x00, .blue = 0x00, .alpha = 0xFF },
    },
    {
        .parent_tile = 1, .root_tile = 0,
        .children_tiles = NULL, .children_count = 0,
        .tile_visible = true, .parent_visible = true,
        .position_left = 120, .position_right = 151,
        .position_top = 120, .position_bottom = 151,
        .position_width = 32, .position_height = 32,
        .color = { .red = 0x00, .green = 0xFF, .blue = 0x7F, .alpha = 0xFF },
 // tx = 96, ty = 0
        .texture_base = 0x80000060
    },
    {
        .parent_tile = 1, .root_tile = 0,
        .children_tiles = NULL, .children_count = 0,
        .tile_visible = true, .parent_visible = true,
        .position_left = 160, .position_right = 191,
        .position_top = 155, .position_bottom = 186,
        .position_width = 32, .position_height = 32,
        .color = { .red = 0xFF, .green = 0x00, .blue = 0x33, .alpha = 0xFF },
 // tx = 64, ty = 0
        .texture_base = 0x80000040
    },
    {
        .parent_tile = 1, .root_tile = 0,
        .children_tiles = NULL, .children_count = 0,
        .tile_visible = true, .parent_visible = true,
        .position_left = 160, .position_right = 191,
        .position_top = 120, .position_bottom = 151,
        .position_width = 32, .position_height = 32,
        .color = { .red = 0x00, .green = 0xFF, .blue = 0x7F, .alpha = 0xFF },
 // tx = 0, ty = 0
        .texture_base = 0x80000000
    },
    {
        .parent_tile = 1, .root_tile = 0,
        .children_tiles = NULL, .children_count = 0,
        .tile_visible = true, .parent_visible = true,
        .position_left = 200, .position_right = 231,
        .position_top = 155, .position_bottom = 186,
        .position_width = 32, .position_height = 32,
        .color = { .red = 0xFF, .green = 0xA5, .blue = 0x00, .alpha = 0xFF },
 // tx = 32, ty = 0
        .texture_base = 0x80000020
    },
};

