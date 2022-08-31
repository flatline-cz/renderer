//
// Created by tumap on 7/31/22.
//

#ifndef RENDERER_RENDERER_H
#define RENDERER_RENDERER_H

#include <stdbool.h>
#include <stdint.h>
#include "ri-constants.h"

typedef uint16_t tRendererPosition;

#define RENDERER_NULL_HANDLE                      0xffff
typedef uint16_t tRendererTileHandle;

typedef struct tRendererColor {
    unsigned red: 8;
    unsigned green: 8;
    unsigned blue: 8;
    unsigned alpha: 8;
} tRendererColor;


typedef struct tRendererTile {
    // tree
    const tRendererTileHandle parent_tile;
    const tRendererTileHandle root_tile;
    const tRendererTileHandle* children_tiles;
    unsigned children_count;

    // visibility
    bool tile_visible;
    bool parent_visible;

    // position
    tRendererPosition position_left;
    tRendererPosition position_right;
    tRendererPosition position_top;
    tRendererPosition position_bottom;
    tRendererPosition position_width;
    tRendererPosition position_height;

    // color
    tRendererColor color;


} tRendererTile;


extern tRendererTile renderer_tiles[RENDERER_TILES_COUNT];

void renderer_init();

bool renderer_handle();

void renderer_set_visibility(tRendererTileHandle tile, bool visible);

void renderer_set_position(tRendererTileHandle tile_handle,
                           tRendererPosition left, tRendererPosition top);

void renderer_set_color(tRendererTileHandle tile, tRendererColor color);

void renderer_set_text(tRendererTileHandle tile, const char* text, unsigned length);

void renderer_show_screen(tRendererTileHandle root_tile);

void renderer_update_display(unsigned buffer);

int renderer_display_ready();



#endif //RENDERER_RENDERER_H
