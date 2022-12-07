
set(EGL_TEST_INCLUDES
        ${CMAKE_CURRENT_LIST_DIR}
        ${CMAKE_CURRENT_LIST_DIR}/egl/
        )

set(EGL_TEST_SOURCES
        ${CMAKE_CURRENT_LIST_DIR}/egl/main.c
        ../src/opengl/window.c
        ../src/opengl/opengl.c)

add_executable(renderer-egl
        ${EGL_TEST_SOURCES}
        ${RENDERER_SOURCES}
        )

target_include_directories(renderer-egl PRIVATE
        ${EGL_TEST_INCLUDES}
        ${RENDERER_INCLUDES}
        )

target_link_libraries(renderer-egl PRIVATE
        GLESv2
        glfw)


set(VC_TEST_INCLUDES
        ${CMAKE_CURRENT_LIST_DIR}
        ${CMAKE_CURRENT_LIST_DIR}/vc/
        )

set(VC_TEST_SOURCES
        ${CMAKE_CURRENT_LIST_DIR}/vc/main.c
        ${CMAKE_CURRENT_LIST_DIR}/vc/serial.c
        )

add_executable(renderer-vc
        ${VC_TEST_SOURCES}
        ${RENDERER_SOURCES}
        )

target_include_directories(renderer-vc PRIVATE
        ${VC_TEST_INCLUDES}
        ${RENDERER_INCLUDES}
        )

