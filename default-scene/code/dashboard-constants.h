#ifndef __RENDER_CONSTANTS__
#define __RENDER_CONSTANTS__

typedef enum tagRendererColor {
   RENDER_COLOR_black = 0,
   RENDER_COLOR_white = 1,
   RENDER_COLOR_transparent = 2,
   RENDER_COLOR_signRed = 3,
   RENDER_COLOR_signOrange = 4,
   RENDER_COLOR_signGreen = 5,
   RENDER_COLOR_signBlue = 6,
   RENDER_COLOR_signGray = 7,
} eRendererColor;

typedef enum tagRendererTile {
    RENDER_TILE_Frame = 1,
    RENDER_TILE_Background = 2,
} eRendererTile;

typedef enum tagRendererScreen {
    RENDER_SCREEN_Default = 0,
} eRendererScreen;

typedef enum tagRendererText {
    RENDER_InvalidTextHandle = 0xffff
} eRendererText;


#endif
