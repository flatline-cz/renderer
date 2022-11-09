//
// Created by tumap on 7/31/22.
//

#ifndef RENDERER_RENDERER_H
#define RENDERER_RENDERER_H

#include <stdbool.h>

void renderer_init();

bool renderer_handle();

bool renderer_update_display(unsigned buffer);

int renderer_display_ready();


#endif //RENDERER_RENDERER_H
