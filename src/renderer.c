//
// Created by tumap on 11/17/22.
//
#include "renderer.h"
#include "renderer-definition.h"
#include "video-core-hw.h"
#include "profile.h"


// renderer mode context
static eVCRenderingMode current_mode;
static eVCRenderingMode target_mode;
static eVCRenderingMode requested_mode;
#define STATE_MODE_IDLE             0
#define STATE_MODE_REQUEST          1
#define STATE_MODE_VERIFY           2
static unsigned state_mode;
static tTime mode_switch_timeout;

// normal rendering context
static bool vsync_passed = false;
static bool render_ready =  false;
static uint8_t render_queue_data[8*1024];
static uint16_t render_queue_length=0;
tRendererTileHandle root_tile = RENDERER_NULL_HANDLE;


void renderer_init() {
    // mode initialization
    state_mode = STATE_MODE_REQUEST;
    target_mode = DISPLAY_OFF;
    mode_switch_timeout = time_get() + 10;
}

bool renderer_handle() {

    // Mode switch
    switch (state_mode) {
        case STATE_MODE_REQUEST: {
            tVCRequest request;
            request.type = VC_SET_MODE;
            request.rendering_mode.mode = target_mode;
            if (vc_send_request(&request)) {
                state_mode = STATE_MODE_VERIFY;
                return true;
            }
            return false;
        }
        case STATE_MODE_VERIFY: {
            uint8_t status;
            if (vc_get_status(&status)) {
                if (((status >> 4) & 3) == target_mode) {
                    state_mode = STATE_MODE_IDLE;
                    current_mode = target_mode;
                    break;
                }
            }
            return false;
        }
        case STATE_MODE_IDLE:
        default:
            if (requested_mode != current_mode) {
                state_mode = STATE_MODE_REQUEST;
                target_mode = requested_mode;
                mode_switch_timeout = time_get() + 10;
                return true;
            }
            break;
    }

    // Mode is valid

    if(current_mode==NORMAL) {
        if(!vsync_passed) {
            if(vc_check_vsync())
                vsync_passed=true;
            else
                return false;
        }
        if(!render_ready) {
            uint8_t status;
            if(!vc_get_status(&status))
                return false;
            if((status&1)==0)
                render_ready=true;
        }

        if(render_queue_length==0) {
            // try to render
            renderer_update_display(
                    render_queue_data,
                    8 * 1024,
                    &render_queue_length);
        }

        tVCRequest request;
        request.type=VC_FILL_QUEUE;
        request.fill_queue.buffer=render_queue_data;
        request.fill_queue.length=render_queue_length;

        if(render_queue_length==0 || vc_send_request(&request)) {
            // reset synchronization
            vsync_passed = false;
            render_ready = false;
            render_queue_length = 0;
            return true;
        }
        return false;
    }

    return false;
}

void renderer_show_screen(tRendererScreenHandle screen_handle) {
    requested_mode = NORMAL;
    root_tile=screen_handle;
}

void renderer_turn_off() {
    requested_mode = DISPLAY_OFF;
}