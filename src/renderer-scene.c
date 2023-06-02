//
// Created by tumap on 7/31/22.
//
#include "renderer.h"
#include "renderer-definition.h"


static inline tRendererColor map_color(tRendererColorHandle handle);


static void propagate_visibility(tRendererTileHandle tile_handle, bool visible) {
    unsigned i, count;
    tRendererTile *tile = renderer_tiles + tile_handle;
    const tRendererTileHandle *children = tile->children_tiles;
    for (i = 0, count = tile->children_count; i < count; i++, children++) {
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

void renderer_set_color(tRendererTileHandle tile, tRendererColorHandle color) {
    renderer_tiles[tile].color_handle = color;
    renderer_tiles[tile].color = map_color(color);
}

static const uint32_t offsetsFromUTF8[6] = {
        0x00000000UL, 0x00003080UL, 0x000E2080UL,
        0x03C82080UL, 0xFA082080UL, 0x82082080UL
};
#define isutf(c) (((c)&0xC0)!=0x80)

static uint32_t utf_nextchar(const char *s, unsigned *i) {
    uint32_t ch = 0;
    int sz = 0;

    do {
        ch <<= 6;
        ch += (unsigned char) s[(*i)++];
        sz++;
    } while (s[*i] && !isutf(s[*i]));
    ch -= offsetsFromUTF8[sz - 1];

    return ch;
}

void renderer_set_text(tRendererTileHandle tile_handle, const char *text) {

    // find text definition
    tRendererText *text_definition = renderer_texts + tile_handle;

    // layout all characters
    unsigned character_index = 0;
    tRendererPosition x = 0;
    while (*text && character_index < text_definition->tile_count) {
        // extract code point
        unsigned i = 0;
        uint32_t code_point = utf_nextchar(text, &i);
        text += i;

        // space?
        if (code_point == ' ') {
            x += text_definition->font->space_width;
            continue;
        }

        // find glyph
        tRendererFontGlyph *glyph;
        for (glyph = text_definition->font->glyphs, i = text_definition->font->glyph_count; i > 0; i--, glyph++) {
            if (glyph->code_point == code_point)
                break;
        }
        if (i == 0) {
            // unknown code point -> show space
            x += text_definition->font->space_width;
            continue;
        }

        // set character tile coordinates & texture
        tRendererTile *tile = renderer_tiles + text_definition->tile[character_index];
        tile->tile_visible = true;
        tile->position_top = text_definition->position_y + glyph->offset_y;
        tile->position_left = x + glyph->offset_x;
        tile->position_width = glyph->width;
        tile->position_height = glyph->height;
        tile->position_right = tile->position_left + tile->position_width - 1;
        tile->position_bottom = tile->position_top + tile->position_height - 1;
        tile->texture.base = glyph->texture.base;
        tile->texture.stripe_length = glyph->texture.stripe_length;
        tile->texture.packed_alpha = glyph->texture.packed_alpha;

        x += glyph->advance_x;

        character_index++;
    }

    while (character_index < text_definition->tile_count) {
        tRendererTile *tile = renderer_tiles + text_definition->tile[character_index++];
        tile->tile_visible = false;
    }

    // update X position
    tRendererPosition deltaX = text_definition->position_x;
    if (text_definition->alignment_h == TEXT_RIGHT)
        deltaX -= x;
    if (text_definition->alignment_h == TEXT_CENTER)
        deltaX -= x / 2;
    for (character_index = 0; character_index < text_definition->tile_count; character_index++) {
        tRendererTile *tile = renderer_tiles + text_definition->tile[character_index];
        tile->position_left += deltaX;
        tile->position_right += deltaX;
    }

}

static const tRendererColor default_color = {.red=0, .green=0, .blue=0, .alpha=255};

static inline tRendererColor map_color(tRendererColorHandle handle) {
    tRendererColor ret;
    uint16_t color = renderer_colors[handle];
    ret.red = ((color >> 12) & 0x0f) * 17;
    ret.green = ((color >> 8) & 0x0f) * 17;
    ret.blue = ((color >> 4) & 0x0f) * 17;
    ret.alpha = ((color >> 0) & 0x0f) * 17;
    return ret;
}