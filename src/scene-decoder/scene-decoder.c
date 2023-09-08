//
// Created by tumap on 6/1/23.
//
#include <stdbool.h>
#include "scene-decoder.h"
#include "renderer-definition.h"
#include "spi-flash.h"
#include "system-config.h"
#include "trace.h"
#include "memcpy.h"

static bool use_default;

#define BUFFER_LENGTH                   256
static uint8_t input_buffer[BUFFER_LENGTH];
static uint32_t input_buffer_start;
static uint32_t input_position;
static uint32_t input_data_length;

#define SCENE_MEMORY_KB                 16
#define SCENE_MEMORY                    ((SCENE_MEMORY_KB)*1024)
static uint8_t memory[SCENE_MEMORY];
static unsigned memory_size;

uint16_t *renderer_colors;
uint16_t renderer_colors_simple_count;
tRendererText *renderer_texts;
uint16_t renderer_texts_count;
tRendererTile *renderer_tiles;
uint16_t renderer_tiles_count;
tRendererTileHandle *renderer_child_index;
tRendererScreen *renderer_screens;
uint16_t renderer_screen_count;
tRendererVideoDescriptor *renderer_videos;
uint16_t renderer_videos_count;
tRendererScreenGraphics *renderer_graphics;
uint16_t renderer_graphics_count;
tRendererFontGlyph *renderer_font_glyphs;
uint16_t renderer_font_glyphs_count;
tRendererFont *renderer_fonts;
uint16_t renderer_fonts_count;

static inline bool input_init(bool custom) {
    input_position = 8;
    input_buffer_start = 0;
    if (custom) {
        spi_flash_read_sync(FLASH_BANK_SCENE, 0, input_buffer, BUFFER_LENGTH);
    } else {
        memcpy(input_buffer, renderer_data, BUFFER_LENGTH);
    }
    if (((((uint32_t) input_buffer[0]) << 0) |
         (((uint32_t) input_buffer[1]) << 8) |
         (((uint32_t) input_buffer[2]) << 16) |
         (((uint32_t) input_buffer[3]) << 24)) == 0xDEADBEEF) {
        input_data_length =
                (((uint32_t) input_buffer[4]) << 0) |
                (((uint32_t) input_buffer[5]) << 8) |
                (((uint32_t) input_buffer[6]) << 16) |
                (((uint32_t) input_buffer[7]) << 24);
    } else {
        return false;
    }
    memory_size = 0;
    return true;
}

static inline void *__attribute((always_inline)) allocate(unsigned size, unsigned alignment) {
    switch (alignment) {
        case 2:
            memory_size = (memory_size + 1) & ~1;
            break;
        case 4:
            memory_size = (memory_size + 3) & ~3;
            break;
        default:
            break;
    }
    void *ret = memory + memory_size;
    memory_size += size;
    return ret;
}

static inline bool input_get_byte(bool custom, uint8_t *buffer) {
    if (input_position >= input_data_length)
        return false;
    if (input_position - input_buffer_start >= BUFFER_LENGTH) {
        input_buffer_start += BUFFER_LENGTH;
        if (custom)
            spi_flash_read_sync(FLASH_BANK_SCENE, input_buffer_start, input_buffer, BUFFER_LENGTH);
        else
            memcpy(input_buffer, renderer_data + input_buffer_start, BUFFER_LENGTH);
    }
    *buffer = input_buffer[input_position - input_buffer_start];
    input_position++;
    return true;
}

static inline bool input_get_word(bool custom, uint16_t *buffer) {
    uint8_t b1;
    uint8_t b2;
    if (!input_get_byte(custom, &b1))
        return false;
    if (!input_get_byte(custom, &b2))
        return false;
    *buffer = (((uint16_t) b2) << 8) | b1;
    return true;
}

