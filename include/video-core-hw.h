//
// Created by tumap on 8/15/22.
//

#ifndef RENDERER_VIDEO_CORE_HW_H
#define RENDERER_VIDEO_CORE_HW_H

#include <stdbool.h>
#include <stdint.h>

typedef enum eVCRequestType_ {
    VC_GET_STATUS,
    VC_SET_MODE,
    VC_FILL_QUEUE,
    VC_FILL_FLASH_ROW,
    VC_FETCH_FLASH_ROW,
    VC_READ_FLASH,
    VC_ERASE_FLASH,
    VC_PROGRAM_FLASH,
    VC_SET_VIDEO_DESCRIPTOR
} eVCRequestType;

typedef enum eVCRenderingMode_ {
    DISPLAY_OFF,
    NORMAL,
    VIDEO
} eVCRenderingMode;

#define CHECK_VC_STATUS_FLASH_DONE(s) ((s) & 0x02)
#define CHECK_VC_STATUS_FLASH_FAILED(s) ((s) & 0x04)
#define CHECK_VC_STATUS_FLASH_BUSY(s) ((s) &0x08)

typedef struct tVCRequest_ {
    eVCRequestType type;
    union {
        struct {
            uint8_t status;
        } status;
        struct {
            uint8_t *buffer;
            uint16_t length;
        } fill_queue;
        struct {
            uint8_t *buffer;
        } flash_data;
        struct {
            uint32_t address;
        } flash_address;
        struct {
            eVCRenderingMode mode;
        } rendering_mode;
        struct {
            uint8_t block;
            uint8_t row;
        } video_descriptor;
    };
} tVCRequest;

bool vc_check_vsync();

bool vc_check_interrupt();

bool vc_send_request(tVCRequest *request);

bool vc_response_ready();



#endif //RENDERER_VIDEO_CORE_HW_H
