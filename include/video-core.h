//
// Created by tumap on 10/13/22.
//

#ifndef RENDERER_TEST_VIDEO_CORE_H
#define RENDERER_TEST_VIDEO_CORE_H

#include <stdbool.h>
#include <renderer-definition.h>
#include <renderer-scene.h>

void vc_init();

bool vc_handle();

void vc_set_render_mode(tRendererScreenGraphics* graphics);

void vc_set_playback_mode(tRendererVideoDescriptor* descriptor,
                          rRendererVideoCallback callback,
                          const void* callback_arg);

void vc_set_display_off();
#endif //RENDERER_TEST_VIDEO_CORE_H
