//
// Created by tumap on 10/27/22.
//

#include <stdio.h>
#include "renderer-binding.h"
#include "wa-binding.h"
#include "renderer.h"

// ***********************************
// **                               **
// **  RENDERER_SHOW_SCREEN         **
// **                               **
// ***********************************

// parameters
static uint32_t binding_show_screen_parameter1_value;

static tWasm_binding_value binding_show_screen_params[] = {
        {.type = WASM_BINDING_TYPE_U32, .u32 = {.value = &binding_show_screen_parameter1_value}}
};

// binding
static bool binding_show_screen_routine(tWasm_function_call *call_ctx);

static tWasm_binding binding_show_screen = {
        .call_ctx = {
                .name = "renderer_show_screen",
                .return_value =  {.type = WASM_BINDING_TYPE_NONE},
                .params = binding_show_screen_params,
                .param_count = 1
        },
        .routine=binding_show_screen_routine
};

// binding interface routine
static bool binding_show_screen_routine(tWasm_function_call *call_ctx) {
    renderer_show_screen(*call_ctx->params[0].u32.value);
    return true;
}

// ***********************************
// **                               **
// **  RENDERER_SET_VISIBILITY      **
// **                               **
// ***********************************

// parameters
static uint32_t binding_set_visibility_parameter1_value;
static uint32_t binding_set_visibility_parameter2_value;

static tWasm_binding_value binding_set_visibility_params[] = {
        {.type = WASM_BINDING_TYPE_U32, .u32 = {.value = &binding_set_visibility_parameter1_value}},
        {.type = WASM_BINDING_TYPE_U32, .u32 = {.value = &binding_set_visibility_parameter2_value}}
};

// binding
static bool binding_set_visibility_routine(tWasm_function_call *call_ctx);

static tWasm_binding binding_set_visibility = {
        .call_ctx = {
                .name = "renderer_set_visibility",
                .return_value =  {.type = WASM_BINDING_TYPE_NONE},
                .params = binding_set_visibility_params,
                .param_count = 2
        },
        .routine=binding_set_visibility_routine
};


// binding interface routine
static bool binding_set_visibility_routine(tWasm_function_call *call_ctx) {
    renderer_set_visibility(
            *call_ctx->params[0].u32.value,
            *call_ctx->params[1].u32.value ? true : false);
    return true;
}


// ***********************************
// **                               **
// **  BIND ALL ROUTINES            **
// **                               **
// ***********************************

bool renderer_binding_initialize(tWasm_context *ctx) {
    if (!wasm_binding_bind_function(ctx, &binding_show_screen))
        return false;
    if (!wasm_binding_bind_function(ctx, &binding_set_visibility))
        return false;
    return true;
}
