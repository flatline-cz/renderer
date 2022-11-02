//
// Created by tumap on 11/2/22.
//

#ifndef DASHBOARD_RENDERER_IDLE_H
#define DASHBOARD_RENDERER_IDLE_H

#include <stdbool.h>
#include <stdint.h>
#include "profile.h"

bool wasm_renderer_idle_handle();

bool wasm_renderer_idle_register(const uint8_t* name, uint16_t name_len, tTime period);
bool wasm_renderer_idle_deregister(const uint8_t* name, uint16_t name_len);

#endif //DASHBOARD_RENDERER_IDLE_H
