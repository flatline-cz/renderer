//
// Created by tumap on 8/31/22.
//
#include <stdlib.h>
#include <stdarg.h>
#include <stdio.h>
#include "zforth.h"
#include "profile.h"
#include "scripting.h"
#include "renderer.h"

extern const char *forth_init_code;

zf_input_state zf_host_sys(zf_syscall_id id, const char *input) {
    char buf[16];

    switch ((int) id) {

        case ZF_SYSCALL_EMIT:
            putchar((char) zf_pop());
            fflush(stdout);
            break;

        case ZF_SYSCALL_PRINT: {
            uint32_t value = zf_pop();
            fprintf(stdout, ZF_CELL_FMT, value);
            fflush(stdout);
            break;
        }

        case ZF_SYSCALL_USER + 0: {
            uint32_t y = zf_pop();
            uint32_t x = zf_pop();
            uint32_t tile_handle = zf_pop();
            renderer_set_position(tile_handle, x, y);
            break;
        }

        case ZF_SYSCALL_USER + 1: {
            uint32_t tile_handle = zf_pop();
            renderer_show_screen(tile_handle);
            break;
        }

        case ZF_SYSCALL_USER + 2: {
            uint32_t visible = zf_pop();
            uint32_t tile_handle = zf_pop();
            renderer_set_visibility(tile_handle, visible != 0);
            break;
        }

        case ZF_SYSCALL_USER + 3: {
            uint32_t alpha = zf_pop();
            uint32_t blue = zf_pop();
            uint32_t green = zf_pop();
            uint32_t red = zf_pop();
            uint32_t tile_handle = zf_pop();
            tRendererColor color;
            color.alpha=alpha;
            color.red=red;
            color.green=green;
            color.blue=blue;
            renderer_set_color(tile_handle, color);
            break;
        }
    }

    return 0;
}

zf_cell zf_host_parse_num(const char *buf) {
    char *end;
    zf_cell v = strtol(buf, &end, 10);
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
    zf_init(0);
    zf_bootstrap();
    zf_result result;
    result = zf_eval(": . 1 sys ;");
    if (result != ZF_OK)
        fprintf(stderr, "Forth failure %d\n", result);
    result = zf_eval(forth_init_code);
    if (result != ZF_OK)
        fprintf(stderr, "Forth failure %d\n", result);

    result = zf_eval(renderer_script);
    if (result != ZF_OK)
        fprintf(stderr, "Forth failure %d\n", result);
}


static tTime idle = 0;

bool scripting_handle() {
    tTime now = time_get();
    if (now < idle)
        return false;
    idle = now + 100;
//    zf_push((zf_cell) now);
//    zf_result result = zf_eval("idle");
//    if (result != ZF_OK)
//        fprintf(stderr, "Forth failure %d\n", result);

    if(now > 2500) {
        tRendererColor color={.alpha=0xff, .green=0x60, .red=0x60, .blue=0x60 };
        renderer_set_color(RENDER_TILE_main_sign_abs, color);
        renderer_set_color(RENDER_TILE_main_sign_steering, color);
    }

    renderer_set_visibility(RENDER_TILE_main_sign_turn_left, (now/1000)&1);

    return true;

}