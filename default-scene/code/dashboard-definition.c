#include <stdint.h>

const uint8_t renderer_data[] = {
    // - Magic constant
    0xef, 0xbe, 0xad, 0xde, 
    // - Scene definition length
    0x76, 0x00, 0x00, 0x00, 
    // Number of simple colors
    0x08, 0x00, 
    // Simple color: black
    0x0f, 0x00, 
    // Simple color: white
    0xff, 0xff, 
    // Simple color: transparent
    0x00, 0x00, 
    // Simple color: signRed
    0x0f, 0xf0, 
    // Simple color: signOrange
    0x3f, 0xff, 
    // Simple color: signGreen
    0x5f, 0x2b, 
    // Simple color: signBlue
    0xdf, 0x00, 
    // Simple color: signGray
    0x8f, 0x88, 

    // Number of tiles
    0x03, 0x00, 
    // Tile: Default
    // - Root tile
    0x00, 0x00, 
    // - Parent tile
    0xff, 0xff, 
    // - Children count
    0x01, 0x00, 
    // - Children index offset
    0x00, 0x00, 
    // - Position X
    0x00, 0x00, 
    // - Position Y
    0x00, 0x00, 
    // - Width
    0x00, 0x04, 
    // - Height
    0x58, 0x02, 
    // - Visible
    0x01, 
    // - Color
    0x00, 0x00, 
    // - Type
    0x00, 
    // Tile: Frame
    // - Root tile
    0x00, 0x00, 
    // - Parent tile
    0x00, 0x00, 
    // - Children count
    0x01, 0x00, 
    // - Children index offset
    0x01, 0x00, 
    // - Position X
    0xd4, 0x00, 
    // - Position Y
    0xc8, 0x00, 
    // - Width
    0x58, 0x02, 
    // - Height
    0xc8, 0x00, 
    // - Visible
    0x01, 
    // - Color
    0x01, 0x00, 
    // - Type
    0x00, 
    // Tile: Background
    // - Root tile
    0x00, 0x00, 
    // - Parent tile
    0x01, 0x00, 
    // - Children count
    0x00, 0x00, 
    // - Children index offset
    0x02, 0x00, 
    // - Position X
    0xd9, 0x00, 
    // - Position Y
    0xcd, 0x00, 
    // - Width
    0x4e, 0x02, 
    // - Height
    0xbe, 0x00, 
    // - Visible
    0x01, 
    // - Color
    0x00, 0x00, 
    // - Type
    0x00, 

    // Number of screens
    0x01, 0x00, 
    // Screen: Default
    0x00, 0x00, 
    // - Graphics
    0x00, 0x00, 

    // Child nodes index - Size
    0x02, 0x00, 
    // - - Child: Frame
    0x01, 0x00, 
    // - - Child: Background
    0x02, 0x00, 

    // - Number of font glyphs
    0x00, 0x00, 

    // - Number of fonts
    0x00, 0x00, 

    // - Length of all texts
    0x00, 0x00, 
    // - Number of text items
    0x00, 0x00, 

    // - Number of texture bundles
    0x01, 0x00, 
    // - Texture bundle #0
    // - Position
    0x00, 0x00, 0x00, 0x00, 
    // - Size
    0x00, 0x00, 0x00, 0x00, 

    // - End of scene definition

};
const unsigned renderer_data_length = sizeof(renderer_data);

