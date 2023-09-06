//
// Created by tumap on 10/13/22.
//

#ifndef RENDERER_TEST_RENDERER_DEFINITION_H
#define RENDERER_TEST_RENDERER_DEFINITION_H

#include <stdint.h>
#include <stdbool.h>

#ifndef NULL
#define NULL ((void*)0)
#endif

typedef uint16_t tRendererPosition;

#define RENDERER_NULL_HANDLE                      0xffff
typedef uint16_t tRendererTileHandle;

typedef uint16_t tRendererScreenHandle;

typedef uint16_t tRendererGraphicsHandle;

typedef uint16_t tRendererVideoHandle;

typedef uint16_t tRendererColorHandle;

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
    uint32_t base;
    uint16_t stripe_length;     // 10 bits
    bool packed_alpha;
} tRendererTexture;

typedef struct tRendererTile {
    // tree
    tRendererTileHandle parent_tile;
    tRendererTileHandle root_tile;
    uint16_t children_list_index;
    uint16_t children_count;
    bool overlapping_children;

    // visibility
    bool tile_visible;
    bool parent_visible;

    // position (for rendering)
    tRendererPosition position_left;
    tRendererPosition position_right;
    tRendererPosition position_top;
    tRendererPosition position_bottom;
    tRendererPosition position_width;
    tRendererPosition position_height;

    // rendering mode
    eRendererTileMode rendering_mode;

    // color
    tRendererColorHandle color_handle;
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
    uint16_t first_glyph;
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
    tRendererTileHandle tile;
    uint16_t font;
    tRendererPosition position_x;
    tRendererPosition position_y;
    eRendererHAlignment alignment_h;
    eRendererVAlignment alignment_v;
    uint16_t *text;
} tRendererText;

typedef struct tRendererVideoDescriptor {
    uint16_t frame_count;
    const uint32_t *frame_offsets;
    const uint8_t *data;
    uint32_t length;
} tRendererVideoDescriptor;

typedef struct tRendererScreenGraphics {
    uint32_t length;
    uint32_t base;
} tRendererScreenGraphics;

typedef struct tRendererScreen {
    tRendererGraphicsHandle graphics;
    tRendererTileHandle root_tile;
} tRendererScreen;

extern uint16_t *renderer_colors;
extern uint16_t renderer_colors_simple_count;

extern tRendererFontGlyph *renderer_font_glyphs;
extern uint16_t renderer_font_glyphs_count;

extern tRendererFont * renderer_fonts;
extern uint16_t renderer_fonts_count;

extern tRendererText *renderer_texts;
extern uint16_t renderer_texts_count;

extern tRendererTile *renderer_tiles;
extern uint16_t renderer_tiles_count;

extern tRendererTileHandle *renderer_child_index;

extern tRendererScreen *renderer_screens;
extern uint16_t renderer_screen_count;

extern tRendererVideoDescriptor *renderer_videos;
extern uint16_t renderer_videos_count;

extern tRendererScreenGraphics *renderer_graphics;
extern uint16_t renderer_graphics_count;

extern const char *renderer_script;

#endif //RENDERER_TEST_RENDERER_DEFINITION_H
