//
// Created by tumap on 8/7/23.
//
#include "video-core-hw.h"
#include <stdlib.h>
#include <libftdi1/ftdi.h>
#include <stdio.h>
#include <unistd.h>
#include "profile.h"

#define TRACE(msg, ...) fprintf(stderr, "%d.%03ds : "  msg  "\n", TIME_GET/1000, TIME_GET%1000, ##__VA_ARGS__);

// FPGA bit stream
extern const unsigned char FPGA_bit_stream[];
extern const unsigned int FPGA_bit_stream_len;

// forward declarations
static void mpsse_init();

static void mpsse_chip_select();

static void mpsse_chip_deselect();

static void mpsse_sram_reset();

static void mpsse_end_reset();

static bool mpsse_get_cdone(void);

static void mpsse_send_dummy_bytes(uint8_t n);

static void mpsse_send_dummy_bit(void);

static void mpsse_send(const uint8_t *data, int n);

static void mpsse_send_receive(const uint8_t *data_send, uint8_t *data_receive, int n);


void program_ICE40() {
    // ---------------------------------------------------------
    // Reset
    // ---------------------------------------------------------
    TRACE("FPGA: reset...")

    mpsse_sram_reset();

    mpsse_chip_select();
    usleep(2000);

    TRACE("FPGA: cdone: %s", mpsse_get_cdone() ? "high" : "low")

    // ---------------------------------------------------------
    // Program
    // ---------------------------------------------------------

    TRACE("FPGA: programming...")
    unsigned position = 0;
    while (position < FPGA_bit_stream_len) {
        unsigned len = FPGA_bit_stream_len - position;
        if (len > 4096)
            len = 4096;
        mpsse_send(FPGA_bit_stream + position, (int) len);
        position += len;
    }

    mpsse_send_dummy_bytes(7);
//    mpsse_send_dummy_bit();

    mpsse_end_reset();
    TRACE("FPGA: cdone: %s", mpsse_get_cdone() ? "high" : "low")
}

void video_core_hw_init() {
    // initialize SPI interface
    mpsse_init();

    // program FPGA
    program_ICE40();
}

bool video_core_hw_handle() {
    // nothing to handle, all operations are synchronous
    return false;
}

bool video_core_hw_idle() {
    // always idle, all operations are synchronous
    return true;
}

bool video_core_hw_send(const uint8_t *prefix, uint16_t prefix_length,
                        const uint8_t *data, uint16_t data_length) {
    mpsse_chip_select();
    if (prefix_length && prefix)
        mpsse_send(prefix, prefix_length);
    mpsse_send(data, data_length);
    mpsse_chip_deselect();
    return true;
}

bool video_core_hw_exchange(const uint8_t *data_send, uint8_t *data_receive, uint16_t length) {
    mpsse_chip_select();
    mpsse_send_receive(data_send, data_receive, length);
    mpsse_chip_deselect();
    return true;
}

// ************************************************************************
// *** USB-FTDI-SPI interface routines                                  ***
// ************************************************************************

struct ftdi_context mpsse_ftdic;
bool mpsse_ftdic_open = false;
bool mpsse_ftdic_latency_set = false;
unsigned char mpsse_ftdi_latency;

#define MC_DATA_TMS  (0x40) /* When set use TMS mode */
#define MC_DATA_IN   (0x20) /* When set read data (Data IN) */
#define MC_DATA_OUT  (0x10) /* When set write data (Data OUT) */
#define MC_DATA_LSB  (0x08) /* When set input/output data LSB first. */
#define MC_DATA_ICN  (0x04) /* When set receive data on negative clock edge */
#define MC_DATA_BITS (0x02) /* When set count bits not bytes */
#define MC_DATA_OCN  (0x01) /* When set update data on negative clock edge */


