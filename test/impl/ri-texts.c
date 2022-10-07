#include "renderer.h"
#include "ri-constants.h"

#define RENDERER_FONT_COUNT                                              2
#define RENDERER_GLYPH_COUNT                                             18

// glyphs
static tRendererFontGlyph glyphs[RENDERER_GLYPH_COUNT] = {
    { .code_point = '0', 
          .advance_x = 13,
          .width = 12, .height = 15, .offset_x = 1, .offset_y = -15,
          .texture = { .texture_base = 0x80004468 },
    },
    { .code_point = '1', 
          .advance_x = 13,
          .width = 8, .height = 15, .offset_x = 2, .offset_y = -15,
          .texture = { .texture_base = 0x800000D4 },
    },
    { .code_point = '2', 
          .advance_x = 13,
          .width = 12, .height = 15, .offset_x = 1, .offset_y = -15,
          .texture = { .texture_base = 0x80004474 },
    },
    { .code_point = '3', 
          .advance_x = 13,
          .width = 12, .height = 15, .offset_x = 2, .offset_y = -15,
          .texture = { .texture_base = 0x80004490 },
    },
    { .code_point = '4', 
          .advance_x = 13,
          .width = 12, .height = 15, .offset_x = 1, .offset_y = -15,
          .texture = { .texture_base = 0x800044A0 },
    },
    { .code_point = '5', 
          .advance_x = 13,
          .width = 8, .height = 15, .offset_x = 2, .offset_y = -15,
          .texture = { .texture_base = 0x80003CD4 },
    },
    { .code_point = '6', 
          .advance_x = 13,
          .width = 12, .height = 15, .offset_x = 1, .offset_y = -15,
          .texture = { .texture_base = 0x800044B0 },
    },
    { .code_point = '7', 
          .advance_x = 13,
          .width = 12, .height = 15, .offset_x = 2, .offset_y = -15,
          .texture = { .texture_base = 0x800044BC },
    },
    { .code_point = '8', 
          .advance_x = 13,
          .width = 12, .height = 15, .offset_x = 1, .offset_y = -15,
          .texture = { .texture_base = 0x800000C8 },
    },
    { .code_point = '9', 
          .advance_x = 13,
          .width = 12, .height = 15, .offset_x = 1, .offset_y = -15,
          .texture = { .texture_base = 0x80003CC8 },
    },
    { .code_point = 'O', 
          .advance_x = 24,
          .width = 20, .height = 23, .offset_x = 2, .offset_y = -23,
          .texture = { .texture_base = 0x80000040 },
    },
    { .code_point = 'T', 
          .advance_x = 18,
          .width = 20, .height = 23, .offset_x = 0, .offset_y = -23,
          .texture = { .texture_base = 0x80000054 },
    },
    { .code_point = 'e', 
          .advance_x = 17,
          .width = 16, .height = 17, .offset_x = 2, .offset_y = -17,
          .texture = { .texture_base = 0x80000090 },
    },
    { .code_point = 'h', 
          .advance_x = 19,
          .width = 16, .height = 24, .offset_x = 2, .offset_y = -24,
          .texture = { .texture_base = 0x80000080 },
    },
    { .code_point = 'n', 
          .advance_x = 18,
          .width = 12, .height = 17, .offset_x = 3, .offset_y = -17,
          .texture = { .texture_base = 0x800000B0 },
    },
    { .code_point = 'o', 
          .advance_x = 19,
          .width = 16, .height = 17, .offset_x = 2, .offset_y = -17,
          .texture = { .texture_base = 0x800000A0 },
    },
    { .code_point = 'r', 
          .advance_x = 12,
          .width = 12, .height = 17, .offset_x = 3, .offset_y = -17,
          .texture = { .texture_base = 0x800000BC },
    },
    { .code_point = 'w', 
          .advance_x = 23,
          .width = 24, .height = 17, .offset_x = 0, .offset_y = -17,
          .texture = { .texture_base = 0x80000068 },
    },
};

// fonts
static tRendererFont fonts[RENDERER_FONT_COUNT] =  {
    { .glyph_count = 10, .glyphs = glyphs + 0, .space_width = 7 },
    { .glyph_count = 8, .glyphs = glyphs + 10, .space_width = 11 },
};

// text-tiles
static tRendererTileHandle text_tiles[RENDERER_TEXT_CHARACTER_COUNT] = {
    5, 6, 7, 8, 9, 
    10, 11, 12, 13, 14, 
};

// text-characters
static uint16_t characters[RENDERER_TEXT_CHARACTER_COUNT];

// texts
tRendererText renderer_texts[RENDERER_TEXT_COUNT] = {
    { .tile_count = 5, .tile = text_tiles + 0, .text = characters + 0,
          .font = fonts + 0,
          .position_x = 150, .position_y = 270, .alignment_h = TEXT_CENTER, .alignment_v = TEXT_MIDDLE },
    { .tile_count = 5, .tile = text_tiles + 5, .text = characters + 5,
          .font = fonts + 1,
          .position_x = 150, .position_y = 300, .alignment_h = TEXT_CENTER, .alignment_v = TEXT_MIDDLE },
};


