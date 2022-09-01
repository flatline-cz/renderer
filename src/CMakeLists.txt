

set(RENDERER_INCLUDES
        ${CMAKE_CURRENT_LIST_DIR}/../include/
        ${CMAKE_CURRENT_LIST_DIR}/../scripting/
        ${CMAKE_CURRENT_LIST_DIR}/../renderer/
        ${CMAKE_CURRENT_LIST_DIR}
        ${ZFORTH_INCLUDES}
        ${RENDERER_IMPL_INCLUDES}
        ${DASHBOARD_LIB_INCLUDES}
        )

set(RENDERER_SOURCES
        ${CMAKE_CURRENT_LIST_DIR}/../renderer/renderer-display.c
        ${CMAKE_CURRENT_LIST_DIR}/../renderer/renderer-scene.c
        ${CMAKE_CURRENT_LIST_DIR}/../scripting/scripting.c
        ${CMAKE_CURRENT_LIST_DIR}/../scripting/library.c
        ${ZFORTH_SOURCES}
        ${RENDERER_IMPL_SOURCES}
        ${DASHBOARD_LIB_SOURCES}
        )