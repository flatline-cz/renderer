//
// Created by tumap on 10/13/22.
//

#ifndef RENDERER_TEST_RENDERER_SCENE_H
#define RENDERER_TEST_RENDERER_SCENE_H

#include <stdbool.h>
#include "renderer-definition.h"

void renderer_set_visibility(tRendererTileHandle tile, bool visible);

void renderer_set_position(tRendererTileHandle tile_handle,
                           tRendererPosition left, tRendererPosition top);

void renderer_set_color(tRendererTileHandle tile, tRendererColor color);

void renderer_set_text(tRendererTileHandle tile, const char *text);

void renderer_show_screen(tRendererScreenHandle screen_handle);

typedef void (*rRendererVideoCallback)(const void*);

void renderer_show_video(tRendererVideoHandle video_handle,
                         rRendererVideoCallback callback,
                         const void* callback_arg);

void renderer_turn_off();

#endif //RENDERER_TEST_RENDERER_SCENE_H
