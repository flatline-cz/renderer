#include <unistd.h>
#include <stdlib.h>
#include "renderer.h"
#include "ri-constants.h"
#include "window.h"
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
