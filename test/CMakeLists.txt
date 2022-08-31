
set(TEST_INCLUDES
        ${CMAKE_CURRENT_LIST_DIR}
        ${CMAKE_CURRENT_LIST_DIR}/egl/
        )

set(TEST_SOURCES
        ${CMAKE_CURRENT_LIST_DIR}/main.c
        ${CMAKE_CURRENT_LIST_DIR}/egl/window.c
        ${CMAKE_CURRENT_LIST_DIR}/egl/opengl.c)

add_executable(renderer-test
        ${TEST_SOURCES}
        ${RENDERER_SOURCES}
        )

target_include_directories(renderer-test PRIVATE
        ${TEST_INCLUDES}
        ${RENDERER_INCLUDES}
        )

target_link_libraries(renderer-test PRIVATE
        GLESv2
        glfw)