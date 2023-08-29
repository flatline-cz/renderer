//
// Created by tumap on 8/2/22.
//
#include <stdbool.h>
#include <renderer-scene.h>
#include <video-core.h>
#include "memcpy.h"

extern tRendererTileHandle root_tile;

// FIXME: allocate memory
static uint8_t tile_cache_mem[8 * 1024];

// a local copy of graphics scene as it was last rendered
// used for detecting the changes as only these are actually rendered
typedef struct tVideoBuffer {
    bool not_rendered_at_all;
    tRendererTile tile_cache[300];
} tVideoBuffer;
static tVideoBuffer buffer;

tRendererTileHandle root_tile;
tRendererGraphicsHandle graphics_handle;


static void update_tile_cache();

// VideoCore commands & buffer
#define VIDEO_CORE_BUFFER_SIZE           (8*1024)
static uint8_t video_buffer[VIDEO_CORE_BUFFER_SIZE];
static unsigned video_buffer_length;


static void vc_cmd_rect_color(tRendererPosition left,
                              tRendererPosition top,
                              tRendererPosition width,
                              tRendererPosition height,
                              tRendererColor color,
                              uint8_t *buffer,
                              uint16_t max_length,
                              uint16_t *length);

static void vc_cmd_rect_texture(tRendererPosition left,
                                tRendererPosition top,
                                tRendererPosition width,
                                tRendererPosition height,
                                tRendererColor color,
                                tRendererTexture *texture,
                                tRendererPosition texture_left,
                                tRendererPosition texture_top,
                                uint8_t *buffer,
                                uint16_t max_length,
                                uint16_t *length);


typedef struct tRectangle {
    tRendererPosition x1;
    tRendererPosition x2;
    tRendererPosition y1;
    tRendererPosition y2;
} tRectangle;

#define REDRAW_LIST_SIZE        5
typedef struct tRedrawList {
    unsigned count;
    tRectangle area[REDRAW_LIST_SIZE];
} tRedrawList;

void renderer_init() {
    root_tile=RENDERER_NULL_HANDLE;
    graphics_handle=RENDERER_NULL_HANDLE;
}

static void compute_area_to_redraw(tVideoBuffer *buffer,
                                   tRendererTile *tile,
                                   tRendererTileHandle tile_handle,
                                   tRedrawList *list) {
    register tRendererTile *cache = buffer->tile_cache + tile_handle;

    // visibility has changed?
    register bool tile_visible = tile->tile_visible && tile->parent_visible;
    register bool cache_visible = cache->tile_visible && cache->parent_visible;

    // tile not visible and has not been?
    if (!tile_visible && !cache_visible && !buffer->not_rendered_at_all) {
        // nothing to draw
        list->count = 0;
        return;
    }

    // tile is visible and has not been?
    if ((tile_visible && !cache_visible) || buffer->not_rendered_at_all) {
        // redraw entire rectangle
        list->count = 1;
        list->area[0].x1 = tile->position_left;
        list->area[0].x2 = tile->position_right;
        list->area[0].y1 = tile->position_top;
        list->area[0].y2 = tile->position_bottom;
        return;
    }

    // tile is not visible and has been?
    if (!tile_visible && cache_visible) {
        // redraw entire previous rectangle
        list->count = 1;
        list->area[0].x1 = cache->position_left;
        list->area[0].x2 = cache->position_right;
        list->area[0].y1 = cache->position_top;
        list->area[0].y2 = cache->position_bottom;
        return;
    }

    // tile is visible and has been

    // position has changed?
    if (tile->position_left != cache->position_left
        || tile->position_width != cache->position_width
        || tile->position_top != cache->position_top
        || tile->position_height != cache->position_height) {
        // redraw entire new rectangle
        list->area[0].x1 = tile->position_left;
        list->area[0].x2 = tile->position_right;
        list->area[0].y1 = tile->position_top;
        list->area[0].y2 = tile->position_bottom;
        list->count = 1;

        // check intersection
        if (tile->position_left > cache->position_right
            || tile->position_right < cache->position_left
            || tile->position_top > cache->position_bottom
            || tile->position_bottom < cache->position_top) {
            // no intersection -> redraw entire previous rectangle
            list->count = 2;
            list->area[1].x1 = cache->position_left;
            list->area[1].x2 = cache->position_right;
            list->area[1].y1 = cache->position_top;
            list->area[1].y2 = cache->position_bottom;
        } else {
            register tRendererPosition x1 = (tile->position_left > cache->position_left)
                                            ? tile->position_left
                                            : cache->position_left;
            register tRendererPosition x2 = (tile->position_right < cache->position_right)
                                            ? tile->position_right
                                            : cache->position_right;
            register tRendererPosition y1 = (tile->position_top > cache->position_top)
                                            ? tile->position_top
                                            : cache->position_top;
            register tRendererPosition y2 = (tile->position_bottom < cache->position_bottom)
                                            ? tile->position_bottom
                                            : cache->position_bottom;
            if (cache->position_top < y1) {
                list->area[list->count].x1 = cache->position_left;
                list->area[list->count].x2 = cache->position_right;
                list->area[list->count].y1 = cache->position_top;
                list->area[list->count].y2 = y1 - 1;
                list->count++;
            }
            if (cache->position_left < x1) {
                list->area[list->count].x1 = cache->position_left;
                list->area[list->count].x2 = x1 - 1;
                list->area[list->count].y1 = y1;
                list->area[list->count].y2 = y2;
                list->count++;
            }
            if (cache->position_right > x2) {
                list->area[list->count].x1 = x2 + 1;
                list->area[list->count].x2 = cache->position_right;
                list->area[list->count].y1 = y1;
                list->area[list->count].y2 = y2;
                list->count++;
            }
            if (cache->position_bottom > y2) {
                list->area[list->count].x1 = cache->position_left;
                list->area[list->count].x2 = cache->position_right;
                list->area[list->count].y1 = y2 + 1;
                list->area[list->count].y2 = cache->position_bottom;
                list->count++;
            }
        }
        return;
    }

    // color or texture has changed?
    if (cache->color.blue != tile->color.blue
        || cache->color.green != tile->color.green
        || cache->color.red != tile->color.red
        || cache->color.alpha != tile->color.alpha
        || cache->texture.packed_alpha != tile->texture.packed_alpha
        || cache->texture.base != tile->texture.base
        || cache->texture.stripe_length != tile->texture.stripe_length) {
        // redraw current rectangle
        list->count = 1;
        list->area[0].x1 = tile->position_left;
        list->area[0].x2 = tile->position_right;
        list->area[0].y1 = tile->position_top;
        list->area[0].y2 = tile->position_bottom;
        return;
    }

    // no changes
    list->count = 0;
}

