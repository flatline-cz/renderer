//
// Created by tumap on 11/2/22.
//
#include "profile.h"
#include "wa-types.h"
#include "renderer-idle.h"

// register context
typedef struct tagIdleRoutine {
    // routine binding
    uint32_t function_index;

    // timing context
    tTime timeout;
    tTime period;
} tIdleRoutine;

#define MAX_IDLE_ROUTINES       32
static tIdleRoutine routines[MAX_IDLE_ROUTINES];
static unsigned routine_position=0;
static unsigned routine_count = 0;

// binding context
static tWasm_function_call idle_ctx;

bool wasm_renderer_idle_register(const uint8_t *name, uint16_t name_len, tTime period) {
    return false;
}

bool wasm_renderer_idle_deregister(const uint8_t *name, uint16_t name_len) {
    return false;
}

bool wasm_renderer_idle_handle() {
    return false;
}
