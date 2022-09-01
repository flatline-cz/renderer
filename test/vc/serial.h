//
// Created by tumap on 9/1/22.
//

#ifndef RENDERER_SERIAL_H
#define RENDERER_SERIAL_H

#include <stdint.h>
#include <stdbool.h>

void serial_init();

bool serial_handle();

void serial_send(const char* data, unsigned length);

#endif //RENDERER_SERIAL_H
