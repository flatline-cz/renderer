//
// Created by tumap on 8/15/22.
//

#ifndef RENDERER_VIDEO_CORE_HW_H
#define RENDERER_VIDEO_CORE_HW_H

#include <stdbool.h>
#include <stdint.h>

#define RENDERER_MODE_DISPLAY_OFF       0
#define RENDERER_MODE_NORMAL            1
#define RENDERER_MODE_VIDEO             2

bool vc_set_rendering_mode(uint8_t mode);

bool vc_cmd_execute(const uint8_t *data, unsigned length);

bool vc_check_vsync();

bool vc_check_interrupt();




#endif //RENDERER_VIDEO_CORE_HW_H
