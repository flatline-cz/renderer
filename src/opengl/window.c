//
// Created by tumap on 26.12.19.
//
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/select.h>
#include <termios.h>
#include "window.h"

#define GLFW_INCLUDE_ES2

#include <GLFW/glfw3.h>
#include <memory.h>

static GLFWwindow *window;
#define SCREEN_WIDTH    640
#define SCREEN_HEIGHT   480


static void reset_terminal_mode();
static void set_conio_terminal_mode();

void err_cb(int error, const char *text) {
    fprintf(stderr, "Failed: %s\r\n", text);
}

void opengl_init();

void window_init() {
    set_conio_terminal_mode();

    glfwSetErrorCallback(err_cb);
    if(glfwInit()==GLFW_FALSE) {
        exit(1);
    }
    glfwWindowHint(GLFW_CLIENT_API, GLFW_OPENGL_ES_API);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 2);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0);
    window = glfwCreateWindow(SCREEN_WIDTH, SCREEN_HEIGHT, __FILE__, NULL, NULL);
    glfwMakeContextCurrent(window);

#ifndef SILENT
    fprintf(stderr, "GL_VERSION  : %s\r\n", glGetString(GL_VERSION));
    fprintf(stderr, "GL_RENDERER : %s\r\n", glGetString(GL_RENDERER));
#endif

    glViewport(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);
    glClear(GL_COLOR_BUFFER_BIT);
    glDisable(GL_DEPTH_TEST);
    // swap buffers
    window_swap_buffers();

    opengl_init();
}

void window_swap_buffers() {
    if (glfwWindowShouldClose(window))
        exit(0);
    glfwPollEvents();
    glfwSwapBuffers(window);
}

static struct termios orig_termios;

static void reset_terminal_mode()
{
    tcsetattr(0, TCSANOW, &orig_termios);
}

void set_conio_terminal_mode()
{
    struct termios new_termios;

    /* take two copies - one for now, one for later */
    tcgetattr(0, &orig_termios);
    memcpy(&new_termios, &orig_termios, sizeof(new_termios));

    /* register cleanup handler, and set the new terminal mode */
    atexit(reset_terminal_mode);
    cfmakeraw(&new_termios);
    tcsetattr(0, TCSANOW, &new_termios);
}
