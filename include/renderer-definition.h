//
// Created by tumap on 10/13/22.
//

#ifndef RENDERER_TEST_RENDERER_DEFINITION_H
#define RENDERER_TEST_RENDERER_DEFINITION_H

#include <stdint.h>
#include <stdbool.h>
#include "renderer-types.h"
#include "ri-constants.h"

typedef enum eRendererTileMode {
    COLOR,
    ALPHA_TEXTURE,
    ABGR_TEXTURE
} eRendererTileMode;

typedef struct tRendererTexture {
    uint8_t block;
    uint8_t row;               // 8 bits
    uint16_t column;            // 10 bits
    uint16_t stripe_length;     // 10 bits
    bool packed_alpha;
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

typedef struct tRendererFontGlyph {
    uint16_t code_point;
    uint16_t width;
    uint16_t height;
    int16_t offset_x;
    int16_t offset_y;
    uint16_t advance_x;
    tRendererTexture texture;
} tRendererFontGlyph;

typedef struct tRendererFont {
    uint16_t glyph_count;
    tRendererFontGlyph *glyphs;
    uint16_t space_width;
} tRendererFont;

typedef enum eRendererHAlignment {
    TEXT_LEFT, TEXT_CENTER, TEXT_RIGHT
} eRendererHAlignment;

typedef enum eRendererVAlignment {
    TEXT_TOP, TEXT_MIDDLE, TEXT_BOTTOM
} eRendererVAlignment;

typedef struct tRendererText {
    uint16_t tile_count;
    tRendererTileHandle *tile;
    tRendererFont *font;
    tRendererPosition position_x;
    tRendererPosition position_y;
    eRendererHAlignment alignment_h;
    eRendererVAlignment alignment_v;
    uint16_t *text;
} tRendererText;

typedef struct tRendererVideoFrameDescriptor {
    uint8_t block;
    uint8_t row;
} tRendererVideoFrameDescriptor;

typedef struct tRendererVideoDescriptor {
    uint16_t frame_count;
    tRendererVideoFrameDescriptor * frames;
} tRendererVideoDescriptor;

extern tRendererText renderer_texts[RENDERER_TEXT_COUNT];
extern tRendererTile renderer_tiles[RENDERER_TILES_COUNT];
extern tRendererVideoDescriptor  renderer_videos[RENDERER_VIDEO_COUNT];

extern const char *renderer_script;

#endif //RENDERER_TEST_RENDERER_DEFINITION_H
