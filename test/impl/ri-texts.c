#include "renderer.h"
#include "ri-constants.h"

#define RENDERER_FONT_COUNT                                              2
#define RENDERER_GLYPH_COUNT                                             18

// glyphs
static tRendererFontGlyph glyphs[RENDERER_GLYPH_COUNT] = {
    { .code_point = '0', .width = 8, .height = 9, .offset_x = 0, .offset_y = -9, .texture = { .texture_base =  0x8000008C} },
    { .code_point = '1', .width = 4, .height = 9, .offset_x = 0, .offset_y = -9, .texture = { .texture_base =  0x80004088} },
    { .code_point = '2', .width = 8, .height = 9, .offset_x = 0, .offset_y = -9, .texture = { .texture_base =  0x8000248C} },
    { .code_point = '3', .width = 8, .height = 9, .offset_x = 0, .offset_y = -9, .texture = { .texture_base =  0x8000488C} },
    { .code_point = '4', .width = 8, .height = 9, .offset_x = 0, .offset_y = -9, .texture = { .texture_base =  0x80000094} },
    { .code_point = '5', .width = 8, .height = 9, .offset_x = 0, .offset_y = -9, .texture = { .texture_base =  0x80002494} },
    { .code_point = '6', .width = 8, .height = 9, .offset_x = 0, .offset_y = -9, .texture = { .texture_base =  0x80004894} },
    { .code_point = '7', .width = 8, .height = 9, .offset_x = 0, .offset_y = -9, .texture = { .texture_base =  0x8000009C} },
    { .code_point = '8', .width = 8, .height = 9, .offset_x = 0, .offset_y = -9, .texture = { .texture_base =  0x8000249C} },
    { .code_point = '9', .width = 8, .height = 9, .offset_x = 0, .offset_y = -9, .texture = { .texture_base =  0x8000489C} },
    { .code_point = 'O', .width = 12, .height = 9, .offset_x = 0, .offset_y = -9, .texture = { .texture_base =  0x80000080} },
    { .code_point = 'T', .width = 8, .height = 9, .offset_x = 0, .offset_y = -9, .texture = { .texture_base =  0x800000A4} },
    { .code_point = 'e', .width = 8, .height = 7, .offset_x = 0, .offset_y = -7, .texture = { .texture_base =  0x800040A4} },
    { .code_point = 'h', .width = 8, .height = 10, .offset_x = 0, .offset_y = -10, .texture = { .texture_base =  0x80004080} },
    { .code_point = 'n', .width = 8, .height = 7, .offset_x = 0, .offset_y = -7, .texture = { .texture_base =  0x800024A4} },
    { .code_point = 'o', .width = 8, .height = 7, .offset_x = 0, .offset_y = -7, .texture = { .texture_base =  0x80005CA4} },
    { .code_point = 'r', .width = 8, .height = 7, .offset_x = 0, .offset_y = -7, .texture = { .texture_base =  0x800000AC} },
    { .code_point = 'w', .width = 12, .height = 7, .offset_x = 0, .offset_y = -7, .texture = { .texture_base =  0x80002480} },
};

// fonts
static tRendererFont fonts[RENDERER_FONT_COUNT] =  {
    { .glyph_count = 10, .glyphs = glyphs + 0 },
    { .glyph_count = 8, .glyphs = glyphs + 10 },
};

// text-tiles
static tRendererTileHandle text_tiles[RENDERER_TEXT_CHARACTER_COUNT] = {
    7, 8, 9, 10, 11, 
    12, 13, 14, 15, 16, 
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


