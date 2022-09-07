cmake_minimum_required(VERSION 3.23)
project(renderer C)

set(CMAKE_C_STANDARD 99)

include(common/CMakeLists.txt)

set(ZFORTH_SOURCES
        forth/src/zforth/zforth.c
        )

set(ZFORTH_INCLUDES
        forth/src/zforth/
        )

include(test/impl/CMakeLists.txt)
include(src/CMakeLists.txt)


include(test/CMakeLists.txt)


#add_executable(renderer
#        test/main.c
#        src/renderer-scene.c
#        ${RENDERER_IMPL_SOURCES}
#        ${VIDEOCORE_SOURCES}
#        )
#
#target_include_directories(renderer PRIVATE
#        include
#        ${RENDERER_IMPL_INCLUDES}
#        )
