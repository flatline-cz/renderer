//
// Created by tumap on 8/9/23.
//
#include "binding-canbus.h"
#include "binding-canbus-definition.h"

static tBindingCANBUSMessage binding_msg;

void binding_canbus_call_handler(tBindingCANBUSMessage *msg);

bool binding_canbus_handle(tCANMessage *msg) {
    // try to find message
    int msg_idx;
    const tBindingCANBUSDefMessage *msg_def = binding_canbus_messages;
    for (msg_idx = 0; msg_idx < binding_canbus_message_count; msg_idx++, msg_def++) {
        if (msg->channel == msg_def->channel && msg->id == msg_def->id && msg->dlc == msg_def->dlc)
            break;
    }
    if (msg_idx == binding_canbus_message_count)
        return false;

    // decode message fields
    binding_msg.msg = msg_idx;
    unsigned field_count = msg_def->field_count;
    binding_msg.field_count = field_count;

    const tBindingCANBUSDefField *field_def = binding_canbus_fields + msg_def->first_field;
    tBindingCANBUSField *field = binding_msg.fields;
    while (field_count--) {
        // process all bit slices
        uint32_t field_value = 0;
        unsigned slice_count = field_def->bit_splices;
        const tBindingCANBUSDefBitSplice *slice = binding_canbus_bit_splices + field_def->first_bit_splice;
        while (slice_count--) {
            // process slice
            uint32_t value = msg->data[slice->byte];
            value >>= slice->src_right;
            value &= slice->mask;
            value <<= slice->dst_left;
            field_value |= value;

            // next slice
            slice++;
        }

        // TODO: process sign

        // do the type mapping
        switch (field_def->type) {
            case CANBUS_FIELD_BOOLEAN:
            default:
                field->type = 0;
                field->boolean = field_value != 0;
                break;
            case CANBUS_FIELD_INTEGER:
                field->type = 1;
                field->integer = ((int32_t) field_value) + field_def->integer_offset;
                break;
            case CANBUS_FIELD_FLOAT:
                field->type = 2;
                field->real = ((float) ((int32_t) field_value)) * field_def->float_scale + field_def->float_offset;
                break;

        }

        // next field
        field_def++;
        field++;
    }

    // call handlers
    binding_canbus_call_handler(&binding_msg);

    return true;
}
