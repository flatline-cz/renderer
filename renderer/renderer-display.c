//
// Created by tumap on 8/2/22.
//
#include <stdbool.h>
#include <string.h>
#include <stdio.h>
#include "renderer.h"
#include "video-core-hw.h"

static tRendererTileHandle root_tile = RENDERER_NULL_HANDLE;

#define VIDEO_BUFFERS 2

// a local copy of graphics scene as it was last rendered
// used for detecting the changes as only these are actually rendered
typedef struct tVideoBuffer {
    bool not_rendered_at_all;
    tRendererTile tile_cache[RENDERER_TILES_COUNT];
} tVideoBuffer;
static tVideoBuffer buffers[VIDEO_BUFFERS];

void renderer_init() {
    unsigned i;
    for (i = 0; i < VIDEO_BUFFERS; i++)
        buffers[i].not_rendered_at_all = true;
}

static void update_tile_cache(unsigned buffer);

// VideoCore commands & buffer
#define VIDEOCODE_BUFFER_SIZE           (8*1024)
static uint8_t video_buffer[VIDEOCODE_BUFFER_SIZE];
static unsigned video_buffer_length;


static void vc_cmd_start();

static void vc_cmd_end_of_list();

static bool vc_cmd_rect_color(tRendererPosition left,
                              tRendererPosition top,
                              tRendererPosition width,
                              tRendererPosition height,
                              tRendererColor color);

void renderer_show_screen(tRendererTileHandle tile) {
    if (root_tile != tile) {
        root_tile = tile;
        renderer_init();
    }
}


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

    // color has changed?
    if (cache->color.blue != tile->color.blue
        || cache->color.green != tile->color.green
        || cache->color.red != tile->color.red
        || cache->color.alpha != tile->color.alpha) {
        // redraw current rectangle
        list->count = 1;
        list->area[0].x1 = tile->position_left;
        list->area[0].x2 = tile->position_right;
        list->area[0].y1 = tile->position_top;
        list->area[0].y2 = tile->position_bottom;
        return;
    }

    // TODO: check other changes (texture, etc)

    // no changes
    list->count = 0;
}

static void redraw_tile(tVideoBuffer *buffer, tRendererTile *tile, tRectangle *bounding_box) {
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
    vc_cmd_rect_color(x1, y1, x2 + 1 - x1, y2 + 1 - y1, tile->color);

    // render all children
    unsigned i;
    for (i = 0; i < tile->children_count; i++) {
        tRendererTile *child = renderer_tiles + tile->children_tiles[i];
        if (child->tile_visible)
            redraw_tile(buffer, child, bounding_box);
    }


}

static void render_tile(tVideoBuffer *buffer, tRendererTileHandle tile_handle) {
    static tRedrawList list;
    tRendererTile *tile = renderer_tiles + tile_handle;

    // compute redraw areas
    compute_area_to_redraw(buffer, tile, tile_handle, &list);

    if (list.count != 0) {
        // redraw areas
        unsigned i;
        for (i = 0; i < list.count; i++)
            redraw_tile(buffer, renderer_tiles + tile->root_tile, list.area + i);
    } else {
        // render children?
        if (tile->tile_visible) {
            unsigned i;
            for (i = 0; i < tile->children_count; i++)
                render_tile(buffer, tile->children_tiles[i]);
        }
    }

}

void renderer_update_display(unsigned buffer) {
    if (root_tile == RENDERER_NULL_HANDLE)
        return;
    vc_cmd_start();
    render_tile(buffers + buffer, root_tile);
    vc_cmd_end_of_list();
    vc_cmd_execute(video_buffer, video_buffer_length);
    update_tile_cache(buffer);
}


static void update_tile_cache(unsigned buffer) {
    memcpy(buffers[buffer].tile_cache, renderer_tiles, sizeof(tRendererTile) * RENDERER_TILES_COUNT);
    buffers[buffer].not_rendered_at_all = false;
}

static bool vc_cmd_rect_color(tRendererPosition left,
                              tRendererPosition top,
                              tRendererPosition width,
                              tRendererPosition height,
                              tRendererColor color) {
    // command parameters alignment is:
    // cmd:     1 byte
    // left:    2 bytes (LSB first)
    // top:     2 bytes (LSB first)
    // width:   2 bytes (LSB first)
    // height:  2 bytes (LSB first)
    // color:   3 bytes (special encoding)
    // === total: 12 byte ===
    if (video_buffer_length + 12 >= VIDEOCODE_BUFFER_SIZE)
        return false;

    video_buffer[video_buffer_length++] = 0x00;
    video_buffer[video_buffer_length++] = left & 0xff;
    video_buffer[video_buffer_length++] = top & 0xff;
    video_buffer[video_buffer_length++] = width & 0xff;
    video_buffer[video_buffer_length++] = height & 0xff;
    video_buffer[video_buffer_length++] =
            ((left >> 8) & 3)
            | (((top >> 8) & 3) << 2)
            | (((width >> 8) & 3) << 4)
            | (((height >> 8) & 3) << 6);

    uint8_t red = ((color.red) >> 3) & 0x1f;
    uint8_t green = ((color.green) >> 3) & 0x1f;
    uint8_t blue = ((color.blue) >> 3) & 0x1f;
    uint8_t alpha = ((color.alpha) >> 4) & 0x0f;

    video_buffer[video_buffer_length++] = red | ((green << 5) & 0xe0);
    video_buffer[video_buffer_length++] = ((green >> 3) & 0x03) | (blue << 2);
    video_buffer[video_buffer_length++] = alpha;

    video_buffer[video_buffer_length++] = 0;
    video_buffer[video_buffer_length++] = 0;
    video_buffer[video_buffer_length++] = 0;
    video_buffer[video_buffer_length++] = 0;

    return true;
}

static void vc_cmd_end_of_list() {
    video_buffer[video_buffer_length++] = 0x80;
}

static void vc_cmd_start() {
    video_buffer_length = 0;
}

