#include <unistd.h>
#include <stdlib.h>
#include "renderer.h"
#include "ri-constants.h"
#include "window.h"
#include "profile.h"

static bool stop=false;
static unsigned state=0;
static tTime next_state=0;


static void event_loop() {
    tTime now=time_get();
    if(now<next_state)
        return;

    next_state=now+5000;

    switch(state) {
        case 0:
            renderer_show_screen(RENDER_TILE_main);
//            renderer_handle();
            break;
        case 1:
            renderer_set_visibility(RENDER_TILE_main_sign2, true);
//            renderer_handle();
            break;
        case 2:
            renderer_set_position(RENDER_TILE_main_sign2, 90, 0);
//            renderer_handle();
            break;
        default:
            stop=true;
            break;
    }
    state++;
}


void scripting_init();
void scripting_handle();

int main() {
    renderer_init();
    window_init();
    scripting_init();

    while(!stop) {
        renderer_handle();
        scripting_handle();
        event_loop();
    }

    return 0;
}
