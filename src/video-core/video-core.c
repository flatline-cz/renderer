//
// Created by tumap on 12/5/22.
//
#include <profile.h>
#include <renderer.h>
#include <video-core.h>
#include <spi-vc.h>
#include "trace.h"
#include "data-upload.h"

// *******************************************
// **  VIDEO CORE POLL CONTEXT              **
// *******************************************

static tTime next_poll_time;

#define POLL_PERIOD_MS          10

// *******************************************
// **  MODE SELECTION CONTEXT               **
// *******************************************

typedef enum tagVCMode {
    DISPLAY_OFF,
    NORMAL,
    VIDEO
} eVCMode;

// actual mode
static eVCMode current_mode;
// target mode
static eVCMode target_mode;
// mode the system is switching to
static eVCMode requested_mode;

// timeout & retry counter
static tTime mode_switch_timeout;
#define MODE_SWITCH_TIMEOUT     25
static unsigned mode_switch_retry;

// *******************************************
// **  RENDERING CONTEXT                    **
// *******************************************

// update timer
static tTime last_rendering;
#define RENDERING_PERIOD        50
#define PLAYBACK_PERIOD         50

//// data exchange buffer
//#define BUFFER_SIZE     (4*1024)
//static uint8_t data_bufferA[BUFFER_SIZE];
//static uint8_t data_bufferB[BUFFER_SIZE];

// rendering textures
static bool clear_screen;
static tRendererScreenGraphics *current_rendering_context;
static tRendererScreenGraphics *target_rendering_context;
#define RENDER_STATE_START              0
#define RENDER_STATE_CLEAR_SCREEN       1
#define RENDER_STATE_CLEAR_SCREEN_WAIT  2
#define RENDER_STATE_UPLOAD_TEXTURE     3
#define RENDER_STATE_RENDERING          4
#define RENDER_STATE_UPLOAD_VIDEO       5
#define RENDER_STATE_PLAYBACK           6
static int render_state;
static tUploadDataRequest texture_request;

//static uint32_t texture_length;
//// -- texture buffer A
//static tSPIFlashRequest texture_requestA;
//// -- texture buffer B
//static tSPIFlashRequest texture_requestB;

// video playback context
static bool video_uploaded;
static uint32_t video_upload_position;
static uint16_t video_frame;
static tRendererVideoDescriptor *video_descriptor;
static rRendererVideoCallback video_callback;
static const void *video_callback_arg;

void vc_cmd_rect_color(tRendererPosition left,
                       tRendererPosition top,
                       tRendererPosition width,
                       tRendererPosition height,
                       tRendererColor color,
                       uint8_t *buffer,
                       uint16_t max_length,
                       uint16_t *length);

// *******************************************
// **  INITIALIZATION ROUTINE               **
// *******************************************

void vc_init() {
    TRACE("Started");

    // initialize poll context
    next_poll_time = 0;

    // reset mode context
    current_mode = DISPLAY_OFF;
    target_mode = DISPLAY_OFF;
    requested_mode = DISPLAY_OFF;
    mode_switch_timeout = 0;
    mode_switch_retry = 0;

    // reset rendering context
    clear_screen = true;
    current_rendering_context = NULL;
    target_rendering_context = NULL;
    last_rendering = 0;

    // reset playback context
    video_uploaded = false;
    video_descriptor = NULL;

    // reset
    upload_data_init();
    renderer_init();
}

void vc_set_render_mode(tRendererScreenGraphics *graphics) {
    target_rendering_context = graphics;
    render_state = clear_screen ? RENDER_STATE_CLEAR_SCREEN : RENDER_STATE_START;
    clear_screen = false;
    last_rendering = 0;
    target_mode = NORMAL;
}

void vc_set_playback_mode(tRendererVideoDescriptor *descriptor,
                          rRendererVideoCallback callback,
                          const void *callback_arg) {
    video_descriptor = descriptor;
    video_uploaded = false;
    video_frame = 0;
    video_upload_position = 0;
    video_callback = callback;
    video_callback_arg = callback_arg;

    target_mode = VIDEO;
}

void vc_set_display_off() {
    target_mode = DISPLAY_OFF;
}

// *******************************************
// **  HANDLING ROUTINE                     **
// *******************************************

#define MAX_QUEUE_LENGTH        (16*1024)
static uint8_t command_queue[MAX_QUEUE_LENGTH];

static uint8_t query_status_buffer[3];

static uint8_t query_status() {
    if (!spi_vc_idle())
        return 0;
    query_status_buffer[0] = 0;
    query_status_buffer[1] = 0xff;
    query_status_buffer[2] = 0xff;
    spi_vc_exchange(query_status_buffer, query_status_buffer, 3);
    return query_status_buffer[2];
}

