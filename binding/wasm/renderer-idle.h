//
// Created by tumap on 11/2/22.
//

#ifndef DASHBOARD_RENDERER_IDLE_H
#define DASHBOARD_RENDERER_IDLE_H

#include <stdbool.h>
#include <stdint.h>
#include "profile.h"

bool wasm_renderer_idle_init(tWasm_context* ctx);

bool wasm_renderer_idle_handle(tWasm_context* ctx);

bool wasm_renderer_idle_register(uint16_t function_index, uint32_t data, tTime period);
bool wasm_renderer_idle_deregister(uint16_t function_index, uint32_t data);

#endif //DASHBOARD_RENDERER_IDLE_H
