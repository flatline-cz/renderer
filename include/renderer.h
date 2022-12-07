//
// Created by tumap on 7/31/22.
//

#ifndef RENDERER_RENDERER_H
#define RENDERER_RENDERER_H

#include <stdbool.h>
#include <stdint.h>

//void renderer_init();

//bool renderer_handle();

void renderer_update_display(uint8_t* queue_data, uint16_t queue_max_length,
                             uint16_t* queue_lenth);



#endif //RENDERER_RENDERER_H
