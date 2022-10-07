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

typedef enum eRendererTileMode {
    COLOR,
    ALPHA_TEXTURE,
    ABGR_TEXTURE
} eRendererTileMode;

typedef struct tRendererTexture {
    // TODO: make better
    uint32_t texture_base;
} tRendererTexture;

typedef struct tRendererTile {
    // tree
    const tRendererTileHandle parent_tile;
    const tRendererTileHandle root_tile;
    const tRendererTileHandle *children_tiles;
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

    // rendering mode
    eRendererTileMode rendering_mode;

    // color
    tRendererColor color;

    // texture
    tRendererTexture texture;

} tRendererTile;

extern tRendererTile renderer_tiles[RENDERER_TILES_COUNT];

typedef struct tRendererFontGlyph {
    uint16_t code_point;
    uint16_t width;
    uint16_t height;
    int16_t offset_x;
    int16_t offset_y;
    tRendererTexture texture;
} tRendererFontGlyph;

typedef struct tRendererFont {
    uint16_t glyph_count;
    tRendererFontGlyph *glyphs;
} tRendererFont;

typedef enum eRendererHAlignment {
    TEXT_LEFT, TEXT_CENTER, TEXT_RIGHT
} eRendererHAlignment;

typedef enum eRendererVAlignment {
    TEXT_TOP, TEXT_MIDDLE, TEXT_BOTTOM
} eRendererVAlignment;

typedef struct tRendererText {
    uint16_t tile_count;
    tRendererTileHandle * tile;
    tRendererFont *font;
    tRendererPosition position_x;
    tRendererPosition position_y;
    eRendererHAlignment alignment_h;
    eRendererVAlignment alignment_v;
    uint16_t* text;
} tRendererText;

extern tRendererText renderer_texts[RENDERER_TEXT_COUNT];

extern const char *renderer_script;

void renderer_init();

bool renderer_handle();

void renderer_set_visibility(tRendererTileHandle tile, bool visible);

void renderer_set_position(tRendererTileHandle tile_handle,
                           tRendererPosition left, tRendererPosition top);

void renderer_set_color(tRendererTileHandle tile, tRendererColor color);

void renderer_set_text(tRendererTileHandle tile, const char *text, unsigned length);

void renderer_show_screen(tRendererTileHandle root_tile);

bool renderer_update_display(unsigned buffer);

int renderer_display_ready();


#endif //RENDERER_RENDERER_H
