//
// Created by tumap on 9/1/22.
//
#include <fcntl.h>
#include <termios.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <memory.h>
#include "serial.h"

static char buffer[4096];
static unsigned buffer_length=0;
static unsigned buffer_position;
static int sock;

static int init_interface_Serial(const char *interface_name);


void serial_init() {
    sock=STDERR_FILENO;
//    sock = init_interface_Serial("/dev/ttyUSB1");
//    fcntl(sock, F_SETFL, fcntl(sock, F_GETFL) | O_NONBLOCK);
}

bool serial_handle() {
    if(buffer_length==0)
        return false;

    int written = (int) write(sock, buffer + buffer_position, buffer_length-buffer_position);
    if (written < 0) {
        if (errno == EWOULDBLOCK) {
            return true;
        }
        perror(__FUNCTION__);
        exit(1);
    }

    buffer_position+=written;
    if(buffer_position==buffer_length) {
        buffer_position=0;
        buffer_length=0;
    }

    return true;
}

void serial_send(const char* data, unsigned length) {
    if(buffer_length!=0)
        return;
    buffer_length=length;
    memcpy(buffer, data, length);
}


static int init_interface_Serial(const char *interface_name) {
    int sock = open(interface_name, O_RDWR);

    struct termios tty;
    if (tcgetattr(sock, &tty) != 0) {
        perror("Serial port failed");
        exit(1);
    }
    tty.c_cflag &= ~PARENB;
    tty.c_cflag &= ~CSTOPB;
    tty.c_cflag &= ~CSIZE;
    tty.c_cflag |= CS8;
    tty.c_cflag &= ~CRTSCTS;
    tty.c_cflag |= CREAD | CLOCAL;

    tty.c_lflag &= ~ICANON;
    tty.c_lflag &= ~ECHO;
    tty.c_lflag &= ~ECHOE;
    tty.c_lflag &= ~ECHONL;
    tty.c_lflag &= ~ISIG;
    tty.c_lflag &= ~(IXON | IXOFF | IXANY);
    tty.c_lflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL);

    tty.c_oflag &= ~OPOST;
    tty.c_oflag &= ~ONLCR;

    tty.c_cc[VTIME] = 0;
    tty.c_cc[VMIN] = 0;

    cfsetispeed(&tty, B115200);
    cfsetospeed(&tty, B115200);

    if (tcsetattr(sock, TCSANOW, &tty) != 0) {
        perror("Serial port failed");
        exit(1);
    }
    return sock;
}
