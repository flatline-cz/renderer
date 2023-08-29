//
// Created by tumap on 8/29/23.
//
#include "system-config.h"
#include "data-upload.h"
#include "spi-flash.h"

static tUploadDataRequest *current;
static uint32_t position;

#define BUFFER_SIZE         4096
static uint8_t bufferA_data[BUFFER_SIZE];
static uint8_t bufferB_data[BUFFER_SIZE];

typedef enum tagBufferState {
    BUFFER_STATE_IDLE,
    BUFFER_STATE_READING,
    BUFFER_STATE_READ,
    BUFFER_STATE_UPLOADING
} eBufferState;

typedef struct tagBuffer {
    uint8_t *buffer;
    eBufferState state;
    uint32_t position;
    uint32_t length;
} tBuffer;

static tBuffer bufferA;
static tBuffer bufferB;

static tSPIFlashRequest read_request;

void upload_data_init() {
    current = 0;
    bufferA.buffer = bufferA_data;
    bufferB.buffer = bufferB_data;
}

void upload_data_start(tUploadDataRequest *request) {
    current = request;
    current->finished=false;
    position = 0;

    bufferA.position = 0;
    bufferB.position = 0;
    bufferA.state = BUFFER_STATE_IDLE;
    bufferB.state = BUFFER_STATE_IDLE;
}

static inline void start_reading(tBuffer *buffer) {
    buffer->position = position;
    buffer->length = current->length - position;
    if (buffer->length > BUFFER_SIZE)
        buffer->length = BUFFER_SIZE;
    position += buffer->length;
    buffer->state = BUFFER_STATE_READING;

    read_request.buffer = buffer->buffer;
    read_request.bank = FLASH_BANK_SCENE;
    read_request.address = current->source_addr + buffer->position;
    read_request.length = buffer->length;
    spi_flash_read(&read_request);
}

bool upload_data_handle() {
    if (!current)
        return false;

    // finished?
    if (bufferA.state == BUFFER_STATE_IDLE && position == current->length) {
        current->finished = true;
        current = 0;
        return true;
    }

    // initialize read on buffer A?
    if (bufferA.state == BUFFER_STATE_IDLE && position != current->length) {
        start_reading(&bufferA);
        return true;
    }

    // initialize read on buffer B?
//    if (bufferB.state == BUFFER_STATE_IDLE && bufferA.state != BUFFER_STATE_READING && position != current->length) {
//        start_reading(&bufferB);
//        return true;
//    }

    // read on buffer A finished?
    if (bufferA.state == BUFFER_STATE_READING) {
        if (read_request.status == SPI_FLASH_DONE) {
            bufferA.state = BUFFER_STATE_READ;
            return true;
        }
    }

    // read on buffer B finished?
//    if (bufferB.state == BUFFER_STATE_READING) {
//        if (read_request.status == SPI_FLASH_DONE) {
//            bufferB.state = BUFFER_STATE_READ;
//            return true;
//        }
//    }

    // uploading finished?
    if (bufferA.state == BUFFER_STATE_UPLOADING && current->updateFinishedRoutine()) {
        bufferA.state = BUFFER_STATE_IDLE;
    }
//    if (bufferB.state == BUFFER_STATE_UPLOADING && current->updateFinishedRoutine()) {
//        bufferB.state = BUFFER_STATE_IDLE;
//    }

    // upload buffer A?
    if(bufferA.state==BUFFER_STATE_READ) {
        current->uploadDataRoutine(bufferA.buffer, current->target_addr+bufferA.position, bufferA.length);
        bufferA.state=BUFFER_STATE_UPLOADING;
    }

//    // upload buffer B?
//    if(bufferB.state==BUFFER_STATE_READ && bufferA.state!=BUFFER_STATE_UPLOADING) {
//        current->uploadDataRoutine(bufferB.buffer, current->target_addr+bufferB.position, bufferB.length);
//        bufferB.state=BUFFER_STATE_UPLOADING;
//    }


    return true;
}

