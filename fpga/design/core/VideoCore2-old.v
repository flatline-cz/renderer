

module VideoCore2 (
        // clocks
        i_master_clk,
        i_pixel_clk,

        // UART interface
        i_uart_rx, 
        o_uart_tx,

        // VIDEO OUTPUT interface
        o_video_hsync,
        o_video_vsync,
        o_video_red,
        o_video_green,
        o_video_blue,

        // SRAM interface
        o_sram_address,
        o_sram_data_out,
        o_sram_data_dir_out,
        i_sram_data_in,
        o_sram_cs_n,
        o_sram_oe_n,
        o_sram_we_n,

        // DEBUG interface
        LED
    );

    input           i_master_clk;
    input           i_pixel_clk;

    input           i_uart_rx;
    output          o_uart_tx;

    output          o_video_vsync;
    output          o_video_hsync;
    output[3:0]     o_video_red;
    output[3:0]     o_video_green;
    output[3:0]     o_video_blue;

    output[19:0]    o_sram_address;
    output[23:0]    o_sram_data_out;
    output          o_sram_data_dir_out;
    input[23:0]     i_sram_data_in;
    output          o_sram_cs_n;
    output          o_sram_oe_n;
    output          o_sram_we_n;

    output[6:0]     LED;


    parameter PIXEL_FREQ = 12000000;
    parameter MASTER_FREQ = 50350000;
    parameter BOUD_RATE = 500000;


    // ***********************************************
    // **                                           **
    // **   MCU INTERFACE                           **
    // **                                           **
    // ***********************************************

    wire w_mcu_queue_finished;

    MCUController #(
            .CLOCK_FREQ(MASTER_FREQ),
            .BOUD_RATE(BOUD_RATE)
        ) mcu_controller (
            .i_master_clk(i_master_clk),

            .i_uart_rx(i_uart_rx),
            .o_uart_tx(o_uart_tx),

            .i_status_vsync(w_status_vsync),
            .i_status_interrupt(w_status_interrupt),
            .i_status_data(w_status_data),
            .o_status_request(w_status_request),

            .o_system_mode(w_set_rendering_mode),
            .o_system_mode_valid(w_set_rendering_mode_valid)
        );


    // ***********************************************
    // **                                           **
    // **   STATUS CONTROLLER                       **
    // **                                           **
    // ***********************************************

    wire        w_status_vsync;
    wire        w_status_interrupt;
    wire[7:0]   w_status_data;
    wire        w_status_request;

    wire        w_mcu_queue_locked;

    StatusController status_controller (
            .i_master_clk(i_master_clk),

            .i_video_vsync_n(w_video_vsync),

            .i_status_request(w_status_request),
            .o_status_data(w_status_data),

            .o_event_interrupt(w_status_interrupt),
            .o_event_vsync(w_status_vsync),

            .i_system_rendering_mode(w_system_rendering_mode),

            .i_flash_operation_done(1'b0),  // TODO
            .i_flash_operation_failed(1'b0), // TODO
            
            .i_video_descriptor_ready(1'b0), // TODO

            .i_buffer_locked(w_mcu_queue_locked)



        );

    assign LED[0] = w_status_vsync;
    assign LED[1] = w_status_interrupt;

    // ***********************************************
    // **                                           **
    // **   SYSTEM CONTROLLER                       **
    // **                                           **
    // ***********************************************

    wire[1:0]   w_system_rendering_mode;
    wire[1:0]   w_set_rendering_mode;
    wire        w_set_rendering_mode_valid;

    wire        w_system_video_enabled;
    wire        w_system_video_switch_allowed;

    SystemController system_controller (
            .i_master_clk(i_master_clk),

            .o_status_rendering_mode(w_system_rendering_mode),

            .i_mcu_mode(w_set_rendering_mode),
            .i_mcu_mode_valid(w_set_rendering_mode_valid),

            .o_video_enable(w_system_video_enabled),
            .i_video_switch_allowed(w_system_video_switch_allowed)
        );

    assign LED[3:2] = w_system_rendering_mode;


    // ***********************************************
    // **                                           **
    // **   VIDEO TIMING CONTROLLER                 **
    // **                                           **
    // ***********************************************

    wire w_video_vsync;
    wire w_video_hsync;

    VideoTimingController video_controller (
            // clocks
            .i_pixel_clk(i_pixel_clk),
            .i_master_clk(i_master_clk),

            .o_video_vsync(w_video_vsync),
            .o_video_hsync(w_video_hsync),

            .i_system_enabled(w_system_video_enabled),
            .o_system_switch_allowed(w_system_video_switch_allowed)
        );

    assign o_video_vsync = w_video_vsync;
    assign o_video_hsync = w_video_hsync;

    // ***********************************************
    // **                                           **
    // **   VIDEO DATA CONTROLLER                   **
    // **                                           **
    // ***********************************************

    assign o_video_red = 4'h0;
    assign o_video_green = 4'h0;
    assign o_video_blue = 4'h0;

    // ***********************************************
    // **                                           **
    // **   BUFFER CONTROLLER                       **
    // **                                           **
    // ***********************************************

    wire w_display_bank;
    wire w_render_bank;
    wire w_render_start;
    wire w_render_finished;
    

    BufferController buffer_controller (
            .i_master_clk(i_master_clk),

            .i_system_rendering_mode(w_system_rendering_mode),

            .i_video_switch_allowed(w_system_video_switch_allowed),
            .o_video_bank(w_display_bank),

            .o_render_bank(w_render_bank),

            .o_mcu_queue_locked(w_mcu_queue_locked)

        );


    // ***********************************************
    // **                                           **
    // **   RENDERING ENGINE                        **
    // **                                           **
    // ***********************************************

    // connection between RENDER CONTROLLER & VRAM CONTROLLER
    wire[19:0]  w_vram_render_read_address; 
    wire        w_vram_render_read_request;
    wire[23:0]  w_vram_render_read_data;
    wire        w_vram_render_read_data_valid;
    wire[19:0]  w_vram_render_write_address;
    wire        w_vram_render_write_request;
    wire[23:0]  w_vram_render_write_data;
    wire        w_vram_render_write_done;

    wire        w_rendering;

    RenderingController render_controller (
            .i_master_clk(i_master_clk),

            .i_process_start(w_render_start),
            .i_process_bank(w_render_bank),
            .o_process_done(w_render_finished),

            // .i_queue_start(w_mcu_data_start),
            // .i_queue_data(w_mcu_data),
            // .i_queue_data_valid(w_mcu_data_valid),

            .o_vram_read_address(w_vram_render_read_address),
            .o_vram_read_request(w_vram_render_read_request),
            .i_vram_read_data(w_vram_render_read_data),
            .i_vram_read_data_valid(w_vram_render_read_data_valid),
            .o_vram_write_address(w_vram_render_write_address),
            .o_vram_write_request(w_vram_render_write_request),
            .o_vram_write_data(w_vram_render_write_data),
            .i_vram_write_done(w_vram_render_write_done),

            .o_flash_read_address(w_flash_render_address),
            .o_flash_read_request(w_flash_render_request),
            .i_flash_read_data(w_flash_render_data),
            .i_flash_read_data_valid(w_flash_render_data_valid),

            .dbg_rendering(w_rendering)

        );        

    // ***********************************************
    // **                                           **
    // **   NAND FLASH CONTROLLER                   **
    // **                                           **
    // ***********************************************

    // Connection between FLASH CONTROLLER & RENDERING CONTROLLER
    wire[31:0]      w_flash_render_address;
    wire            w_flash_render_request;
    wire[15:0]      w_flash_render_data;
    wire            w_flash_render_data_valid;

    FLASHController flash_controller (
            .i_master_clk(i_master_clk),

            .i_flash_read_address(w_flash_render_address),
            .i_flash_read_request(w_flash_render_request),
            .o_flash_read_data(w_flash_render_data),
            .o_flash_read_data_valid(w_flash_render_data_valid)

        );


    // ***********************************************
    // **                                           **
    // **   FRAMEBUFFER CONTROLLER                  **
    // **                                           **
    // ***********************************************

    VRAMController vram_controller (
            .i_master_clk(i_master_clk),

            .o_sram_addr(o_sram_address),
            .o_sram_data_out(o_sram_data_out),
            .o_sram_data_dir_out(o_sram_data_dir_out),
            .i_sram_data_in(i_sram_data_in),
            .o_sram_oe_n(o_sram_oe_n),
            .o_sram_we_n(o_sram_we_n),
            .o_sram_cs_n(o_sram_cs_n),

            // .i_display_address(w_vram_display_address),
            // .i_display_start(w_vram_display_start),
            // .o_display_column(w_vram_display_column),
            // .o_display_data(w_vram_display_data),
            // .o_display_data_valid(w_vram_display_data_valid),

            .i_render_read_address(w_vram_render_read_address),
            .i_render_read_request(w_vram_render_read_request),
            .o_render_read_data(w_vram_render_read_data),
            .o_render_read_data_valid(w_vram_render_read_data_valid),

            .i_render_write_address(w_vram_render_write_address),
            .i_render_write_data(w_vram_render_write_data),
            .i_render_write_request(w_vram_render_write_request),
            .o_render_write_done(w_vram_render_write_done)
        );

    


endmodule
