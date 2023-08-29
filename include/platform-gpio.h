//
// Created by tumap on 8/8/23.
//

#ifndef HEAD_UNIT_PLATFORM_GPIO_H
#define HEAD_UNIT_PLATFORM_GPIO_H

#include <stdbool.h>
#include <stdint.h>

#define PLATFORM_GPIO_BUTTONS       5

void platform_gpio_init();

bool platform_gpio_handle();

uint32_t platform_gpio_get_state();


#endif //HEAD_UNIT_PLATFORM_GPIO_H
