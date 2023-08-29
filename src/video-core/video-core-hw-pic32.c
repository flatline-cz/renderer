//
// Created by tumap on 8/7/23.
//
#include <xc.h>
#include <sys/kmem.h>
#include "system-config.h"
#include "system-clock.h"
#include "video-core-hw.h"
#include "pic32/pic32mz-gpio.h"
#include "pic32/pic32mz-regs.h"
#include "pic32/pic32mz-int.h"
#include "profile.h"


#define SPI_CLOCK_LIMIT         10
#define SPI_CLOCK_DIV_          ((PBCLK2_FREQ+SPI_CLOCK_LIMIT-1)/SPI_CLOCK_LIMIT)
#define SPI_CLOCK_DIV           (((SPI_CLOCK_DIV_ + 1) / 2) - 1)

// FPGA bit stream
extern const unsigned char FPGA_bit_stream[];
extern const unsigned int FPGA_bit_stream_len;

typedef enum tagState {
    STATE_INIT,
    STATE_RESET,
    STATE_RESET_WAIT,
    STATE_CODE_UPLOAD,
    STATE_CODE_UPLOADED,
    STATE_READY,
    STATE_BUSY
} eState;

static eState state;
static tTime timeout;

// DMA transfer context
static uint32_t transfer_address;
static uint32_t transfer_position;
static uint32_t transfer_length;
static uint32_t transfer_block_size;


void video_core_hw_init() {
    // initialize pin
    ResolveLAT(FPGA_CS_PIN) = 0;
    ResolveTRIS(FPGA_CS_PIN) = 0;
    ResolveClearAnsel(FPGA_CS_PIN);

    ResolveLAT(FPGA_RESET_PIN) = 1;
    ResolveTRIS(FPGA_RESET_PIN) = 0;
    ResolveClearAnsel(FPGA_RESET_PIN);

    ResolveTRIS(FPGA_DONE_PIN) = 1;
    ResolveClearAnsel(FPGA_DONE_PIN);

    // initialize SPI interface
    ResolveSPICON(FPGA_SPI) = 0;
    ResolveSPICONbits(FPGA_SPI).MSTEN = 1;
    ResolveSPICONbits(FPGA_SPI).CKP = 1;
    ResolveSPICONbits(FPGA_SPI).SMP = 1;
    ResolveSPIBRG(FPGA_SPI) = SPI_CLOCK_DIV;
    ResolveSPICONbits(FPGA_SPI).ON = 1;

    // clear context
    state = STATE_INIT;
    transfer_length = 0;
}

static void start_DMA_transfer(const void *src, uint32_t length) {
    // create context
    transfer_address = KVA_TO_PA(src);
    transfer_length = length;
    transfer_position = 0;
    transfer_block_size = length;
    if (transfer_block_size > 65536)
        transfer_block_size = 65536;

    // enable DMA controller
    DMACONSET = _DMACON_ON_MASK;

    // setup channel
    ResolveDCHxCON(FPGA_DMA) = 1;
    ResolveDCHxECON(FPGA_DMA) = 0;
    ResolveDCHxECONSET(FPGA_DMA) = (IRQ_NUMBER(SPI_TX, FPGA_SPI) << _DCH0ECON_CHSIRQ_POSITION) | _DCH0ECON_SIRQEN_MASK;

    ResolveDCHxSSA(FPGA_DMA) = transfer_address;
    ResolveDCHxSSIZ(FPGA_DMA) = transfer_block_size & 0xffff;
    ResolveDCHxDSA(FPGA_DMA) = KVA_TO_PA(&ResolveSPIBUF(FPGA_SPI));
    ResolveDCHxDSIZ(FPGA_DMA) = 1;
    ResolveDCHxCSIZ(FPGA_DMA) = 1;
    ResolveDCHxINT(FPGA_DMA) = 0;
    ResolveDCHxCONSET(FPGA_DMA) = _DCH0CON_CHEN_MASK;
    ResolveDCHxECONSET(FPGA_DMA) = _DCH0ECON_CFORCE_MASK;
}

static bool is_DMA_transfer_finished() {
    // nothing to transfer?
    if (transfer_length == 0)
        return true;

    // transfer in progress?
    if (ResolveDCHxINTbits(FPGA_DMA).CHSDIF == 0)
        return false;

    // update context
    transfer_length -= transfer_block_size;
    transfer_position += transfer_block_size;

    // end of transfer?
    if (transfer_length == 0)
        return true;

    transfer_block_size = transfer_length;
    if (transfer_block_size > 65536)
        transfer_block_size = 65536;

    // wait until SPI is idle
    while (ResolveSPISTATbits(FPGA_SPI).SPITBE == 0 || ResolveSPISTATbits(FPGA_SPI).SPIBUSY == 1);

    // initiate transfer
    ResolveDCHxSSA(FPGA_DMA) = transfer_address + transfer_position;
    ResolveDCHxSSIZ(FPGA_DMA) = transfer_block_size & 0xffff;
    ResolveDCHxDSA(FPGA_DMA) = KVA_TO_PA(&ResolveSPIBUF(FPGA_SPI));
    ResolveDCHxDSIZ(FPGA_DMA) = 1;
    ResolveDCHxCSIZ(FPGA_DMA) = 1;
    ResolveDCHxINT(FPGA_DMA) = 0;
    ResolveDCHxCONSET(FPGA_DMA) = _DCH0CON_CHEN_MASK;
    ResolveDCHxECONSET(FPGA_DMA) = _DCH0ECON_CFORCE_MASK;

    return false;
}

