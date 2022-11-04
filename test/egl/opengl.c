//
// Created by tumap on 8/31/22.
//
#include <stdio.h>
#include <GLES2/gl2.h>
#include <malloc.h>
#include <stdlib.h>
#include "video-core-hw.h"
#include "window.h"
#include "profile.h"

#define SCREEN_WIDTH  640
#define SCREEN_HEIGHT 480

static void stream_dump(const uint8_t *data, unsigned length);

static void set_geometry(unsigned x, unsigned y, unsigned width, unsigned height);

static void update_vertices();

static void shader_activate_simple(unsigned *aPosition, unsigned *uColor);

#define VERTEX_BUFFER_STRIDE 4
#define SET_VERTEX(y, x, value) vertices[(y) *VERTEX_BUFFER_STRIDE + (x)] = value
static GLfloat vertices[6 * VERTEX_BUFFER_STRIDE];
static GLuint vertex_buffer;
static float coord_x[4], coord_y[4];
static GLuint shader;
static unsigned aPosition, uColor;

static void opengl_render(const uint8_t* data, unsigned length) {
    unsigned pos;
    for (pos = 0; pos < length;) {
        if (data[pos] & 0x80)
            break;

        unsigned x = ((unsigned) data[pos + 1]) | (((unsigned) data[pos + 2]) << 8);
        unsigned y = ((unsigned) data[pos + 3]) | (((unsigned) data[pos + 4]) << 8);
        unsigned w = ((unsigned) data[pos + 5]) | (((unsigned) data[pos + 6]) << 8);
        unsigned h = ((unsigned) data[pos + 7]) | (((unsigned) data[pos + 8]) << 8);
        set_geometry(x, y, w, h);

        // select rendering program
        shader_activate_simple(NULL, NULL);

        // set color
        uint16_t color = ((uint16_t) data[pos + 9]) | (((uint16_t) data[pos + 10]) << 8);
        float red = ((float) (color & 0x1f)) / 31.f;
        float green = ((float) ((color >> 5) & 0x1f)) / 31.f;
        float blue = ((float) ((color >> 10) & 0x1f)) / 31.f;
        float alpha = ((float) data[pos + 11]) / 15.f;
        glUniform4f(uColor, red, green, blue, alpha);
        // set vertices
        glBindBuffer(GL_ARRAY_BUFFER, vertex_buffer);
        glVertexAttribPointer(aPosition, 2, GL_FLOAT, GL_FALSE,
                              VERTEX_BUFFER_STRIDE * sizeof(float), (GLvoid *) 0);
        glEnableVertexAttribArray(aPosition);

        // render
        glDrawArrays(GL_TRIANGLES, 0, 6);


        pos += 12;
    }
}

bool vc_cmd_execute(const uint8_t *data, unsigned length) {
    if(length==1 && data[0]==0x80)
        return true;

//    stream_dump(data, length);

    opengl_render(data, length);
    window_swap_buffers();

    return true;
}

void stream_dump(const uint8_t *data, unsigned length) {
    unsigned pos;
    printf("=== Start of list ===\n");
    for (pos = 0; pos < length;) {
        if (data[pos] & 0x80) {
            printf("=== End of list ===\n");
            break;
        }
        printf("Rectangle: x=%d, y=%d, w=%d, h=%d\n",
               ((unsigned) data[pos + 1]) | (((unsigned) data[pos + 2]) << 8),
               ((unsigned) data[pos + 3]) | (((unsigned) data[pos + 4]) << 8),
               ((unsigned) data[pos + 5]) | (((unsigned) data[pos + 6]) << 8),
               ((unsigned) data[pos + 7]) | (((unsigned) data[pos + 8]) << 8));
        uint16_t color = ((uint16_t) data[pos + 9]) | (((uint16_t) data[pos + 10]) << 8);
        printf("  r=%0.3f, g=%0.3f, b=%0.3f, a=%0.3f\n",
               ((float) (color & 0x1f)) / 31.f,
               ((float) ((color >> 5) & 0x1f)) / 31.f,
               ((float) ((color >> 10) & 0x1f)) / 31.f,
               ((float) data[pos + 11]) / 15.f);

        pos += 12;
    }
}


static void set_geometry(unsigned x, unsigned y, unsigned width, unsigned height) {
    coord_x[0] = (float) x;
    coord_x[1] = (float) (x + width);
    coord_x[2] = (float) x;
    coord_x[3] = (float) (x + width);
    coord_y[0] = (float) y;
    coord_y[1] = (float) y;
    coord_y[2] = (float) (y + height);
    coord_y[3] = (float) (y + height);
    update_vertices();

    glBindBuffer(GL_ARRAY_BUFFER, vertex_buffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(float) * 6 * VERTEX_BUFFER_STRIDE,
                 vertices, GL_DYNAMIC_DRAW);
}

