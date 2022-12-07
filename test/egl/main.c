#include <unistd.h>
#include <stdlib.h>
#include "renderer.h"
#include "ri-constants.h"
#include "../../src/opengl/window.h"
#include "profile.h"
#include "scripting.h"


int main() {
    renderer_init();
    window_init();
    scripting_init();

#pragma clang diagnostic push
#pragma ide diagnostic ignored "EndlessLoop"
    while(true) {
        bool didSomething;
        didSomething=renderer_handle();
        didSomething|=scripting_handle();
        if(didSomething)
            continue;
        sleep_a_bit();
    }
#pragma clang diagnostic pop

    return 0;
}

const char* renderer_script=
        // define tile names
        " 0 const RENDER_TILE_main "
        " 1 const RENDER_TILE_main_sign1 "
        " 2 const RENDER_TILE_main_sign2 "

        // show screen
        " RENDER_TILE_main show_screen "
;
