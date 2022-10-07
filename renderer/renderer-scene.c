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

void renderer_set_text(tRendererTileHandle tile_handle, const char *text, unsigned length) {

    // find text definition
    tRendererText *text_definition = renderer_texts + tile_handle;

    // layout all characters
    unsigned character_index = 0;
    tRendererPosition x = 0;
    while (*text && character_index < length && character_index < text_definition->tile_count) {
        // extract code point
        uint16_t code_point = (unsigned char) *(text++); // FIXME -> UTF8

        // find glyph
        tRendererFontGlyph *glyph;
        unsigned i;
        for (glyph = text_definition->font->glyphs, i = text_definition->font->glyph_count; i > 0; i--, glyph++) {
            if (glyph->code_point == code_point)
                break;
        }
        if (i == 0) {
            // FIXME: unknown code point
            continue;
        }

        // set character tile coordinates & texture
        tRendererTile *tile = renderer_tiles + text_definition->tile[character_index];
        tile->tile_visible = true;
        tile->position_top = text_definition->position_y + glyph->offset_y;
        tile->position_left = x;
        tile->position_width = glyph->width;
        tile->position_height = glyph->height;
        tile->position_right = tile->position_left + tile->position_width - 1;
        tile->position_bottom = tile->position_top + tile->position_height - 1;
        tile->texture.texture_base = glyph->texture.texture_base;

        x += tile->position_width + 2;

        character_index++;
    }

    while (character_index < text_definition->tile_count) {
        tRendererTile *tile = renderer_tiles + text_definition->tile[character_index++];
        tile->tile_visible = false;
    }

    // update X position
    tRendererPosition deltaX = text_definition->position_x;
    for (character_index = 0; character_index < text_definition->tile_count; character_index++) {
        tRendererTile *tile = renderer_tiles + text_definition->tile[character_index];
        tile->position_left += deltaX;
        tile->position_right += deltaX;
    }

}