static void spi_xchg(uint8_t *data_send, uint8_t *data_receive, unsigned length);

bool video_core_hw_handle() {
    // nothing to do?
    if (state == STATE_READY)
        return false;

    // transfer initiated?
//    if (state == STATE_BUSY) {
//        if (is_DMA_transfer_finished()) {
//            state = STATE_READY;
//            ResolveLAT(FPGA_CS_PIN) = 1;
//            return true;
//        }
//        return false;
//    }

    // reset FPGA?
    if (state == STATE_INIT) {
        // trigger FPGA reset
        timeout = TIME_GET + 2;
        state = STATE_RESET;
        ResolveLAT(FPGA_CS_PIN) = 0;
        ResolveLAT(FPGA_RESET_PIN) = 0;
        return true;
    }

    // release FPGA reset?
    if (state == STATE_RESET) {
        if (timeout > TIME_GET)
            return false;

        // release reset
        state = STATE_RESET_WAIT;
        timeout = TIME_GET + 3;
        ResolveLAT(FPGA_RESET_PIN) = 1;
        return true;
    }

    // reset finished?
    if (state == STATE_RESET_WAIT) {
        if (timeout > TIME_GET)
            return false;

        state = STATE_CODE_UPLOAD;
//        spi_xchg((uint8_t*)FPGA_bit_stream, NULL, FPGA_bit_stream_len+13);
        start_DMA_transfer(FPGA_bit_stream, FPGA_bit_stream_len + 13);
        return true;
    }

    // uploading code?
    if (state == STATE_CODE_UPLOAD) {
        if (!is_DMA_transfer_finished())
            return false;
        state = STATE_CODE_UPLOADED;
        ResolveLAT(FPGA_CS_PIN) = 1;
        timeout = TIME_GET + 2;
        return true;
    }

    // code uploaded?
    if (state == STATE_CODE_UPLOADED) {
        if (timeout > TIME_GET)
            return false;
        // verify
        volatile bool done = ResolvePORT(FPGA_DONE_PIN);
        state = done ? STATE_READY : STATE_INIT;
        return true;
    }

    // reset
    state = STATE_INIT;
    return true;
}

bool video_core_hw_idle() {
    return state == STATE_READY;
}

static void spi_xchg(uint8_t *data_send, uint8_t *data_receive, unsigned length) {
    // clear receive buffer
    if (ResolveSPISTATbits(FPGA_SPI).SPIRBF)
        ResolveSPIBUF(FPGA_SPI);
    ResolveSPISTATCLR(FPGA_SPI) = _SPI1STAT_SPIROV_MASK;
    
    volatile uint8_t* p=data_send;
    volatile uint8_t dummy;

    // process each byte
    while (length--) {
        while (ResolveSPISTATbits(FPGA_SPI).SPITBF);
        ResolveSPIBUF(FPGA_SPI) = *(p++);
        while (!ResolveSPISTATbits(FPGA_SPI).SPIRBF);
        if (data_receive) {
            *(data_receive++) = ResolveSPIBUF(FPGA_SPI);
        } else {
            dummy=ResolveSPIBUF(FPGA_SPI);
        }
    }
}

bool video_core_hw_send(uint8_t *prefix, uint16_t prefix_length,
                        uint8_t *data, uint16_t data_length) {
    if (state != STATE_READY)
        return false;

    // assert CS
    ResolveLAT(FPGA_CS_PIN) = 0;

    // send prefix
    if (prefix_length)
        spi_xchg(prefix, NULL, prefix_length);

    if (data_length != 0) {
        spi_xchg(data, NULL, data_length);
        
    }
    // de-assert CS
    ResolveLAT(FPGA_CS_PIN) = 1;
    return true;

    // start transfer
//    state = STATE_BUSY;
//    start_DMA_transfer(data, data_length);

    return true;
}

bool video_core_hw_exchange(uint8_t *data_send, uint8_t *data_receive, uint16_t length) {
    if (state != STATE_READY)
        return false;

    // assert CS
    ResolveLAT(FPGA_CS_PIN) = 0;

    // exchange data over SPI
    spi_xchg(data_send, data_receive, length);

    // de-assert CS
    ResolveLAT(FPGA_CS_PIN) = 1;

    return true;
}