static void update_vertices() {
    // clip position to screen
    GLfloat x[4], y[4];
    int i;

    for (i = 0; i < 4; i++) {
        x[i] = (((GLfloat) coord_x[i] * 2) / (GLfloat) SCREEN_WIDTH) - (GLfloat) 1.0f;
        y[i] = ((((GLfloat) SCREEN_HEIGHT - (GLfloat) coord_y[i]) * 2) / (GLfloat) SCREEN_HEIGHT) - (GLfloat) 1.0f;
        if (x[i] < -1.0f || x[i] > 1.0f || y[i] < -1.0f || y[i] > 1.0f) {
            return;
        }
    }

    SET_VERTEX(0, 0, x[0]);
    SET_VERTEX(0, 1, y[0]);
    SET_VERTEX(1, 0, x[1]);
    SET_VERTEX(1, 1, y[1]);
    SET_VERTEX(2, 0, x[2]);
    SET_VERTEX(2, 1, y[2]);

    SET_VERTEX(3, 0, x[1]);
    SET_VERTEX(3, 1, y[1]);
    SET_VERTEX(4, 0, x[2]);
    SET_VERTEX(4, 1, y[2]);
    SET_VERTEX(5, 0, x[3]);
    SET_VERTEX(5, 1, y[3]);
}

#define SIMPLE_SHADER_VERTEX \
"attribute vec2 aPosition;    \n" \
"void main()                  \n" \
"{                            \n" \
"   gl_Position = vec4(aPosition.x, aPosition.y, 0.0, 1.0);  \n" \
"}                            \n"

#define SIMPLE_SHADER_FRAGMENT \
"precision mediump float;\n" \
"uniform vec4 uColor;\n" \
"void main()                                  \n" \
"{                                            \n" \
"  gl_FragColor = uColor;\n" \
"}                                            \n"


static unsigned loadShader(GLenum type, const char *shaderSrc) {
    GLuint shader;
    GLint compiled;

    // Create the shader object
    shader = glCreateShader(type);

    if (shader == 0)
        return 0;

    // Load the shader source
    glShaderSource(shader, 1, &shaderSrc, NULL);

    // Compile the shader
    glCompileShader(shader);

    // Check the compile status
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);

    if (!compiled) {
        GLint infoLen = 0;

        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &infoLen);

        if (infoLen > 1) {
            char *infoLog = (char *) malloc(sizeof(char) * infoLen);

            glGetShaderInfoLog(shader, infoLen, NULL, infoLog);
            fprintf(stderr, "Error compiling shader:\n%s\n", infoLog);
            free(infoLog);
            exit(2);
        }

        glDeleteShader(shader);
//        std::cout << "Unable to initialize GLES (loading shader)" << std::endl;
        exit(2);
    }

    return shader;

}


static void loadShaders(const char *fragmentCode, const char *vertexCode,
                        unsigned *program_id) {
    GLuint vertexShader;
    GLuint fragmentShader;
    GLint linked;
    vertexShader = loadShader(GL_VERTEX_SHADER, vertexCode);
    fragmentShader = loadShader(GL_FRAGMENT_SHADER, fragmentCode);

    // Create the program object
    *program_id = glCreateProgram();

    if (*program_id == 0) {
        //        std::cout << "Unable to initialize GLES (create shader)" << std::endl;
        exit(2);
    }

    glAttachShader(*program_id, vertexShader);
    glAttachShader(*program_id, fragmentShader);

    // Link the program
    glLinkProgram(*program_id);

    // Check the link status
    glGetProgramiv(*program_id, GL_LINK_STATUS, &linked);

    if (!linked) {
        GLint infoLen = 0;

        glGetProgramiv(*program_id, GL_INFO_LOG_LENGTH, &infoLen);

        if (infoLen > 1) {
            char *infoLog = (char *) malloc(sizeof(char) * infoLen);

            glGetProgramInfoLog(*program_id, infoLen, NULL, infoLog);
            fprintf(stderr, "Error linking program:\n%s\n", infoLog);

            free(infoLog);
            exit(2);
        }

        glDeleteProgram(*program_id);
        //        std::cout << "Unable to initialize GLES (linking shader)" << std::endl;
        exit(2);
    }
}

static void shader_activate_simple(unsigned *aPosition,
                                   unsigned *uColor) {
    glUseProgram(shader);
    if (aPosition)
        *aPosition = glGetAttribLocation(shader, "aPosition");
    if (uColor)
        *uColor = glGetUniformLocation(shader, "uColor");
}

void opengl_init() {
    glGenBuffers(1, &vertex_buffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertex_buffer);
    loadShaders(SIMPLE_SHADER_FRAGMENT, SIMPLE_SHADER_VERTEX, &shader);
    shader_activate_simple(&aPosition, &uColor);
}

static bool active_buffer=true;
static tTime swap_buffers=0;
int renderer_display_ready() {
    tTime now=TIME_GET;
    if(now<swap_buffers)
        return -1;
    swap_buffers=now+100;

    active_buffer=!active_buffer;
    return active_buffer?1:0;
}