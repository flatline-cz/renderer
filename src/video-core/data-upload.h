//
// Created by tumap on 8/29/23.
//

#ifndef HEAD_UNIT_DATA_UPLOAD_H
#define HEAD_UNIT_DATA_UPLOAD_H

#include <stdbool.h>
#include <stdint.h>

typedef void (*rUploadDataRoutine)(uint8_t *data, uint32_t offset, uint32_t length);
typedef bool (*rUpdateFinishedRoutine)();

typedef struct tagUploadDataRequest {
    rUploadDataRoutine uploadDataRoutine;
    rUpdateFinishedRoutine updateFinishedRoutine;

    uint32_t source_addr;
    uint32_t target_addr;
    uint32_t length;

    bool finished;
} tUploadDataRequest;

void upload_data_init();

void upload_data_start(tUploadDataRequest* request);

bool upload_data_handle();

#endif //HEAD_UNIT_DATA_UPLOAD_H
