//
// Created by tumap on 6/1/23.
//
#include <stdbool.h>
#include <stdint.h>
#include "decoder.h"

extern uint8_t *scene_content;
extern uint32_t scene_context_length;


static uint32_t input_position;

static inline void input_init() {
    input_position = 0;
}

static inline bool input_get_byte(uint8_t *buffer) {
    if (input_position < scene_context_length) {
        *buffer = scene_content[input_position++];
        return true;
    }
    return false;
}

static inline bool input_get_word(uint16_t *buffer) {
    if (input_position + 1 < scene_context_length) {
        *buffer = (((uint16_t) scene_content[input_position]) << 8) | scene_content[input_position + 1];
        input_position += 2;
        return true;
    }
    return false;
}

static inline bool input_get_dword(uint32_t *buffer) {
    if (input_position + 3 < scene_context_length) {
        *buffer = (((uint32_t) scene_content[input_position]) << 24) |
                  (((uint32_t) scene_content[input_position + 1]) << 16) |
                  (((uint32_t) scene_content[input_position + 2]) << 8) |
                  scene_content[input_position + 3];
        input_position += 4;
        return true;
    }
    return false;
}


void scene_decoder_decode() {
    input_init();

    // number of tiles


}
