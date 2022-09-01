//
// Created by tumap on 9/1/22.
//
#include "renderer.h"
#include "profile.h"
#include "serial.h"
#include "hex.h"
#include "scripting.h"


static char serial_buffer[4096];

bool vc_cmd_execute(const uint8_t *data, unsigned length) {
    if(length==1 && data[0]==0x80)
        return false;

    unsigned position=0;
    serial_buffer[position++]=':';
    serial_buffer[position++]='0';
    serial_buffer[position++]='0';
    for(;length ; length--) {
        serial_buffer[position++]=NIBBLE_TO_HEX(*data>>4);
        serial_buffer[position++]=NIBBLE_TO_HEX(*data);
        data++;
    }
    serial_buffer[position++]=';';

    serial_send(serial_buffer, position);

    return true;
}

static bool active_buffer=true;
static tTime swap_buffers=0;
int renderer_display_ready() {
    tTime now=time_get();
    if(now<swap_buffers)
        return -1;
    swap_buffers=now+100;

    active_buffer=!active_buffer;
    return active_buffer?1:0;
}

int main() {
    serial_init();
    renderer_init();
    scripting_init();

#pragma clang diagnostic push
#pragma ide diagnostic ignored "EndlessLoop"
    while(true) {
        bool didSomething;
        didSomething=serial_handle();
        didSomething|=renderer_handle();
        didSomething|=scripting_handle();
        if(didSomething)
            continue;
        sleep_a_bit();
    }
#pragma clang diagnostic pop

    return 0;
}
