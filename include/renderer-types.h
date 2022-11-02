//
// Created by tumap on 10/13/22.
//

#ifndef RENDERER_TEST_RENDERER_TYPES_H
#define RENDERER_TEST_RENDERER_TYPES_H

#include <stdint.h>

typedef uint16_t tRendererPosition;

#define RENDERER_NULL_HANDLE                      0xffff
typedef uint16_t tRendererTileHandle;

typedef uint16_t tRendererScreenHandle;

typedef uint16_t tRendererVideoHandle;

typedef struct tRendererColor {
    unsigned red: 8;
    unsigned green: 8;
    unsigned blue: 8;
    unsigned alpha: 8;
} tRendererColor;


#endif //RENDERER_TEST_RENDERER_TYPES_H
