
module VideoCore (
        // pixel clock domain
        i_pixel_clk,

        // master clock domain
        i_master_clk,

        // UART interface
        i_uart_rx,
        o_uart_tx,

        // Video out interface
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
        dbg_rendering

    );

    parameter MASTER_FREQ = 50350000;


    input           i_pixel_clk;
    input           i_master_clk;

    input           i_uart_rx;
    output          o_uart_tx;

    output          o_video_hsync;
    output          o_video_vsync;
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

    output          dbg_rendering;


    // ***********************************************
    // **                                           **
    // **   VIDEO CONTROLLER                        **
    // **                                           **
    // ***********************************************

    // connection between VIDEO CONTROLLER & VRAM CONTROLLER
    wire[19:0]      w_vram_display_address;
    wire            w_vram_display_start;
    wire[8:0]       w_vram_display_column;
    wire[23:0]      w_vram_display_data;
    wire            w_vram_display_data_valid;

    // controller submodule
    VideoController video_controller (
            // pixel clock
            .i_pixel_clk(i_pixel_clk),

            // master clock
            .i_master_clk(i_master_clk),

            // SYSTEM CONTROLLER interface
            .i_system_bank(w_system_display_bank),
            .o_system_switch_allowed(w_system_switch_allowed),

            // VIDEO interface
            .o_video_hsync(o_video_hsync),
            .o_video_vsync(o_video_vsync),
            .o_video_red(o_video_red),
            .o_video_green(o_video_green),
            .o_video_blue(o_video_blue),

            // VRAM CONTROLLER interface
            .o_vram_display_address(w_vram_display_address),
            .o_vram_display_start(w_vram_display_start),
            .i_vram_display_column(w_vram_display_column),
            .i_vram_display_data(w_vram_display_data),
            .i_vram_display_data_valid(w_vram_display_data_valid)

        );

    // ***********************************************
    // **                                           **
    // **   RENDER CONTROLLER                       **
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

    assign      dbg_rendering = w_rendering;

    RenderingController render_controller (
            .i_master_clk(i_master_clk),

            .i_process_start(w_system_render_start),
            .i_process_bank(w_system_render_bank),
            .o_process_done(w_system_render_finished),

            .i_queue_start(w_mcu_data_start),
            .i_queue_data(w_mcu_data),
            .i_queue_data_valid(w_mcu_data_valid),

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
    // **   UART CONTROLLER                         **
    // **                                           **
    // ***********************************************

    wire[7:0] w_status = { 6'b001100, !w_system_queue_locked, 1'b0 };

    wire[7:0]   w_mcu_data;
    wire        w_mcu_data_start;
    wire        w_mcu_data_valid;
    wire        w_mcu_data_end;

    UART #(
            .CLOCK_FREQ(MASTER_FREQ)
        ) uart (
            .clk(i_master_clk),

            .rxd(i_uart_rx),
            .data_in(w_mcu_data),
            .data_in_valid(w_mcu_data_valid),
            .data_in_start(w_mcu_data_start),
            .data_in_end(w_mcu_data_end),

            .o_txd(o_uart_tx),
            .i_tx_byte(w_status)
        );        

    // ***********************************************
    // **                                           **
    // **   SYSTEM CONTROLLER                       **
    // **                                           **
    // ***********************************************

    wire w_system_display_bank;
    wire w_system_switch_allowed;
    wire w_system_render_bank;
    wire w_system_render_start;
    wire w_system_render_finished;
    wire w_system_queue_locked;

    SystemController system_controller (
            .i_master_clk(i_master_clk),

            .i_video_switch_allowed(w_system_switch_allowed),
            .o_video_bank(w_system_display_bank),

            .o_render_bank(w_system_render_bank),
            .o_render_start(w_system_render_start),
            .i_render_finished(w_system_render_finished),

            .i_mcu_queue_finished(w_mcu_data_end),
            .o_mcu_queue_locked(w_system_queue_locked)

        );


    // ***********************************************
    // **                                           **
    // **   VRAM CONTROLLER                         **
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

            .i_display_address(w_vram_display_address),
            .i_display_start(w_vram_display_start),
            .o_display_column(w_vram_display_column),
            .o_display_data(w_vram_display_data),
            .o_display_data_valid(w_vram_display_data_valid),

            .i_render_read_address(w_vram_render_read_address),
            .i_render_read_request(w_vram_render_read_request),
            .o_render_read_data(w_vram_render_read_data),
            .o_render_read_data_valid(w_vram_render_read_data_valid),

            .i_render_write_address(w_vram_render_write_address),
            .i_render_write_data(w_vram_render_write_data),
            .i_render_write_request(w_vram_render_write_request),
            .o_render_write_done(w_vram_render_write_done)
        );

    // ***********************************************
    // **                                           **
    // **   FLASH CONTROLLER                         **
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




endmodule