static inline bool input_get_dword(bool custom, uint32_t *buffer) {
    uint8_t b1;
    uint8_t b2;
    uint8_t b3;
    uint8_t b4;
    if (!input_get_byte(custom, &b1))
        return false;
    if (!input_get_byte(custom, &b2))
        return false;
    if (!input_get_byte(custom, &b3))
        return false;
    if (!input_get_byte(custom, &b4))
        return false;
    *buffer =
            (((uint32_t) b1) << 0) |
            (((uint32_t) b2) << 8) |
            (((uint32_t) b3) << 16) |
            (((uint32_t) b4) << 24);
    return true;
}

static bool decode_color_table(bool custom) {
    TRACE("- Decoding color table")
    // number of colors
    if (!input_get_word(custom, &renderer_colors_simple_count))
        return false;

    // allocate memory
    renderer_colors = allocate(2 * renderer_colors_simple_count, 2);

    // fill color table
    unsigned i;
    for (i = 0; i < renderer_colors_simple_count; i++) {
        if (!input_get_word(custom, renderer_colors + i))
            return false;
    }

    TRACE("- Decoded %d colors", renderer_colors_simple_count)

    return true;
}

static bool decode_texture(bool custom, tRendererTexture *tex) {
    if (!input_get_dword(custom, &tex->base))
        return false;
    if (!input_get_word(custom, &tex->stripe_length))
        return false;
    uint8_t texture_compression;
    if (!input_get_byte(custom, &texture_compression))
        return false;
    if (texture_compression >= 2)
        return false;
    tex->packed_alpha = (texture_compression == 1);
    TRACE("-- Decoded texture at 0x%08X", tex->base)
    return true;
}

static bool decode_tiles(bool custom) {
    TRACE("- Decoding tiles")
    // number of tiles
    if (!input_get_word(custom, &renderer_tiles_count))
        return false;

    // allocate memory
    renderer_tiles = allocate(renderer_tiles_count * sizeof(tRendererTile), 4);

    // fill tile table
    unsigned i;
    for (i = 0; i < renderer_tiles_count; i++) {
        tRendererTile *tile = renderer_tiles + i;

        // decode tree structure field
        if (!input_get_word(custom, &tile->root_tile))
            return false;
        if (!input_get_word(custom, &tile->parent_tile))
            return false;
        if (!input_get_word(custom, &tile->children_count))
            return false;
        if (!input_get_word(custom, &tile->children_list_index))
            return false;

        // position
        if (!input_get_word(custom, &tile->position_left))
            return false;
        if (!input_get_word(custom, &tile->position_top))
            return false;
        if (!input_get_word(custom, &tile->position_width))
            return false;
        if (!input_get_word(custom, &tile->position_height))
            return false;
        uint8_t visible;
        if (!input_get_byte(custom, &visible))
            return false;
        tile->tile_visible = visible == 1;

        // update rendering position
        tile->position_right = tile->position_left + tile->position_width - 1;
        tile->position_bottom = tile->position_top + tile->position_height - 1;

        // color
        if (!input_get_word(custom, &tile->color_handle))
            return false;
        // FIXME: map handle to color
        uint16_t color = renderer_colors[tile->color_handle];
        tile->color.red = ((color >> 12) & 0x0f) * 17;
        tile->color.green = ((color >> 8) & 0x0f) * 17;
        tile->color.blue = ((color >> 4) & 0x0f) * 17;
        tile->color.alpha = ((color >> 0) & 0x0f) * 17;

        // decode tile type
        uint8_t tile_type;
        if (!input_get_byte(custom, &tile_type))
            return false;
        switch (tile_type) {
            case 0:
                tile->rendering_mode = COLOR;
                break;
            case 1:
                tile->rendering_mode = ALPHA_TEXTURE;
                break;
            default:
                return false;
        }

        // decode texture properties
        if (tile_type == 1) {
            if (!decode_texture(custom, &tile->texture))
                return false;
        }

        // FIXME: decode tile visual properties
        tile->overlapping_children = false;
        tile->parent_visible = true;
    }

    TRACE("- Decoded %d tiles", renderer_tiles_count)

    return true;
}