/* MPSSE engine command definitions */
enum mpsse_cmd {
    /* Mode commands */
    MC_SETB_LOW = 0x80, /* Set Data bits LowByte */
    MC_READB_LOW = 0x81, /* Read Data bits LowByte */
    MC_SETB_HIGH = 0x82, /* Set Data bits HighByte */
    MC_READB_HIGH = 0x83, /* Read data bits HighByte */
    MC_LOOPBACK_EN = 0x84, /* Enable loopback */
    MC_LOOPBACK_DIS = 0x85, /* Disable loopback */
    MC_SET_CLK_DIV = 0x86, /* Set clock divisor */
    MC_FLUSH = 0x87, /* Flush buffer fifos to the PC. */
    MC_WAIT_H = 0x88, /* Wait on GPIOL1 to go high. */
    MC_WAIT_L = 0x89, /* Wait on GPIOL1 to go low. */
    MC_TCK_X5 = 0x8A, /* Disable /5 div, enables 60MHz master clock */
    MC_TCK_D5 = 0x8B, /* Enable /5 div, backward compat to FT2232D */
    MC_EN_3PH_CLK = 0x8C, /* Enable 3 phase clk, DDR I2C */
    MC_DIS_3PH_CLK = 0x8D, /* Disable 3 phase clk */
    MC_CLK_N = 0x8E, /* Clock every bit, used for JTAG */
    MC_CLK_N8 = 0x8F, /* Clock every byte, used for JTAG */
    MC_CLK_TO_H = 0x94, /* Clock until GPIOL1 goes high */
    MC_CLK_TO_L = 0x95, /* Clock until GPIOL1 goes low */
    MC_EN_ADPT_CLK = 0x96, /* Enable adaptive clocking */
    MC_DIS_ADPT_CLK = 0x97, /* Disable adaptive clocking */
    MC_CLK8_TO_H = 0x9C, /* Clock until GPIOL1 goes high, count bytes */
    MC_CLK8_TO_L = 0x9D, /* Clock until GPIOL1 goes low, count bytes */
    MC_TRI = 0x9E, /* Set IO to only drive on 0 and tristate on 1 */
    /* CPU mode commands */
    MC_CPU_RS = 0x90, /* CPUMode read short address */
    MC_CPU_RE = 0x91, /* CPUMode read extended address */
    MC_CPU_WS = 0x92, /* CPUMode write short address */
    MC_CPU_WE = 0x93, /* CPUMode write extended address */
};

void mpsse_check_rx() {
    while (1) {
        uint8_t data;
        int rc = ftdi_read_data(&mpsse_ftdic, &data, 1);
        if (rc <= 0)
            break;
        fprintf(stderr, "unexpected rx byte: %02X\n", data);
    }
}

void mpsse_error(int status) {
    mpsse_check_rx();
    fprintf(stderr, "ABORT.\n");
    if (mpsse_ftdic_open) {
        if (mpsse_ftdic_latency_set)
            ftdi_set_latency_timer(&mpsse_ftdic, mpsse_ftdi_latency);
        ftdi_usb_close(&mpsse_ftdic);
    }
    ftdi_deinit(&mpsse_ftdic);
    exit(status);
}

