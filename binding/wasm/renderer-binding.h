//
// Created by tumap on 10/27/22.
//

#ifndef WASM_TEST_RENDERER_BINDING_H
#define WASM_TEST_RENDERER_BINDING_H

#include "wa-types.h"

typedef uint32_t tTime;

bool renderer_binding_initialize(tWasm_context* ctx);

typedef void (*rIdleRoutine)(tTime time, uint32_t data);

void renderer_idle_register(rIdleRoutine routine, uint32_t data, tTime period);
void renderer_idle_deregister(rIdleRoutine routine, uint32_t data);

#define SCRIPT_ROUTINE(name, ...) void __attribute__((export_name(#name))) name(__VA_ARGS__)

#endif //WASM_TEST_RENDERER_BINDING_H
