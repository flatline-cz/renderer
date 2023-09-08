//
// Created by tumap on 8/9/23.
//
#include "binding-canbus.h"

typedef struct tagRegistrant {
    eBindingCANBUSMessage msg;
    rBindingCANBUSRoutine routine;
    void *arg;
} tagRegistrant;

#define MAX_REGISTRANTS     64

static tagRegistrant registrants[MAX_REGISTRANTS];

void binding_canbus_init() {
    for (int i = 0; i < MAX_REGISTRANTS; i++)
        registrants[i].routine = 0;
}

void binding_canbus_register(eBindingCANBUSMessage msg, rBindingCANBUSRoutine routine, void *arg) {
    for (int i = 0; i < MAX_REGISTRANTS; i++) {
        if(!registrants[i].routine) {
            registrants[i].msg=msg;
            registrants[i].routine=routine;
            registrants[i].arg=arg;
            return;
        }
    }
}

void binding_canbus_deregister(eBindingCANBUSMessage msg, rBindingCANBUSRoutine routine, void *arg) {

}

void binding_canbus_call_handler(tBindingCANBUSMessage *msg) {
    for(int i=0;i<MAX_REGISTRANTS;i++) {
        if(registrants[i].routine && registrants[i].msg==msg->msg) {
            registrants[i].routine(msg, registrants[i].arg);
        }
    }
}

