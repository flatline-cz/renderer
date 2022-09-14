//
// Created by tumap on 7/31/22.
//
#include "renderer.h"


//int __attribute__((weak)) renderer_display_ready() {
//    return -1;
//}

bool renderer_handle() {
    int buffer = renderer_display_ready();
    if (buffer < 0)
        return false;

    return renderer_update_display(buffer);
}

static void propagate_visibility(tRendererTileHandle tile, bool visible) {
    unsigned i, count;
    const tRendererTileHandle *children = renderer_tiles[tile].children_tiles;
    for (i = 0, count = renderer_tiles[tile].children_count; i < count; i++, children++) {
        renderer_tiles[*children].parent_visible = visible;
        propagate_visibility(*children, visible && renderer_tiles[*children].tile_visible);
    }
}

void renderer_set_visibility(tRendererTileHandle tile, bool visible) {
    if (renderer_tiles[tile].tile_visible == visible)
        return;
    renderer_tiles[tile].tile_visible = visible;
    propagate_visibility(tile, visible && renderer_tiles[tile].parent_visible);
}

void renderer_set_position(tRendererTileHandle tile_handle,
                           tRendererPosition left, tRendererPosition top) {
    register tRendererTile *tile = renderer_tiles + tile_handle;
    tile->position_left = left;
    tile->position_right = left + tile->position_width - 1;
    tile->position_top = top;
    tile->position_bottom = top + tile->position_height - 1;
}

void renderer_set_color(tRendererTileHandle tile, tRendererColor color) {
    renderer_tiles[tile].color = color;
}

void renderer_set_text(tRendererTileHandle tile, const char *text, unsigned length) {

}
