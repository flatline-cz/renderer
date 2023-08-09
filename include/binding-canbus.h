//
// Created by tumap on 12/6/22.
//

#ifndef DASHBOARD_RENDERER_CANBUS_H
#define DASHBOARD_RENDERER_CANBUS_H

#include <stdbool.h>
#include <can.h>
#include "canbus-constants.h"

#define BINDING_CANBUS_MAX_FIELDS       16

typedef struct tagBindingCANBUSField {
    uint8_t type;
    union {
        bool boolean;
        uint32_t integer;
        float real;
    };
} tBindingCANBUSField;

typedef struct tagBindingCANBUSMessage {
   eBindingCANBUSMessage msg;
   unsigned field_count;
   tBindingCANBUSField fields[BINDING_CANBUS_MAX_FIELDS];
} tBindingCANBUSMessage;

typedef bool (*rBindingCANBUSRoutine)(tBindingCANBUSMessage* msg, void* arg);

void binding_canbus_init();

bool binding_canbus_handle(tCANMessage* msg);

void binding_canbus_register(eBindingCANBUSMessage msg, rBindingCANBUSRoutine routine, void* arg);

void binding_canbus_deregister(eBindingCANBUSMessage msg, rBindingCANBUSRoutine routine, void* arg);

#endif //DASHBOARD_RENDERER_CANBUS_H
