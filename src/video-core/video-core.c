//
// Created by tumap on 12/5/22.
//
#include <xc.h>
#include <profile.h>
#include <renderer.h>
#include <video-core.h>
#include <video-core-hw.h>
#include <spi-flash.h>
#include "system-config.h"
#include "trace.h"


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
static tTime last_rendering = 0;
#define RENDERING_PERIOD        50
#define PLAYBACK_PERIOD         50

// data exchange buffer
#define BUFFER_SIZE     (4*1024)
static uint8_t data_bufferA[BUFFER_SIZE];
static uint8_t data_bufferB[BUFFER_SIZE];

// rendering textures
static tRendererScreenGraphics *current_rendering_context;
static tRendererScreenGraphics *target_rendering_context;
#define RENDER_STATE_START              0
#define RENDER_STATE_READ_TEXTURE_A     1
#define RENDER_STATE_UPLOAD_TEXTURE_A   2
#define RENDER_STATE_UPLOAD_TEXTURE_B   3
#define RENDER_STATE_RENDERING          4
static int render_state;
static uint32_t texture_length;
// -- texture buffer A
static tSPIFlashRequest texture_requestA;
// -- texture buffer B
static tSPIFlashRequest texture_requestB;

// video playback context
static bool video_uploaded;
static uint32_t video_upload_position;
static uint16_t video_frame;
static tRendererVideoDescriptor *video_descriptor;
static rRendererVideoCallback video_callback;
static const void *video_callback_arg;

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
    current_rendering_context = NULL;
    target_rendering_context = NULL;

    // reset playback context
    video_uploaded = false;
    video_descriptor = NULL;

    // reset
    renderer_init();

}

void vc_set_render_mode(tRendererScreenGraphics *graphics) {
    target_rendering_context = graphics;
    render_state = RENDER_STATE_START;
    last_rendering=0;
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
    if (!video_core_hw_idle())
        return 0;
    query_status_buffer[0] = 0;
    query_status_buffer[1] = 0xff;
    query_status_buffer[2] = 0xff;
    video_core_hw_exchange(query_status_buffer, query_status_buffer, 3);
    return query_status_buffer[2];
}

static void set_mode(uint8_t mode) {
    int i;
    for(i=0;i<10000;i++);
    query_status_buffer[0] = 4;
    query_status_buffer[1] = mode;
    query_status_buffer[2] = 0xff;
    video_core_hw_exchange(query_status_buffer, query_status_buffer, 3);
    Nop();
//    set_mode_buffer[0] = 4;
//    set_mode_buffer[1] = mode;
//    video_core_hw_exchange(set_mode_buffer, set_mode_buffer, 2);
//    video_core_hw_send(set_mode_buffer, 2, NULL, 0);
}


static void upload_data(uint8_t *data, uint32_t offset, uint32_t length) {
    static uint8_t prefix[4];
    prefix[0] = 0x02;
    prefix[1] = (offset >> 16) & 0xff;
    prefix[2] = (offset >> 8) & 0xff;
    prefix[3] = (offset >> 0) & 0xff;
    video_core_hw_send(prefix, 4, data, length);
}

static void set_video_frame() {
    static uint8_t frame[4];
    frame[0] = 0x03;
    frame[1] = (video_descriptor->frame_offsets[video_frame] >> 16) & 0xff;
    frame[2] = (video_descriptor->frame_offsets[video_frame] >> 8) & 0xff;
    frame[3] = (video_descriptor->frame_offsets[video_frame] >> 0) & 0xff;
    video_core_hw_send(NULL, 0, frame, 4);
}

typedef enum tagStatus {
    PASS, RETURN_TRUE, RETURN_FALSE
} eStatus;

// FIXME:
void renderer_show_screen(tRendererScreenHandle screen_handle);

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
//    bool show_screen=false;
//    if(target_mode!=NORMAL) {
//        renderer_show_screen(0);
//    }
    
    if (target_mode != requested_mode) {
        requested_mode = target_mode;
        mode_switch_timeout = 0;
        return RETURN_FALSE;
    }

    return PASS;
}