static bool decode_screens(bool custom) {
    TRACE("- Decoding screens")
    // number of screens
    if (!input_get_word(custom, &renderer_screen_count))
        return false;

    // allocate memory
    renderer_screens = allocate(sizeof(tRendererScreen) * renderer_screen_count, 2);

    // fill screen table
    int i;
    for (i = 0; i < renderer_screen_count; i++) {
        if (!input_get_word(custom, &renderer_screens[i].root_tile))
            return false;
        if (!input_get_word(custom, &renderer_screens[i].graphics))
            return false;
    }

    TRACE("- Decoded %d screens", renderer_screen_count)

    return true;
}

static bool decode_child_index(bool custom) {
    TRACE("- Decoding tile tree")

    // index records
    uint16_t count;
    if (!input_get_word(custom, &count))
        return false;

    // allocate memory
    renderer_child_index = allocate(count * 2, 2);

    // fill index
    int i;
    for (i = 0; i < count; i++) {
        if (!input_get_word(custom, renderer_child_index + i))
            return false;
    }

    TRACE("- Decoded %d records", count)

    return true;
}

static bool decode_font_glyphs(bool custom) {
    TRACE("- Decoding font glyphs")
    // number of glyphs
    if (!input_get_word(custom, &renderer_font_glyphs_count))
        return false;

    if (!renderer_font_glyphs_count) {
        TRACE("- No font glyphs")
        renderer_font_glyphs = NULL;
        return true;
    }

    // allocate memory
    renderer_font_glyphs = allocate(sizeof(tRendererFontGlyph) * renderer_font_glyphs_count, 4);

    // fetch each glyphs
    int i;
    for (i = 0; i < renderer_font_glyphs_count; i++) {
        if (!input_get_word(custom, &renderer_font_glyphs[i].code_point))
            return false;
        if (!input_get_word(custom, &renderer_font_glyphs[i].width))
            return false;
        if (!input_get_word(custom, &renderer_font_glyphs[i].height))
            return false;
        if (!input_get_word(custom, (uint16_t *) &renderer_font_glyphs[i].offset_x))
            return false;
        if (!input_get_word(custom, (uint16_t *) &renderer_font_glyphs[i].offset_y))
            return false;
        if (!input_get_word(custom, &renderer_font_glyphs[i].advance_x))
            return false;
        if (!decode_texture(custom, &renderer_font_glyphs[i].texture))
            return false;
    }

    TRACE("- Decoded %d font glyphs", renderer_font_glyphs_count)
    return true;
}

static bool decode_fonts(bool custom) {
    TRACE("- Decoding fonts")
    // number of fonts
    if (!input_get_word(custom, &renderer_fonts_count))
        return false;

    if (!renderer_fonts_count) {
        TRACE("- No fonts")
        renderer_fonts = NULL;
        return true;
    }

    // allocate memory
    renderer_fonts = allocate(sizeof(tRendererFont) * renderer_fonts_count, 4);

    // fetch each font
    int i;
    for (i = 0; i < renderer_fonts_count; i++) {
        if (!input_get_word(custom, &renderer_fonts[i].glyph_count))
            return false;
        if (!input_get_word(custom, &renderer_fonts[i].first_glyph))
            return false;
        if (!input_get_word(custom, &renderer_fonts[i].space_width))
            return false;
    }

    TRACE("- Decoded %d fonts", renderer_fonts_count)

    return true;
}

