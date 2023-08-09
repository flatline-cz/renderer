//
// Created by tumap on 12/6/22.
//

#ifndef DASHBOARD_RENDERER_GPIO_H
#define DASHBOARD_RENDERER_GPIO_H

#include <stdbool.h>
#include <stdint.h>

typedef enum tagRendererGpioBindingEvent {
    GPIO_BINDING_SHORT_PRESS,
    GPIO_BINDING_LONG_PRESS
} eRendererGpioBindingEvent;

typedef bool (*rRendererGpioRoutine)(unsigned key, eRendererGpioBindingEvent event, void* arg);

void binding_gpio_init();

bool binding_gpio_handle();

void binding_gpio_register(unsigned key, rRendererGpioRoutine routine, void* arg);

void binding_gpio_deregister(unsigned key, rRendererGpioRoutine  routine, void* arg);

#endif //DASHBOARD_RENDERER_GPIO_H