static void redraw_tile(tVideoBuffer *buffer, tRendererTile *tile,
                        tRectangle *bounding_box,
                        uint8_t *queue_data, uint16_t queue_size,
                        uint16_t *queue_length) {
    // out of bounding box?
    if (tile->position_right < bounding_box->x1
        || tile->position_left > bounding_box->x2
        || tile->position_bottom < bounding_box->y1
        || tile->position_top > bounding_box->y2)
        return;

    // compute intersection
    tRendererPosition x1 = (tile->position_left < bounding_box->x1) ? bounding_box->x1 : tile->position_left;
    tRendererPosition x2 = (tile->position_right > bounding_box->x2) ? bounding_box->x2 : tile->position_right;
    tRendererPosition y1 = (tile->position_top < bounding_box->y1) ? bounding_box->y1 : tile->position_top;
    tRendererPosition y2 = (tile->position_bottom > bounding_box->y2) ? bounding_box->y2 : tile->position_bottom;

    // render color rectangle
    switch (tile->rendering_mode) {
        case ALPHA_TEXTURE:
            vc_cmd_rect_texture(x1, y1, x2 + 1 - x1, y2 + 1 - y1,
                                tile->color,
                                &tile->texture,
                                x1 - tile->position_left,
                                y1 - tile->position_top, \
                                queue_data, queue_size, queue_length);
            break;
        case COLOR:
        default:
            vc_cmd_rect_color(x1, y1, x2 + 1 - x1, y2 + 1 - y1, tile->color,
                              queue_data, queue_size, queue_length);
            break;
    }

    // render all children
    unsigned i;
    for (i = 0; i < tile->children_count; i++) {
        tRendererTile *child = renderer_tiles + renderer_child_index[tile->children_list_index + i];
        if (child->tile_visible)
            redraw_tile(buffer, child, bounding_box, queue_data, queue_size, queue_length);
    }


}

static void render_tile(tVideoBuffer *buffer, tRendererTileHandle tile_handle,
                        uint8_t *queue_data, uint16_t queue_size,
                        uint16_t *queue_length) {
    static tRedrawList list;
    tRendererTile *tile = renderer_tiles + tile_handle;

    // compute redraw areas
    compute_area_to_redraw(buffer, tile, tile_handle, &list);

    if (list.count != 0) {
        // redraw areas
        unsigned i;
        for (i = 0; i < list.count; i++)
            redraw_tile(buffer, renderer_tiles + tile->root_tile, list.area + i,
                        queue_data, queue_size, queue_length);
    } else {
        // render children?
        if (tile->tile_visible) {
            unsigned i;
            for (i = 0; i < tile->children_count; i++)
                render_tile(buffer, renderer_child_index[tile->children_list_index + i],
                            queue_data, queue_size, queue_length);
        }
    }

}

