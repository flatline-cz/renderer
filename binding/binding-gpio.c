//
// Created by tumap on 8/8/23.
//
#include "binding-gpio.h"
#include <trace.h>
#include <profile.h>
#include "platform-gpio.h"

#define STACK_DEPTH         8

typedef struct tagKeyBinding {
    rRendererGpioRoutine routine;
    void *arg;
} tKeyBinding;

static tKeyBinding bindings[PLATFORM_GPIO_BUTTONS][STACK_DEPTH];

void binding_gpio_init() {
    // initialize platform HW
    platform_gpio_init();

    // initialize context
    for (int i = 0; i < PLATFORM_GPIO_BUTTONS; i++) {
        for (int j = 0; j < STACK_DEPTH; j++)
            bindings[i][j].routine = 0;
    }
}

bool binding_gpio_handle() {
    bool state=false;
    uint32_t keys = platform_gpio_get_state();
    int key;
    for (key = 0; key < PLATFORM_GPIO_BUTTONS && keys != 0; key++) {
        if (keys & (1 << key)) {
            keys &= ~(1 << key);
            int level;
            for (level = 0; level < STACK_DEPTH; level++) {
                if (!bindings[key][level].routine)
                    break;
                if (bindings[key][level].routine(
                        key,
                        GPIO_BINDING_SHORT_PRESS,
                        bindings[key][level].arg)) {
                    state=true;
                    break;
                }
            }
        }
    }
    return state;
}

void binding_gpio_register(unsigned key, rRendererGpioRoutine routine, void *arg) {
    TRACE("GPIO-BINDING: Binding routine for key #%d", key)

    if (bindings[key][STACK_DEPTH - 1].routine) {
        TRACE("GPIO-BINDING: Too many bindings")
#ifdef PIC32
        return;
#else
        abort();
#endif
    }

    // make space
    int level;
    for (level = STACK_DEPTH - 1; level > 0; level--) {
        bindings[key][level].routine = bindings[key][level - 1].routine;
        bindings[key][level].arg = bindings[key][level - 1].arg;
    }
    bindings[key][0].routine = routine;
    bindings[key][0].arg = arg;

}

void binding_gpio_deregister(unsigned key, rRendererGpioRoutine routine, void *arg) {
    TRACE("GPIO-BINDING: Un-binding routine for key #%d", key)

    // find routine
    int level;
    for (level = 0; level < STACK_DEPTH; level++) {
        if (!bindings[key][level].routine) {
            TRACE("GPIO_BINDING: Un-binding failed (routine not found)")
#ifdef PIC32
            return;
#else
            abort();
#endif
        }
        if (bindings[key][level].routine == routine && bindings[key][level].arg == arg)
            break;
    }
    if (level == STACK_DEPTH) {
        TRACE("GPIO_BINDING: Un-binding failed (routine not found)")
#ifdef PIC32
        return;
#else
        abort();
#endif
    }

    // move the rest
    while ((level + 1) < STACK_DEPTH) {
        bindings[key][level].routine = bindings[key][level + 1].routine;
        bindings[key][level].arg = bindings[key][level + 1].arg;
        level++;
    }
    if (level < STACK_DEPTH)
        bindings[key][level].routine = 0;
}