static void render_texture_upload() {
    // initialization?
    if (render_state == RENDER_STATE_START) {
        // new texture needed?
        if (current_rendering_context == target_rendering_context) {
            // no -> start rendering scene
            render_state = RENDER_STATE_RENDERING;
            return;
        }
        // new texture needed -> read first buffer
        TRACE("Start uploading texture (%d bytes)", target_rendering_context->length);
        texture_length = target_rendering_context->length;
        texture_requestB.status = SPI_FLASH_IDLE;
        texture_requestA.status = SPI_FLASH_IDLE;
        texture_requestA.buffer = data_bufferA;
        texture_requestA.bank = FLASH_BANK_SCENE;
        texture_requestA.address = target_rendering_context->base;
        texture_requestA.length = (texture_length <= BUFFER_SIZE) ? texture_length : BUFFER_SIZE;
        // initialize texture read
        if (spi_flash_read(&texture_requestA)) {
            render_state = RENDER_STATE_READ_TEXTURE_A;
        }
        return;
    }

    // waiting for 1st block of texture is read
    if (render_state == RENDER_STATE_READ_TEXTURE_A) {
        if (texture_requestA.status == SPI_FLASH_IN_PROGRESS)
            return;
        texture_length -= texture_requestA.length;
        texture_requestA.status = SPI_FLASH_IDLE;

        // start uploading buffer A
        upload_data(texture_requestA.buffer,
                    texture_requestA.address - target_rendering_context->base,
                    texture_requestA.length);

        // update context
        texture_requestB.status = SPI_FLASH_IDLE;
        render_state = RENDER_STATE_UPLOAD_TEXTURE_A;
        return;
    }

    // uploading buffer A?
    if (render_state == RENDER_STATE_UPLOAD_TEXTURE_A) {
        // have something more to read (to buffer B)?
        if (texture_length != 0) {
            // transfer not initialized yet?
            if (texture_requestB.status == SPI_FLASH_IDLE) {
                // initialize
                texture_requestB.buffer = data_bufferB;
                texture_requestB.bank = FLASH_BANK_SCENE;
                texture_requestB.address = texture_requestA.address + texture_requestA.length;
                texture_requestB.length = (texture_length <= BUFFER_SIZE) ? texture_length : BUFFER_SIZE;
                spi_flash_read(&texture_requestB);
                return;
            }
            // wait for transfer to be finished
            if (texture_requestB.status == SPI_FLASH_IN_PROGRESS)
                return;
        }

        // TODO: check the uploading is done

        // Buffer A is processed, end of texture?
        if (texture_length == 0) {
            // end of texture uploading
            TRACE("Texture uploading finished");
            render_state = RENDER_STATE_RENDERING;
            current_rendering_context = target_rendering_context;
            return;
        }
        texture_length -= texture_requestB.length;

        // no, start uploading buffer B
        upload_data(texture_requestB.buffer,
                    texture_requestB.address - target_rendering_context->base,
                    texture_requestB.length);

        // update context
        texture_requestA.status = SPI_FLASH_IDLE;
        render_state = RENDER_STATE_UPLOAD_TEXTURE_B;
        return;
    }

    // uploading buffer B?
    if (render_state == RENDER_STATE_UPLOAD_TEXTURE_B) {
        // have something more to read (to buffer A)?
        if (texture_length != 0) {
            // transfer not initialized yet?
            if (texture_requestA.status == SPI_FLASH_IDLE) {
                // initialize
                texture_requestA.buffer = data_bufferB;
                texture_requestA.bank = FLASH_BANK_SCENE;
                texture_requestA.address = texture_requestB.address + texture_requestA.length;
                texture_requestA.length = (texture_length <= BUFFER_SIZE) ? texture_length : BUFFER_SIZE;
                spi_flash_read(&texture_requestA);
                return;
            }
            // wait for transfer to be finished
            if (texture_requestA.status == SPI_FLASH_IN_PROGRESS)
                return;
        }

        // TODO: check the uploading is done

        // Buffer A is processed, end of texture?
        if (texture_length == 0) {
            // end of texture uploading
            TRACE("Texture uploading finished")
            render_state = RENDER_STATE_RENDERING;
            current_rendering_context = target_rendering_context;
            return;
        }
        texture_length -= texture_requestA.length;

        // no, start uploading buffer A
        upload_data(texture_requestA.buffer,
                    texture_requestA.address - target_rendering_context->base,
                    texture_requestA.length);

        // update context
        texture_requestB.status = SPI_FLASH_IDLE;
        render_state = RENDER_STATE_UPLOAD_TEXTURE_A;
        return;
    }

#ifndef PIC32
    // should not get here
    TRACE("Unknown rendering state");
    abort();
#endif
}

static eStatus handle_rendering(uint8_t status) {
//    if (render_state != RENDER_STATE_RENDERING) {
//        render_texture_upload();
//        return RETURN_TRUE;
//    }

    if (last_rendering + RENDERING_PERIOD > TIME_GET)
        return RETURN_FALSE;

    if (status & 0x02) {
        uint16_t size;
        renderer_update_display(
                command_queue,
                MAX_QUEUE_LENGTH,
                &size);
        if (size) {
            uint8_t prefix[1] = {0x01};
            video_core_hw_send(prefix, 1, command_queue, size);
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
    video_core_hw_send(NULL, 0, frame, 4);
    last_rendering = TIME_GET;
    video_frame++;

    return RETURN_TRUE;
}

bool vc_handle() {
    if (!video_core_hw_idle())
        return false;
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

