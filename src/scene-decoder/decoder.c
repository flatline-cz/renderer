//
// Created by tumap on 6/1/23.
//
#include <stdbool.h>
#include "decoder.h"
#include "renderer-definition.h"
#include "spi-flash.h"
#include "system-config.h"

#ifndef PIC32

#   include <stdio.h>
#   include "profile.h"

#   define TRACE(msg, ...) fprintf(stderr, "%d.%03ds : "  msg  "\n", TIME_GET/1000, TIME_GET%1000, ##__VA_ARGS__);
#else
#   define TRACE(msg, ...)
#endif

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

static inline void input_init() {
    input_position = 4;
    input_buffer_start = 0;
    spi_flash_read_sync(FLASH_BANK_SCENE, 0, input_buffer, BUFFER_LENGTH);
    input_data_length =
            (((uint32_t) input_buffer[0]) << 0) |
            (((uint32_t) input_buffer[1]) << 8) |
            (((uint32_t) input_buffer[2]) << 16) |
            (((uint32_t) input_buffer[3]) << 24);
    memory_size = 0;
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

static inline bool input_get_byte(uint8_t *buffer) {
    if (input_position >= input_data_length)
        return false;
    if (input_position - input_buffer_start >= BUFFER_LENGTH) {
        input_buffer_start += BUFFER_LENGTH;
        spi_flash_read_sync(FLASH_BANK_SCENE, input_buffer_start, input_buffer, BUFFER_LENGTH);
    }
    *buffer = input_buffer[input_position - input_buffer_start];
    input_position++;
    return true;
}

static inline bool input_get_word(uint16_t *buffer) {
    uint8_t b1;
    uint8_t b2;
    if (!input_get_byte(&b1))
        return false;
    if (!input_get_byte(&b2))
        return false;
    *buffer = (((uint16_t) b2) << 8) | b1;
    return true;
}

static inline bool input_get_dword(uint32_t *buffer) {
    uint8_t b1;
    uint8_t b2;
    uint8_t b3;
    uint8_t b4;
    if (!input_get_byte(&b1))
        return false;
    if (!input_get_byte(&b2))
        return false;
    if (!input_get_byte(&b3))
        return false;
    if (!input_get_byte(&b4))
        return false;
    *buffer =
            (((uint32_t) b1) << 0) |
            (((uint32_t) b2) << 8) |
            (((uint32_t) b3) << 16) |
            (((uint32_t) b4) << 24);
    return true;
}

static bool decode_color_table() {
    // number of colors
    if (!input_get_word(&renderer_colors_simple_count))
        return false;

    // allocate memory
    renderer_colors = allocate(2 * renderer_colors_simple_count, 2);

    // fill color table
    unsigned i;
    for (i = 0; i < renderer_colors_simple_count; i++) {
        if (!input_get_word(renderer_colors + i))
            return false;
    }

    return true;
}

static bool decode_tiles() {
    // number of tiles
    if (!input_get_word(&renderer_tiles_count))
        return false;

    // allocate memory
    renderer_tiles = allocate(renderer_tiles_count * sizeof(tRendererTile), 4);

    // fill tile table
    unsigned i;
    for (i = 0; i < renderer_tiles_count; i++) {
        tRendererTile *tile = renderer_tiles + i;

        // decode tree structure field
        if (!input_get_word(&tile->root_tile))
            return false;
        if (!input_get_word(&tile->parent_tile))
            return false;
        if (!input_get_word(&tile->children_count))
            return false;
        if (!input_get_word(&tile->children_list_index))
            return false;

        // position
        if (!input_get_word(&tile->position_left))
            return false;
        if (!input_get_word(&tile->position_top))
            return false;
        if (!input_get_word(&tile->position_width))
            return false;
        if (!input_get_word(&tile->position_height))
            return false;
        uint8_t visible;
        if (!input_get_byte(&visible))
            return false;
        tile->tile_visible = visible == 1;

        // update rendering position
        tile->position_right = tile->position_left + tile->position_width - 1;
        tile->position_bottom = tile->position_top + tile->position_height - 1;

        // color
        if (!input_get_word(&tile->color_handle))
            return false;
        // FIXME: map handle to color
        uint16_t color = renderer_colors[tile->color_handle];
        tile->color.red = ((color >> 12) & 0x0f) * 17;
        tile->color.green = ((color >> 8) & 0x0f) * 17;
        tile->color.blue = ((color >> 4) & 0x0f) * 17;
        tile->color.alpha = ((color >> 0) & 0x0f) * 17;

        // decode tile type
        uint8_t tile_type;
        if (!input_get_byte(&tile_type))
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
            if (!input_get_dword(&tile->texture.base))
                return false;
            if (!input_get_word(&tile->texture.stripe_length))
                return false;
            uint8_t texture_compression;
            if (!input_get_byte(&texture_compression))
                return false;
            if (texture_compression >= 2)
                return false;
            tile->texture.packed_alpha = (texture_compression == 1);
        }

        // FIXME: decode tile visual properties
        tile->overlapping_children = false;
        tile->parent_visible = true;


        // FIXME: decode text properties

    }

    return true;
}

static bool decode_screens() {
    // number of screens
    if (!input_get_word(&renderer_screen_count))
        return false;

    // allocate memory
    renderer_screens = allocate(sizeof(tRendererScreen) * renderer_screen_count, 2);

    // fill screen table
    int i;
    for (i = 0; i < renderer_screen_count; i++) {
        if (!input_get_word(&renderer_screens[i].root_tile))
            return false;
        if (!input_get_word(&renderer_screens[i].graphics))
            return false;
    }

    return true;
}

static bool decode_child_index() {

    // index records
    uint16_t count;
    if (!input_get_word(&count))
        return false;

    // allocate memory
    renderer_child_index = allocate(count * 2, 2);

    // fill index
    int i;
    for (i = 0; i < count; i++) {
        if (!input_get_word(renderer_child_index + i))
            return false;
    }

    return true;
}

static bool decode_texture_bundles() {

    // count
    if (!input_get_word(&renderer_graphics_count))
        return false;

    // allocate memory
    renderer_graphics = allocate(renderer_graphics_count, 4);

    int i;

    // read each record
    for (i = 0; i < renderer_graphics_count; i++) {
        if (!input_get_dword(&renderer_graphics[i].base))
            return false;

        if (!input_get_dword(&renderer_graphics[i].length))
            return false;
    }

    return true;
}


bool scene_decoder_decode() {
    TRACE("Decoding started")
    input_init();

    // create color table
    if (!decode_color_table())
        return false;

    // decode tiles
    if (!decode_tiles())
        return false;

    // decode screens
    if (!decode_screens())
        return false;

    // decode node child index
    if (!decode_child_index())
        return false;

    //decode graphics contexts
    if (!decode_texture_bundles())
        return false;

    // TODO:
    renderer_texts_count = 0;
    renderer_videos_count = 0;

    TRACE("Decoding finished, memory used = %d bytes", memory_size)
    return true;
}