void mpsse_send_byte(uint8_t data) {
    int rc = ftdi_write_data(&mpsse_ftdic, &data, 1);
    if (rc != 1) {
        fprintf(stderr, "Write error (single byte, rc=%d, expected %d).\n", rc, 1);
        mpsse_error(2);
    }
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static void mpsse_init() {
    enum ftdi_interface ftdi_ifnum = INTERFACE_A;

    ftdi_init(&mpsse_ftdic);
    ftdi_set_interface(&mpsse_ftdic, ftdi_ifnum);

    if (ftdi_usb_open(&mpsse_ftdic, 0x0403, 0x6010) && ftdi_usb_open(&mpsse_ftdic, 0x0403, 0x6014)) {
        fprintf(stderr, "Can't find iCE FTDI USB device (vendor_id 0x0403, device_id 0x6010 or 0x6014).\n");
        mpsse_error(2);
    }

    mpsse_ftdic_open = true;

    if (ftdi_usb_reset(&mpsse_ftdic)) {
        fprintf(stderr, "Failed to reset iCE FTDI USB device.\n");
        mpsse_error(2);
    }

    if (ftdi_usb_purge_buffers(&mpsse_ftdic)) {
        fprintf(stderr, "Failed to purge buffers on iCE FTDI USB device.\n");
        mpsse_error(2);
    }

    if (ftdi_get_latency_timer(&mpsse_ftdic, &mpsse_ftdi_latency) < 0) {
        fprintf(stderr, "Failed to get latency timer (%s).\n", ftdi_get_error_string(&mpsse_ftdic));
        mpsse_error(2);
    }

    /* 1 is the fastest polling, it means 1 kHz polling */
    if (ftdi_set_latency_timer(&mpsse_ftdic, 1) < 0) {
        fprintf(stderr, "Failed to set latency timer (%s).\n", ftdi_get_error_string(&mpsse_ftdic));
        mpsse_error(2);
    }

    mpsse_ftdic_latency_set = true;

    /* Enter MPSSE (Multi-Protocol Synchronous Serial Engine) mode. Set all pins to output. */
    if (ftdi_set_bitmode(&mpsse_ftdic, 0xff, BITMODE_MPSSE) < 0) {
        fprintf(stderr, "Failed to set BITMODE_MPSSE on iCE FTDI USB device.\n");
        mpsse_error(2);
    }

    // enable clock divide by 5
    mpsse_send_byte(MC_TCK_D5);

    // set 6 MHz clock
    mpsse_send_byte(MC_SET_CLK_DIV);
    mpsse_send_byte(0x00);
    mpsse_send_byte(0x00);
}

#pragma clang diagnostic pop

//2200377186/2010
void mpsse_close(void) {
    ftdi_set_latency_timer(&mpsse_ftdic, mpsse_ftdi_latency);
    ftdi_disable_bitbang(&mpsse_ftdic);
    ftdi_usb_close(&mpsse_ftdic);
    ftdi_deinit(&mpsse_ftdic);
}

void mpsse_set_gpio(uint8_t gpio, uint8_t direction) {
    mpsse_send_byte(MC_SETB_LOW);
    mpsse_send_byte(gpio); /* Value */
    mpsse_send_byte(direction); /* Direction */
}

static void set_cs_creset(int cs_b, int creset_b) {
    uint8_t gpio = 0;
    uint8_t direction = 0x03;

    if (!cs_b) {
        // ADBUS4 (GPIOL0)
        direction |= 0x10;
    }

    if (!creset_b) {
        // ADBUS7 (GPIOL3)
        direction |= 0x80;
    }

    mpsse_set_gpio(gpio, direction);
}

static void mpsse_chip_select() {
    set_cs_creset(0, 1);
    usleep(100);
}

static void mpsse_chip_deselect() {
    set_cs_creset(1, 1);
    usleep(100);
}

static void mpsse_sram_reset() {
    set_cs_creset(0, 0);
    usleep(200);
}

static void mpsse_send(const uint8_t *data, int n) {
    if (n < 1)
        return;

    /* Output only, update data on negative clock edge. */
    mpsse_send_byte(MC_DATA_OUT | MC_DATA_OCN);
    mpsse_send_byte(n - 1);
    mpsse_send_byte((n - 1) >> 8);

    int rc = ftdi_write_data(&mpsse_ftdic, data, n);
    if (rc != n) {
        fprintf(stderr, "Write error (chunk, rc=%d, expected %d).\n", rc, n);
        mpsse_error(2);
    }
}

uint8_t mpsse_recv_byte() {
    uint8_t data;
    while (1) {
        int rc = ftdi_read_data(&mpsse_ftdic, &data, 1);
        if (rc < 0) {
            fprintf(stderr, "Read error.\n");
            mpsse_error(2);
        }
        if (rc == 1)
            break;
        usleep(100);
    }
    return data;
}

static void mpsse_send_receive(const uint8_t *data_send,
                               uint8_t *data_receive,
                               int n) {
    if (n < 1)
        return;

    /* Input and output, update data on negative edge read on positive. */
    mpsse_send_byte(MC_DATA_IN | MC_DATA_OUT | MC_DATA_OCN);
    mpsse_send_byte(n - 1);
    mpsse_send_byte((n - 1) >> 8);

    int rc = ftdi_write_data(&mpsse_ftdic, data_send, n);
    if (rc != n) {
        fprintf(stderr, "Write error (chunk, rc=%d, expected %d).\n", rc, n);
        mpsse_error(2);
    }

    for (int i = 0; i < n; i++)
        data_receive[i] = mpsse_recv_byte();
}

static int mpsse_readb_low(void) {
    uint8_t data;
    mpsse_send_byte(MC_READB_LOW);
    data = mpsse_recv_byte();
    return data;
}

static bool mpsse_get_cdone(void) {
    // ADBUS6 (GPIOL2)
    return (mpsse_readb_low() & 0x40) != 0;
}

static void mpsse_send_dummy_bytes(uint8_t n) {
    // add 8 x count dummy bits (aka n bytes)
    mpsse_send_byte(MC_CLK_N8);
    mpsse_send_byte(n - 1);
    mpsse_send_byte(0x00);

}

static void mpsse_send_dummy_bit(void) {
    // add 1  dummy bit
    mpsse_send_byte(MC_CLK_N);
    mpsse_send_byte(0x00);
}

static void mpsse_end_reset() {
    set_cs_creset(1, 1);
    while(!mpsse_get_cdone());
}
