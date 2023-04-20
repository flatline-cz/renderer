//
// Created by tumap on 12/5/22.
//
#include <spi.h>
#include <profile.h>
#include <stdlib.h>
#include <stdio.h>
#include <renderer.h>
#include <video-core.h>
#include <fcntl.h>
#include <unistd.h>

#define TRACE(msg) fprintf(stderr, "%d.%03ds : %s\n", TIME_GET/1000, TIME_GET%1000, msg);

// *******************************************
// **  VIDEO CORE POLL CONTEXT              **
// *******************************************

static tTime next_poll_time;

#define POLL_PERIOD_MS          10

// *******************************************
// **  MODE SELECTION CONTEXT               **
// *******************************************

typedef enum taVCMode {
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
#define BUFFER_SIZE     (16*1024)
static uint8_t data_buffer[BUFFER_SIZE];

// rendering textures
static tRendererScreenGraphics *current_rendering_context;
static tRendererScreenGraphics *target_rendering_context;

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
    // initialize SPI interface
    spi_init();

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

}

void vc_set_render_mode(tRendererScreenGraphics *graphics) {
    target_rendering_context = graphics;
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

static uint8_t query_status() {
    static uint8_t data[3];
    data[0] = 0;
    spi_send_receive(data, data, 3);
    return data[2];
}

static void set_mode(uint8_t mode) {
    static uint8_t data[2];
    data[0] = 4;
    data[1] = mode;
    spi_send(NULL, 0, data, 2);
//    fprintf(stderr, "VC: Changing mode to %d\n", mode);
}

static void upload_data(const uint8_t *data, uint32_t offset, uint32_t length) {
    static uint8_t prefix[4];
    prefix[0] = 0x02;
    prefix[1] = (offset >> 16) & 0xff;
    prefix[2] = (offset >> 8) & 0xff;
    prefix[3] = (offset >> 0) & 0xff;
    spi_send(prefix, 4, data, length);
}

static void set_video_frame() {
    static uint8_t frame[4];
    frame[0] = 0x03;
    frame[1] = (video_descriptor->frame_offsets[video_frame] >> 16) & 0xff;
    frame[2] = (video_descriptor->frame_offsets[video_frame] >> 8) & 0xff;
    frame[3] = (video_descriptor->frame_offsets[video_frame] >> 0) & 0xff;
    spi_send(NULL, 0, frame, 4);
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
        if (!video_uploaded) {
            static int content_handle = -1;
            if (content_handle == -1) {
                content_handle = open("impl/output/texture-intro.bin", O_RDONLY);
                if (content_handle < 0) {
                    perror("VideoContent load");
                    exit(1);
                }
                video_upload_position = 0;
                TRACE("Video content upload started")
            }
            int len = read(content_handle, data_buffer, BUFFER_SIZE);
            if (len < 0) {
                perror("VideoContent load");
                exit(1);
            }
            if (len > 0) {
                upload_data(data_buffer, video_upload_position, len);
                video_upload_position += len;
                return RETURN_TRUE;
            } else {
                TRACE("Video content upload finished")
                video_uploaded = true;
                mode_switch_timeout = 0;
                return RETURN_TRUE;
            }
        }

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
    // upload graphics?
    if (current_rendering_context != target_rendering_context) {
        current_rendering_context = target_rendering_context;

        upload_data(current_rendering_context->data,
                    current_rendering_context->base,
                    current_rendering_context->length);

        TRACE("Textures uploaded")

        return RETURN_TRUE;
    }

    if (last_rendering + RENDERING_PERIOD > TIME_GET)
        return RETURN_FALSE;

    if (status & 0x02) {
        uint16_t size;
        renderer_update_display(
                command_queue,
                MAX_QUEUE_LENGTH,
                &size);
        if (size) {
            static uint8_t prefix[1] = {0x01};
            spi_send(prefix, 1, command_queue, size);
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
    spi_send(NULL, 0, frame, 4);
    last_rendering = TIME_GET;
    video_frame++;

    return RETURN_TRUE;
}

bool vc_handle() {
    // polling?
    if (next_poll_time > TIME_GET)
        return false;

    // poll status
    next_poll_time = TIME_GET + POLL_PERIOD_MS;
    uint8_t status = query_status();

    // TODO: check if status is valid
    if ((status & 0x80) == 0) {
        exit(1);
    }

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