static uint8_t set_mode_buffer[2];

static void set_mode(uint8_t mode) {
    if (!spi_vc_idle())
        return;
    set_mode_buffer[0] = 4;
    set_mode_buffer[1] = mode;
    spi_vc_exchange(set_mode_buffer, NULL, 2);
}

static uint8_t upload_data_buffer[4];

static void upload_data(uint8_t *data, uint32_t offset, uint32_t length) {
    if (!spi_vc_idle())
        return;
    upload_data_buffer[0] = 0x02;
    upload_data_buffer[1] = (offset >> 16) & 0xff;
    upload_data_buffer[2] = (offset >> 8) & 0xff;
    upload_data_buffer[3] = (offset >> 0) & 0xff;
    spi_vc_send(upload_data_buffer, 4, data, length);
}

static uint8_t set_video_frame_buffer[4];

static void set_video_frame() {
    if (!spi_vc_idle())
        return;
    set_video_frame_buffer[0] = 0x03;
    set_video_frame_buffer[1] = (video_descriptor->frame_offsets[video_frame] >> 16) & 0xff;
    set_video_frame_buffer[2] = (video_descriptor->frame_offsets[video_frame] >> 8) & 0xff;
    set_video_frame_buffer[3] = (video_descriptor->frame_offsets[video_frame] >> 0) & 0xff;
    spi_vc_exchange(set_video_frame_buffer, NULL, 4);
}

typedef enum tagStatus {
    PASS, RETURN_TRUE, RETURN_FALSE
} eStatus;

static eStatus handle_mode(uint8_t status) {
    // get current mode
    current_mode = (status >> 2) & 0x03;

    // special case (playback mode)
    if (requested_mode == VIDEO && current_mode != VIDEO) {
        // display off?
        if (current_mode != DISPLAY_OFF) {
            // mode switch request not set yet?
            if (mode_switch_timeout == 0) {
                set_mode(DISPLAY_OFF);
                mode_switch_timeout = TIME_GET + MODE_SWITCH_TIMEOUT;
                return RETURN_TRUE;
            } else {
                if (mode_switch_timeout > TIME_GET)
                    return RETURN_FALSE;
                set_mode(DISPLAY_OFF);
                mode_switch_timeout = TIME_GET + MODE_SWITCH_TIMEOUT;
                return RETURN_TRUE;
            }
        }

        // DISPLAY IS OFF

        // 1st frame address not sent?
        if (video_frame == 0) {
            // send frame
            set_video_frame();
            video_frame++;
            return RETURN_TRUE;
        }

        // video content uploaded?
        // TODO: implement FLASH reading
        /*
        if (!video_uploaded) {
            static int content_handle = -1;
            if (content_handle == -1) {
                content_handle = open("impl1/texture-intro.bin", O_RDONLY);
                if (content_handle < 0) {
                    perror("VideoContent load");
                    exit(1);
                }
                video_upload_position = 0;
                TRACE("Video content upload started")
            }
            int len = read(content_handle, data_bufferA, BUFFER_SIZE);
            if (len < 0) {
                perror("VideoContent load");
                exit(1);
            }
            if (len > 0) {
                upload_data(data_bufferA, video_upload_position, len);
                video_upload_position += len;
                return RETURN_TRUE;
            } else {
                TRACE("Video content upload finished")
                video_uploaded = true;
                mode_switch_timeout = 0;
                return RETURN_TRUE;
            }
        }
         */

        // VIDEO CONTENT IS UPLOADED
        last_rendering = TIME_GET;

        if (mode_switch_timeout == 0) {
            set_mode(VIDEO);
            mode_switch_timeout = TIME_GET + MODE_SWITCH_TIMEOUT;
            return RETURN_TRUE;
        } else {
            if (mode_switch_timeout > TIME_GET)
                return RETURN_FALSE;
            set_mode(VIDEO);
            mode_switch_timeout = TIME_GET + MODE_SWITCH_TIMEOUT;
            return RETURN_TRUE;
        }
    }

    // handle video core mode
    if (requested_mode != current_mode) {
        // mode switch request not sent yet?
        if (mode_switch_timeout == 0) {
            // send request
            set_mode(requested_mode);
            mode_switch_timeout = TIME_GET + MODE_SWITCH_TIMEOUT;
            return RETURN_TRUE;
        } else {
            // check timeout
            if (mode_switch_timeout > TIME_GET)
                return RETURN_FALSE;
            set_mode(requested_mode);
            mode_switch_timeout = TIME_GET + MODE_SWITCH_TIMEOUT;
            return RETURN_TRUE;
        }
    }

    // new mode request?
    if (target_mode != requested_mode) {
        requested_mode = target_mode;
        mode_switch_timeout = 0;
        return RETURN_FALSE;
    }

    return PASS;
}

