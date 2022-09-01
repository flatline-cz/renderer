//
// Created by tumap on 9/1/22.
//
//#include "renderer.h"
//#include "ri-constants.h"
#include <unistd.h>
#include "profile.h"
#include "serial.h"

static bool stop=false;
static unsigned state=0;
static tTime next_state=0;


//static void event_loop() {
//    tTime now=time_get();
//    if(now<next_state)
//        return;
//
//    next_state=now+5000;
//
//    switch(state) {
//        case 0:
//            renderer_show_screen(RENDER_TILE_main);
////            renderer_handle();
//            break;
//        case 1:
//            renderer_set_visibility(RENDER_TILE_main_sign2, true);
////            renderer_handle();
//            break;
//        case 2:
//            renderer_set_position(RENDER_TILE_main_sign2, 90, 0);
////            renderer_handle();
//            break;
//        default:
//            stop=true;
//            break;
//    }
//    state++;
//}


//void scripting_init();
//void scripting_handle();

int main() {
    serial_init();
//    renderer_init();
//    scripting_init();

    uint8_t test[]={
            0x00,
            0x00,
            0x00, 0x00, //x
            0x00, 0x00, //y
            0x80, 0x02, //w
            0xe0, 0x01, //h
            0x00, 0x7f, 0x00, // color
            0x80
            };
    serial_send(test, 14);
    serial_handle();

    sleep(1);

    serial_send(test, 14);
    serial_handle();


//    while(!stop) {
//        if(!serial_handle())
//            break;
////        renderer_handle();
////        scripting_handle();
////        event_loop();
//    }

    return 0;
}