static bool decode_texts(bool custom) {
    TRACE("- Decoding texts")

    // length of all texts
    uint16_t texts_length;
    if (!input_get_word(custom, &texts_length))
        return false;

    // number of texts
    if (!input_get_word(custom, &renderer_texts_count))
        return false;

    if (!renderer_texts_count) {
        TRACE("- No texts")
        renderer_texts = NULL;
        return true;
    }

    if (!texts_length)
        return false;

    // allocate memory for texts
    uint16_t *texts = allocate(texts_length * 2, 2);

    // allocate memory
    renderer_texts = allocate(sizeof(tRendererText) * renderer_texts_count, 4);

    // fetch each text
    int i, j;
    for (i = 0; i < renderer_texts_count; i++) {
        if (!input_get_word(custom, &renderer_texts[i].tile_count))
            return false;
        if (!input_get_word(custom, &renderer_texts[i].tile))
            return false;
        if (!input_get_word(custom, &renderer_texts[i].font))
            return false;
        if (!input_get_word(custom, &renderer_texts[i].position_x))
            return false;
        if (!input_get_word(custom, &renderer_texts[i].position_y))
            return false;
        uint8_t b;
        if (!input_get_byte(custom, &b))
            return false;
        switch (b) {
            case 1:
                renderer_texts[i].alignment_h = TEXT_CENTER;
                break;
            case 2:
                renderer_texts[i].alignment_h = TEXT_RIGHT;
                break;
            case 0:
            default:
                renderer_texts[i].alignment_h = TEXT_LEFT;
                break;
        }
        if (!input_get_byte(custom, &b))
            return false;
        switch (b) {
            case 1:
                renderer_texts[i].alignment_v = TEXT_MIDDLE;
                break;
            case 2:
                renderer_texts[i].alignment_v = TEXT_BOTTOM;
                break;
            case 0:
            default:
                renderer_texts[i].alignment_v = TEXT_TOP;
                break;
        }
        renderer_texts[i].text = texts;
        for (j = 0; j < renderer_texts[i].tile_count; j++) {
            if (!input_get_word(custom, texts))
                return false;
            texts++;
        }
    }

    TRACE("- Decoded %d texts", renderer_texts_count)

    return true;
}

static bool decode_texture_bundles(bool custom) {
    TRACE("- Decoding texture bundles")

    // count
    if (!input_get_word(custom, &renderer_graphics_count))
        return false;

    // allocate memory
    renderer_graphics = allocate(renderer_graphics_count, 4);

    int i;

    // read each record
    for (i = 0; i < renderer_graphics_count; i++) {
        if (!input_get_dword(custom, &renderer_graphics[i].base))
            return false;

        if (!input_get_dword(custom, &renderer_graphics[i].length))
            return false;
        TRACE("-- Decoded bundle #%d addr=0x%08X, length=0x%08X", i,
              renderer_graphics[i].base, renderer_graphics[i].length)
    }

    TRACE("- Decoded %d texture bundles", renderer_graphics_count)

    return true;
}

bool scene_decoder_use_default() {
    return use_default;
}

bool scene_decoder_decode(bool custom) {
    use_default = !custom;

    TRACE("Decoding started")
    if (!input_init(custom))
        return false;

    // create color table
    if (!decode_color_table(custom)) {
        TRACE("Scene decoder: Invalid color table")
        return false;
    }

    // decode tiles
    if (!decode_tiles(custom)) {
        TRACE("Scene decoder: Invalid tile list")
        return false;
    }

    // decode screens
    if (!decode_screens(custom)) {
        TRACE("Scene decoder: Invalid screen list")
        return false;
    }

    // decode node child index
    if (!decode_child_index(custom)) {
        TRACE("Scene decoder: Invalid child index")
        return false;
    }

    // decode font glyphs
    if (!decode_font_glyphs(custom)) {
        TRACE("Scene decoder: Invalid glyph list")
        return false;
    }

    // decode fonts
    if (!decode_fonts(custom)) {
        TRACE("Scene decoder: Invalid font list")
        return false;
    }

    // decode texts
    if (!decode_texts(custom)) {
        TRACE("Scene decoder: Invalid text list")
        return false;
    }

    //decode graphics contexts
    if (!decode_texture_bundles(custom)) {
        TRACE("Scene decoder: Invalid texture bundles")
        return false;
    }

    // TODO: video index decoding
    renderer_videos_count = 0;

    TRACE("Decoding finished, memory used = %d bytes", memory_size)
    return true;
}
