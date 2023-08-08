//
// Created by tumap on 8/7/23.
//

#ifndef HEAD_UNIT_VIDEO_CORE_HW_H
#define HEAD_UNIT_VIDEO_CORE_HW_H

#include <stdbool.h>
#include <stdint.h>

void video_core_hw_init();

bool video_core_hw_handle();

bool video_core_hw_idle();

bool video_core_hw_send(const uint8_t *prefix, uint16_t prefix_length,
                        const uint8_t *data, uint16_t data_length);

bool video_core_hw_exchange(const uint8_t *data_send, uint8_t *data_receive, uint16_t length);

#endif //HEAD_UNIT_VIDEO_CORE_HW_H