static eStatus handle_rendering(uint8_t status) {
    if (render_state == RENDER_STATE_START) {
        // no need to upload texture?
        if (current_rendering_context == target_rendering_context) {
            // no -> start rendering scene
            render_state = RENDER_STATE_RENDERING;
            return RETURN_TRUE;
        }
        // upload texture
        current_rendering_context = target_rendering_context;
        texture_request.uploadDataRoutine = upload_data;
        texture_request.updateFinishedRoutine = spi_vc_idle;
        texture_request.source_addr = current_rendering_context->base;
        texture_request.target_addr = 0;
        texture_request.length = current_rendering_context->length;
        render_state = RENDER_STATE_UPLOAD_TEXTURE;
        TRACE("Texture upload (%d bytes)", texture_request.length)
        upload_data_start(&texture_request);
        return RETURN_TRUE;
    }

    if(render_state==RENDER_STATE_CLEAR_SCREEN) {
        if(status & 0x02) {
            uint16_t size = 0;
            tRendererColor color;
            color.alpha=0xff;
            color.blue=0;
            color.green=0;
            color.red=0;
            vc_cmd_rect_color(0, 0, 1024, 600, color, command_queue, MAX_QUEUE_LENGTH, &size);
            uint8_t prefix[1] = {0x01};
            spi_vc_send(prefix, 1, command_queue, size);
            render_state=RENDER_STATE_CLEAR_SCREEN_WAIT;
            TRACE("Initial screen clearing")
            return RETURN_TRUE;
        }
        return RETURN_FALSE;
    }

    if(render_state==RENDER_STATE_CLEAR_SCREEN_WAIT) {
        // ready?
        if(status & 0x02) {
            render_state=RENDER_STATE_START;
            TRACE("Initial screen clearing done")
            return RETURN_TRUE;
        }
        return RETURN_FALSE;
    }

    if (render_state == RENDER_STATE_UPLOAD_TEXTURE) {
        if (!texture_request.finished)
            return RETURN_FALSE;
        TRACE("Rendering started")
        render_state = RENDER_STATE_RENDERING;
    }

    if (last_rendering + RENDERING_PERIOD > TIME_GET)
        return RETURN_FALSE;

    if (status & 0x02) {
        uint16_t size = 0;
        renderer_update_display(
                command_queue,
                MAX_QUEUE_LENGTH,
                &size);
        if (size) {
            uint8_t prefix[1] = {0x01};
            spi_vc_send(prefix, 1, command_queue, size);
            last_rendering = TIME_GET;
            return RETURN_TRUE;
        }

    }

    return RETURN_FALSE;
}

static eStatus handle_playback(uint8_t status) {
    // rendering active
    if (last_rendering + PLAYBACK_PERIOD > TIME_GET)
        return RETURN_FALSE;

    if (video_frame >= video_descriptor->frame_count) {
        TRACE("Video playback finished")

        // switch off
        vc_set_display_off();

        // notify script that video has ended
        if (video_callback)
            video_callback(video_callback_arg);

        return RETURN_FALSE;
    }

    // render
    static uint8_t frame[4];
    frame[0] = 0x03;
    frame[1] = (video_descriptor->frame_offsets[video_frame] >> 16) & 0xff;
    frame[2] = (video_descriptor->frame_offsets[video_frame] >> 8) & 0xff;
    frame[3] = (video_descriptor->frame_offsets[video_frame] >> 0) & 0xff;
    spi_vc_exchange(frame, NULL, 4);
    last_rendering = TIME_GET;
    video_frame++;

    return RETURN_TRUE;
}

bool vc_handle() {
    if (!spi_vc_idle())
        return false;
    upload_data_handle();
    // polling?
    if (next_poll_time > TIME_GET)
        return false;

    // poll status
    next_poll_time = TIME_GET + POLL_PERIOD_MS;
    uint8_t status = query_status();

    // TODO: check if status is valid
#ifndef PIC32
    if ((status & 0x80) == 0) {
        exit(1);
    }
#endif

    // handle video core mode
    eStatus ret = handle_mode(status);
    switch (ret) {
        case RETURN_FALSE:
            return false;
        case RETURN_TRUE:
            return true;
        default:
            break;
    }

    // mode is ok
    switch (current_mode) {
        case NORMAL:
            ret = handle_rendering(status);
            break;
        case VIDEO:
            ret = handle_playback(status);
            break;
        default:
            return false;
    }

    return ret == RETURN_TRUE;
}

