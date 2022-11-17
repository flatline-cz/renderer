//
// Created by tumap on 11/17/22.
//
#include "renderer.h"
#include "renderer-definition.h"
#include "video-core-hw.h"

// state machine
typedef enum eState_ {
    STATE_SWITCH_OFF,
    STATE_SWITCH_OFF_WAIT,
    STATE_DISPLAY_OFF,
    STATE_SWITCH_RENDER,
    STATE_SWITCH_RENDER_WAIT,
    STATE_RENDERING,
} eState;
static eState state;

// current renderer mode
static eVCRenderingMode target_mode;

// video core data exchange
static tVCRequest request;


void renderer_init() {
    target_mode=DISPLAY_OFF;
    state=STATE_SWITCH_OFF;
}

bool renderer_handle() {
    switch(state) {
        case STATE_SWITCH_OFF:
            // try to send command
            request.type=VC_SET_MODE;
            request.rendering_mode.mode=DISPLAY_OFF;
            if(vc_send_request(&request)) {
                state = STATE_SWITCH_OFF_WAIT;
                return true;
            }
            break;
        case STATE_SWITCH_OFF_WAIT:
            // command sent?
            if(vc_response_ready()) {
                state=STATE_DISPLAY_OFF;
                return true;
            }
            break;
        case STATE_DISPLAY_OFF:
            // target changed?
            if(target_mode==NORMAL) {
                state=STATE_SWITCH_RENDER;
                return true;
            }
            break;
        case STATE_SWITCH_RENDER:
            request.type=VC_SET_MODE;
            request.rendering_mode.mode=NORMAL;
            if(vc_send_request(&request)) {
                state=STATE_SWITCH_RENDER_WAIT;
                return true;
            }
            break;
        case STATE_SWITCH_RENDER_WAIT:
            if(vc_response_ready()) {
                state=STATE_RENDERING;
                return true;
            }
            break;
        case STATE_RENDERING:
            // handle mode change
            if(target_mode==DISPLAY_OFF) {
                state=STATE_SWITCH_OFF;
                return true;
            }
            // handle rendering itself
            break;
        default:
            break;
    }

    return false;
}

void renderer_show_screen(tRendererScreenHandle screen_handle) {
    target_mode=NORMAL;
}

void renderer_turn_off() {
    target_mode=DISPLAY_OFF;
}