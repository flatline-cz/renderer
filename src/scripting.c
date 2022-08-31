//
// Created by tumap on 8/31/22.
//
#include <stdlib.h>
#include <stdarg.h>
#include <stdio.h>
#include "zforth.h"
#include "iso-tp.h"
#include "profile.h"

const char *forth_init_code =
        ": "
        "";

zf_input_state zf_host_sys(zf_syscall_id id, const char *input) {
    char buf[16];

    switch((int)id) {

        case ZF_SYSCALL_EMIT:
            putchar((char)zf_pop());
            fflush(stdout);
            break;

        case ZF_SYSCALL_PRINT: {
            float value=zf_pop();
            fprintf(stderr, "%g", value);
            break;
        }
    }

    return 0;
}

zf_cell zf_host_parse_num(const char *buf) {
    char *end;
    zf_cell v = strtof(buf, &end);
    if (*end != '\0') {
        zf_abort(ZF_ABORT_NOT_A_WORD);
    }
    return v;
}

void zf_host_trace(const char *fmt, va_list va) {
    fprintf(stderr, "\033[1;30m");
    vfprintf(stderr, fmt, va);
    fprintf(stderr, "\033[0m");
}

void scripting_init() {
    zf_init(1);
    zf_bootstrap();
    zf_result result = zf_eval(": . 1 sys ; 2.5 . cr . .\"Hello world\" .");
    if (result != ZF_OK)
        fprintf(stderr, "Forth failure %d\n", result);
}


static tTime idle = 0;

void scripting_handle() {
    tTime now = time_get();
    if (now < idle)
        return;
    idle = now + 2000;
    zf_result result = zf_eval("128 sys");
    if (result != ZF_OK)
        fprintf(stderr, "Forth failure %d\n", result);

}