//
// Created by tumap on 8/9/23.
//

#ifndef HEAD_UNIT_BINDING_CANBUS_DEFINITION_H
#define HEAD_UNIT_BINDING_CANBUS_DEFINITION_H

#include <stdbool.h>
#include <stdint.h>
#include <can.h>

typedef struct tagBindingCANBUSDefBitSplice {
    uint8_t byte;
    uint8_t src_right;
    uint8_t mask;
    uint8_t dst_left;
} tBindingCANBUSDefBitSplice;

extern const tBindingCANBUSDefBitSplice binding_canbus_bit_splices[];

typedef struct tagBindingCANBUSDefField {
    uint16_t first_bit_splice;
    uint8_t bit_splices;
    int8_t sign_bits;
} tBindingCANBUSDefField;

extern const tBindingCANBUSDefField binding_canbus_fields[];

typedef struct tagBindingCANBUSDefMessage {
    // message identification
    unsigned channel;
    uint32_t id;
    uint8_t dlc;

    // message content decoding
    uint8_t field_count;
    uint16_t first_field;
} tBindingCANBUSDefMessage;

extern const tBindingCANBUSDefMessage binding_canbus_messages[];
extern const unsigned binding_canbus_message_count;

#endif //HEAD_UNIT_BINDING_CANBUS_DEFINITION_H