void renderer_update_display(uint8_t *queue_data, uint16_t queue_max_length,
                             uint16_t *queue_length) {
    *queue_length = 0;
    if (root_tile == RENDERER_NULL_HANDLE)
        return;
    render_tile(&buffer, root_tile, queue_data, queue_max_length, queue_length);
    if (*queue_length)
        update_tile_cache();
}


static void update_tile_cache() {
    memcpy(&buffer.tile_cache, renderer_tiles, sizeof(tRendererTile) * renderer_tiles_count);
    buffer.not_rendered_at_all = false;
}

static void vc_cmd_common(tRendererPosition left,
                          tRendererPosition top,
                          tRendererPosition width,
                          tRendererPosition height,
                          uint8_t *buffer,
                          uint16_t max_length,
                          uint16_t *length) {
    buffer[(*length)++] = top & 0xff;
    buffer[(*length)++] = left & 0xff;
    buffer[(*length)++] = (top + height - 1) & 0xff;
    buffer[(*length)++] = (left + width - 1) & 0xff;
    buffer[(*length)++] =
            (((left >> 8) & 3) << 2)
            | (((top >> 8) & 3) << 0)
            | ((((left + width - 1) >> 8) & 3) << 6)
            | ((((top + height - 1) >> 8) & 3) << 4);
}

static void vc_cmd_color(tRendererColor color,
                         uint8_t *buffer,
                         uint16_t max_length,
                         uint16_t *length) {
    uint8_t red = ((color.red) >> 4) & 0x0f;
    uint8_t green = ((color.green) >> 4) & 0x0f;
    uint8_t blue = ((color.blue) >> 4) & 0x0f;
    uint8_t alpha = ((color.alpha) >> 4) & 0x0f;

    buffer[(*length)++] = red | (green << 4);
    buffer[(*length)++] = blue | (alpha << 4);
}

static void vc_cmd_rect_color(tRendererPosition left,
                              tRendererPosition top,
                              tRendererPosition width,
                              tRendererPosition height,
                              tRendererColor color,
                              uint8_t *buffer,
                              uint16_t max_length,
                              uint16_t *length) {
    vc_cmd_common(left, top, width, height,
                  buffer, max_length, length);

    buffer[(*length)++] = 0x00;

    vc_cmd_color(color,
                 buffer, max_length, length);
}

static void vc_cmd_rect_texture(tRendererPosition left,
                                tRendererPosition top,
                                tRendererPosition width,
                                tRendererPosition height,
                                tRendererColor color,
                                tRendererTexture *texture,
                                tRendererPosition texture_left,
                                tRendererPosition texture_top,
                                uint8_t *buffer,
                                uint16_t max_length,
                                uint16_t *length) {
    vc_cmd_common(left, top, width, height,
                  buffer, max_length, length);


    buffer[(*length)++] = 0x01 | ((texture->stripe_length & 0x0300) >> 8);
    buffer[(*length)++] = texture->stripe_length & 0xff;

    uint32_t base = texture->base;
    base += texture_top * texture->stripe_length;
    base += texture_left;
    buffer[(*length)++] = base & 0x0ff;
    buffer[(*length)++] = (base >> 8) & 0x0ff;
    buffer[(*length)++] = (base >> 16) & 0x0ff;

    vc_cmd_color(color,
                 buffer, max_length, length);
}

void renderer_show_screen(tRendererScreenHandle screen_handle) {
    if (screen_handle >= renderer_screen_count)
        return;

    // screen definition
    tRendererScreen *screen = renderer_screens + screen_handle;

    // graphics changes?
    if (graphics_handle != screen->graphics) {
        graphics_handle = screen->graphics;
        vc_set_render_mode(renderer_graphics + graphics_handle);
    }

    if (screen->root_tile == root_tile)
        return;
    root_tile = screen->root_tile;
    buffer.not_rendered_at_all = true;
}

void renderer_show_video(tRendererVideoHandle video_handle,
                         rRendererVideoCallback callback,
                         const void *callback_arg) {
    // configure video core
    vc_set_playback_mode(renderer_videos + video_handle,
                         callback, callback_arg);
}

