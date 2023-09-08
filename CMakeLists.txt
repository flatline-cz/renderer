


set(RENDERER_SOURCES
        ${CMAKE_CURRENT_LIST_DIR}/src/renderer-display.c
        ${CMAKE_CURRENT_LIST_DIR}/src/renderer-scene.c
        ${CMAKE_CURRENT_LIST_DIR}/binding/binding-idle.c
        ${CMAKE_CURRENT_LIST_DIR}/binding/binding-gpio.c
        ${CMAKE_CURRENT_LIST_DIR}/binding/binding-canbus.c
        ${CMAKE_CURRENT_LIST_DIR}/binding/binding-canbus-register.c
        ${CMAKE_CURRENT_LIST_DIR}/src/video-core/video-core.c
        ${CMAKE_CURRENT_LIST_DIR}/src/video-core/data-upload.c
        ${CMAKE_CURRENT_LIST_DIR}/src/scene-decoder/scene-decoder.c
        ${CMAKE_CURRENT_LIST_DIR}/default-scene/code/scene-default.c
        ${CMAKE_CURRENT_LIST_DIR}/default-scene/code/dashboard-definition.c
        ${CMAKE_BINARY_DIR}/fpga-bit-stream.c
)

set(FPGA_SOURCES
        ${CMAKE_CURRENT_LIST_DIR}/fpga/design/clock/Clock-65_25.v
        ${CMAKE_CURRENT_LIST_DIR}/fpga/design/clock/Clock-50_35.v
        ${CMAKE_CURRENT_LIST_DIR}/fpga/design/core/VideoCore.v
        ${CMAKE_CURRENT_LIST_DIR}/fpga/design/video/VideoRowBuffer.v
        ${CMAKE_CURRENT_LIST_DIR}/fpga/design/video/PlaybackController.v
        ${CMAKE_CURRENT_LIST_DIR}/fpga/design/video/VideoDecoder2.v
        ${CMAKE_CURRENT_LIST_DIR}/fpga/design/system/SPIController.v
        ${CMAKE_CURRENT_LIST_DIR}/fpga/design/system/DeviceController.v
        ${CMAKE_CURRENT_LIST_DIR}/fpga/design/system/StatusController.v
        ${CMAKE_CURRENT_LIST_DIR}/fpga/design/system/SystemController.v
        ${CMAKE_CURRENT_LIST_DIR}/fpga/design/system/BufferController.v
        ${CMAKE_CURRENT_LIST_DIR}/fpga/design/system/QueueController.v
        ${CMAKE_CURRENT_LIST_DIR}/fpga/design/system/StorageController.v
        ${CMAKE_CURRENT_LIST_DIR}/fpga/design/system/FIFO.v
        ${CMAKE_CURRENT_LIST_DIR}/fpga/design/memory/VRAMController.v
        ${CMAKE_CURRENT_LIST_DIR}/fpga/design/renderer/CommandProcessor.v
        ${CMAKE_CURRENT_LIST_DIR}/fpga/design/renderer/Renderer.v
        ${CMAKE_CURRENT_LIST_DIR}/fpga/design/renderer/RendererMixer.v
        ${CMAKE_CURRENT_LIST_DIR}/fpga/design/renderer/RendererRectFill.v
        ${CMAKE_CURRENT_LIST_DIR}/fpga/design/renderer/RendererRectMix.v
        ${CMAKE_CURRENT_LIST_DIR}/fpga/design/renderer/RendererTextureMix.v
)


if (DEFINED PIC32)
    # C sources
    list(APPEND RENDERER_SOURCES
            ${CMAKE_CURRENT_LIST_DIR}/src/video-core/video-core-hw-pic32.c
    )
    # FPGA properties
    set(FPGA_PCF_FILE ${CMAKE_CURRENT_LIST_DIR}/fpga/design/constraints/Final.pcf)
    set(FPGA_CHIP "hx4k")
    set(FPGA_PACKAGE "tq144")
    list(APPEND FPGA_SOURCES
            ${CMAKE_CURRENT_LIST_DIR}/fpga/design/core/Final.v
            ${CMAKE_CURRENT_LIST_DIR}/fpga/design/clock/Clock-51_00.v
            ${CMAKE_CURRENT_LIST_DIR}/fpga/design/video/VideoTimingControllerTFT.v
    )
else ()
    # C sources
    list(APPEND RENDERER_SOURCES
            ${CMAKE_CURRENT_LIST_DIR}/src/video-core/video-core-hw-linux.c
    )
    # FPGA properties
    set(FPGA_PCF_FILE ${CMAKE_CURRENT_LIST_DIR}/fpga/design/constraints/Prototype2.pcf)
    set(FPGA_CHIP "hx8k")
    set(FPGA_PACKAGE "ct256")
    list(APPEND FPGA_SOURCES
            ${CMAKE_CURRENT_LIST_DIR}/fpga/design/core/Prototype2.v
            ${CMAKE_CURRENT_LIST_DIR}/fpga/design/video/VideoTimingControllerVGA.v
    )
endif ()

set(RENDERER_INCLUDES
        ${CMAKE_CURRENT_LIST_DIR}/include
)

# synthesize FPGA design
add_custom_command(
        OUTPUT ${CMAKE_BINARY_DIR}/fpga.json
        DEPENDS ${FPGA_SOURCES}
        COMMENT "Synthesizing FPGA design"
        BYPRODUCTS ${CMAKE_BINARY_DIR}/fpga-synth.lst
        COMMAND yosys
        ARGS -l ${CMAKE_BINARY_DIR}/fpga-synth.lst
        -q
        -p "synth_ice40 -top FPGA -json ${CMAKE_BINARY_DIR}/fpga.json "
        ${FPGA_SOURCES}
)

# place&route FPGA design
add_custom_command(
        OUTPUT ${CMAKE_BINARY_DIR}/fpga.asc
        DEPENDS ${CMAKE_BINARY_DIR}/fpga.json ${FPGA_PCF_FILE}
        COMMENT "Mapping FGPA design"
        BYPRODUCTS ${CMAKE_BINARY_DIR}/fpga-map.lst
        COMMAND nextpnr-ice40
        ARGS -l ${CMAKE_BINARY_DIR}/fpga-map.lst
        -q
        --${FPGA_CHIP}
        --package ${FPGA_PACKAGE}
        --json ${CMAKE_BINARY_DIR}/fpga.json
        --pcf ${FPGA_PCF_FILE}
        --asc ${CMAKE_BINARY_DIR}/fpga.asc
)

# pack FPGA bit-stream
add_custom_command(
        OUTPUT ${CMAKE_BINARY_DIR}/fpga.bin
        DEPENDS ${CMAKE_BINARY_DIR}/fpga.asc
        COMMENT "Packing FPGA bit-stream"
        COMMAND icepack
        ARGS ${CMAKE_BINARY_DIR}/fpga.asc ${CMAKE_BINARY_DIR}/fpga.bin
)

# generate C code from binary FPGA bit-stream
add_custom_command(
        OUTPUT ${CMAKE_BINARY_DIR}/fpga-bit-stream.c
        DEPENDS ${CMAKE_BINARY_DIR}/fpga.bin
        COMMENT "Generating C code for FPGA bit-stream"
        COMMAND xxd -i -n "FPGA_bit_stream" ${CMAKE_BINARY_DIR}/fpga.bin | sed 's/unsigned/const unsigned/;' > ${CMAKE_BINARY_DIR}/fpga-bit-stream.c
)

