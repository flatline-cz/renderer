//
// Created by tumap on 12/6/22.
//

#ifndef DASHBOARD_RENDERER_IDLE_H
#define DASHBOARD_RENDERER_IDLE_H

#include <stdbool.h>
#include <stdint.h>
#include <profile.h>

void binding_idle_init();

bool binding_idle_handle();

typedef void (*rRendererIdleRoutine)(tTime time, void* arg);

void binding_idle_register(tTime period, rRendererIdleRoutine routine, void* routine_arg);

void binding_idle_deregister(rRendererIdleRoutine routine, void* routine_arg);

#endif //DASHBOARD_RENDERER_IDLE_H
