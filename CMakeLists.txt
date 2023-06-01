
set(RENDERER_SOURCES
        ${CMAKE_CURRENT_LIST_DIR}/src/renderer-display.c
        ${CMAKE_CURRENT_LIST_DIR}/src/renderer-scene.c
        ${CMAKE_CURRENT_LIST_DIR}/src/renderer-idle.c
        ${CMAKE_CURRENT_LIST_DIR}/src/renderer.c
        ${CMAKE_CURRENT_LIST_DIR}/src/video-core/video-core.c
        )

set(RENDERER_INCLUDES
        ${CMAKE_CURRENT_LIST_DIR}/include
        )

#include(${CMAKE_CURRENT_LIST_DIR}/binding/wasm/CMakeLists.txt)