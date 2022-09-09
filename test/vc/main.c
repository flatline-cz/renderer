//
// Created by tumap on 9/1/22.
//
#include <stdio.h>
#include "renderer.h"
#include "profile.h"
#include "serial.h"
#include "hex.h"
#include "scripting.h"


static char serial_buffer[4096];

void stream_dump_bytes(const uint8_t *data, unsigned length) {
    unsigned pos;
    fprintf(stderr, "\n:00");
    for (pos = 0; pos < length;) {
        if (data[pos] & 0x80) {
            fprintf(stderr, ";\n");
            break;
        }
        int i;
        for (i = 0; i < 12; i++, pos++)
            fprintf(stderr, "%02X", data[pos]);
    }
}

void stream_dump(const uint8_t *data, unsigned length) {
    unsigned pos;
    fprintf(stderr, "=== Start of list ===\n");
    for (pos = 0; pos < length;) {
        if (data[pos] & 0x80) {
            fprintf(stderr, "=== End of list ===\n\n");
            break;
        }
        fprintf(stderr, "Rectangle: x=%d, y=%d, w=%d, h=%d\n",
                ((unsigned) data[pos + 1]) | (((unsigned) data[pos + 2]) << 8),
                ((unsigned) data[pos + 3]) | (((unsigned) data[pos + 4]) << 8),
                ((unsigned) data[pos + 5]) | (((unsigned) data[pos + 6]) << 8),
                ((unsigned) data[pos + 7]) | (((unsigned) data[pos + 8]) << 8));
        uint16_t color = ((uint16_t) data[pos + 9]) | (((uint16_t) data[pos + 10]) << 8);
        fprintf(stderr, "  r=%0.3f, g=%0.3f, b=%0.3f, a=%0.3f\n",
                ((float) (color & 0x1f)) / 31.f,
                ((float) ((color >> 5) & 0x1f)) / 31.f,
                ((float) ((color >> 10) & 0x1f)) / 31.f,
                ((float) data[pos + 11]) / 15.f);

        pos += 12;
    }
}

bool vc_cmd_execute(const uint8_t *data, unsigned length) {
    if (length == 1 && data[0] == 0x80)
        return false;

    stream_dump_bytes(data, length);
    stream_dump(data, length);

    unsigned position = 0;
    unsigned original_length = length;
    serial_buffer[position++] = ':';
    serial_buffer[position++] = '0';
    serial_buffer[position++] = '0';
    for (; length; length--) {
        serial_buffer[position++] = NIBBLE_TO_HEX(*data >> 4);
        serial_buffer[position++] = NIBBLE_TO_HEX(*data);
        data++;
    }
    if (original_length & 1) {
        serial_buffer[position++] = '8';
        serial_buffer[position++] = '0';
    }
    serial_buffer[position++] = '8';
    serial_buffer[position++] = '0';
    serial_buffer[position++] = '8';
    serial_buffer[position++] = '0';
    serial_buffer[position++] = ';';
    serial_buffer[position++] = '\n';

    fwrite(serial_buffer, 1, position, stderr);

    serial_send(serial_buffer, position);

    return true;
}


static int counter = 0;
static bool active_buffer = true;
static tTime swap_buffers = 0;

int renderer_display_ready() {
    tTime now = time_get();
    if (now < swap_buffers)
        return -1;
    counter++;
    swap_buffers = now + (counter>10 ? 100:500);

    active_buffer = !active_buffer;
    return active_buffer ? 1 : 0;
}

int main() {
    serial_init();
    renderer_init();
    scripting_init();

#pragma clang diagnostic push
#pragma ide diagnostic ignored "EndlessLoop"
    while (true) {
        bool didSomething;
        didSomething = serial_handle();
        didSomething |= renderer_handle();
        didSomething |= scripting_handle();
        if (didSomething)
            continue;
        sleep_a_bit();
    }
#pragma clang diagnostic pop

    return 0;
}
