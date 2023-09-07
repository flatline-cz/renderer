//
// Created by tumap on 6/1/23.
//

#ifndef HEAD_UNIT_SCENE_DECODER_H
#define HEAD_UNIT_SCENE_DECODER_H

#include <stdbool.h>
#include <stdint.h>

// default dashboard definition
extern const unsigned renderer_data_length;
extern const uint8_t renderer_data[];

bool scene_decoder_decode(bool custom);

bool scene_decoder_use_default();

#endif //HEAD_UNIT_SCENE_DECODER_H
