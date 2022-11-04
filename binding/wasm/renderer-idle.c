//
// Created by tumap on 11/2/22.
//
#include "profile.h"
#include "wa-types.h"
#include "renderer-idle.h"
#include "wa-system.h"
#include "wa-binding.h"

#ifdef WASM_TRACE_BINDING
#include <stdio.h>
#define TRACE_BINDING(ctx) printf("Function '%s' called\n", ctx->function.name);
#else
#define TRACE_BINDING(name)
#endif

// register context
typedef struct tagIdleRoutine {
    // routine binding
    uint32_t function_index;
    uint32_t function_data;

    // timing context
    tTime timeout;
    tTime period;
} tIdleRoutine;

#define MAX_IDLE_ROUTINES       32
static tIdleRoutine routines[MAX_IDLE_ROUTINES];
static unsigned routine_count;

// processing context
static int routine_position;
#define IDLE_MINIMUM_PERIOD     20
static tTime last_time;

// binding context
static uint32_t binding_idle_parameter1_value;
static uint32_t binding_idle_parameter2_value;
static tWasm_binding_value binding_idle_params[] = {
        {.type = WASM_BINDING_TYPE_U32, .u32 = {.value = &binding_idle_parameter1_value}},
        {.type = WASM_BINDING_TYPE_U32, .u32 = {.value = &binding_idle_parameter2_value}}
};
static tWasm_function_call idle_ctx = {
        .params=binding_idle_params,
        .param_count=2,
        .return_value = {.type=WASM_BINDING_TYPE_NONE}
};

// register_idle binding
static bool binding_register_routine(tWasm_function_call *call_ctx);

static uint32_t binding_register_parameter1_value;
static uint32_t binding_register_parameter2_value;
static uint32_t binding_register_parameter3_value;
static tWasm_binding_value binding_register_params[] = {
        {.type = WASM_BINDING_TYPE_U32, .u32 = {.value = &binding_register_parameter1_value}},
        {.type = WASM_BINDING_TYPE_U32, .u32 = {.value = &binding_register_parameter2_value}},
        {.type = WASM_BINDING_TYPE_U32, .u32 = {.value = &binding_register_parameter3_value}}
};
static tWasm_binding binding_register = {
        .call_ctx = {
                .function = {.name = "renderer_idle_register"},
                .return_value =  {.type = WASM_BINDING_TYPE_NONE},
                .params = binding_register_params,
                .param_count = 3
        },
        .routine=binding_register_routine
};

// deregister_idle binding
static bool binding_deregister_routine(tWasm_function_call *call_ctx);

static uint32_t binding_deregister_parameter1_value;
static uint32_t binding_deregister_parameter2_value;
static tWasm_binding_value binding_deregister_params[] = {
        {.type = WASM_BINDING_TYPE_U32, .u32 = {.value = &binding_deregister_parameter1_value}},
        {.type = WASM_BINDING_TYPE_U32, .u32 = {.value = &binding_deregister_parameter2_value}}
};
static tWasm_binding binding_deregister = {
        .call_ctx = {
                .function = {.name = "renderer_idle_deregister"},
                .return_value =  {.type = WASM_BINDING_TYPE_NONE},
                .params = binding_deregister_params,
                .param_count = 2
        },
        .routine=binding_deregister_routine
};


bool wasm_renderer_idle_init(tWasm_context *ctx) {

    // init context
    routine_count = 0;
    routine_position = -1;
    last_time = 0;

    // bind routines
    if (!wasm_binding_bind_function(ctx, &binding_register))
        return false;
    if (!wasm_binding_bind_function(ctx, &binding_deregister))
        return false;

    return true;
}

bool wasm_renderer_idle_register(uint16_t function_index, uint32_t data, tTime period) {

    if (routine_count >= MAX_IDLE_ROUTINES)
        return false;

    // create record
    tIdleRoutine *routine = routines + (routine_count++);
    routine->period = period;
    routine->function_index = function_index;
    routine->function_data = data;
    routine->timeout = TIME_GET + period;

    return true;
}

bool wasm_renderer_idle_deregister(uint16_t function_index, uint32_t data) {
    // find record
    int i;
    for (i = 0; i < routine_count; i++) {
        if (routines[i].function_index != function_index)
            continue;
        if (routines[i].function_data == data)
            break;
    }
    if (i >= routine_count)
        return true;

    // last record?
    if (i + 1 != routine_count) {
        uint8_t *d, *s;
        d = (uint8_t *) (routines + i);
        s = (uint8_t *) (routines + i + 1);
        i = ((int) sizeof(tIdleRoutine)) * ((int) routine_count - 2);
        while ((i--) >= 0)
            *(d++) = *(s++);
    }
    routine_count--;

    // reset processing
    routine_position = -1;

    return false;
}

bool wasm_renderer_idle_handle(tWasm_context *ctx) {
    // shortcut
    if (routine_count == 0)
        return false;

    // engine idle?
    if (wasm_execution_in_progress(ctx))
        return false;

    //  no scanning in progress?
    tTime now = TIME_GET;
    if (routine_position == -1) {
        // keep minimum period
        if (last_time + IDLE_MINIMUM_PERIOD > now)
            return false;

        // start scanning
        routine_position = 0;
        last_time = now;
    }

    // find next suitable routine
    for (; routine_position < routine_count; routine_position++) {
        if (routines[routine_position].timeout <= last_time)
            break;
    }

    // found anything?
    if (routine_position >= routine_count) {
        // restart scanning
        routine_position = -1;
        return false;
    }

    // update context
    tIdleRoutine *routine = routines + routine_position++;
    if (routine_position >= routine_count) {
        // restart scanning
        routine_position = -1;
    }
    routine->timeout += routine->period;
    if (routine->timeout <= now) {
        routine->timeout = now + routine->period;
    }

    // call idle routine
    idle_ctx.function.index = routine->function_index;
    binding_idle_parameter1_value = last_time;
    binding_idle_parameter2_value = routine->function_data;
    wasm_binding_call_function(ctx, &idle_ctx);

    return true;
}

static bool binding_register_routine(tWasm_function_call *call_ctx) {
    TRACE_BINDING(call_ctx)
    return wasm_renderer_idle_register(
            *call_ctx->params[0].u32.value,
            *call_ctx->params[1].u32.value,
            *call_ctx->params[2].u32.value);
}

static bool binding_deregister_routine(tWasm_function_call *call_ctx) {
    TRACE_BINDING(call_ctx)
    return wasm_renderer_idle_deregister(
            *call_ctx->params[0].u32.value,
            *call_ctx->params[1].u32.value);
}
