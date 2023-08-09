
set(RENDERER_SOURCES
        ${CMAKE_CURRENT_LIST_DIR}/src/renderer-display.c
        ${CMAKE_CURRENT_LIST_DIR}/src/renderer-scene.c
        ${CMAKE_CURRENT_LIST_DIR}/binding/binding-idle.c
        ${CMAKE_CURRENT_LIST_DIR}/binding/binding-gpio.c
        ${CMAKE_CURRENT_LIST_DIR}/binding/binding-canbus.c
        ${CMAKE_CURRENT_LIST_DIR}/binding/binding-canbus-register.c
        ${CMAKE_CURRENT_LIST_DIR}/src/renderer.c
        ${CMAKE_CURRENT_LIST_DIR}/src/video-core/video-core.c
        ${CMAKE_CURRENT_LIST_DIR}/src/video-core/fpga-bit-stream.c
        ${CMAKE_CURRENT_LIST_DIR}/src/scene-decoder/decoder.c
        )

if (DEFINED PIC32)
        list(APPEND RENDERER_SOURCES
                ${CMAKE_CURRENT_LIST_DIR}/src/video-core/video-core-hw-pic32.c
        )
else ()
        list(APPEND RENDERER_SOURCES
                ${CMAKE_CURRENT_LIST_DIR}/src/video-core/video-core-hw-linux.c
        )
endif ()

set(RENDERER_INCLUDES
        ${CMAKE_CURRENT_LIST_DIR}/include
        )

#include(${CMAKE_CURRENT_LIST_DIR}/binding/wasm/CMakeLists.txt)