
module VideoCore (
        // clocks
        i_master_clk,
        i_pixel_clk,

        // UART interface
        // i_uart_rx, 
        // o_uart_tx,

        // SPI interface (mixed clock domain)
        i_spi_cs_n, 
        i_spi_clk, 
        i_spi_mosi, 
        o_spi_miso,

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
        dbg_rendering,
        dbg_display_bank,
        dbg_vsync,
        dbg_interrupt,
        dbg_vmode_render,
        dbg_vmode_player,
        dbg_uploading
    );

    input           i_master_clk;
    input           i_pixel_clk;

    // input           i_uart_rx;
    // output          o_uart_tx;

    input           i_spi_cs_n;
    input           i_spi_clk;
    input           i_spi_mosi;
    output          o_spi_miso;

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

    output          dbg_rendering;
    output          dbg_display_bank;
    output          dbg_uploading;
    output          dbg_vsync;
    output          dbg_interrupt;
    output          dbg_vmode_render;
    output          dbg_vmode_player;


    parameter PIXEL_FREQ    = 65250000;
    parameter MASTER_FREQ   = 50350000;
    parameter BOUD_RATE     = 500000;

    localparam QUEUE_SIZE_KB = 256;
    localparam QUEUE_MSB = $clog2(QUEUE_SIZE_KB*1024)-1;

    // ***********************************************
    // **                                           **
    // **   MCU INTERFACE                           **
    // **                                           **
    // ***********************************************

    wire w_mcu_queue_finished;

    // MCUController #(
    //         .CLOCK_FREQ(MASTER_FREQ),
    //         .BOUD_RATE(BOUD_RATE)
    //     ) mcu_controller (
    //         .i_master_clk(i_master_clk),

    //         .i_uart_rx(i_uart_rx),
    //         .o_uart_tx(o_uart_tx),

    //         .i_status_vsync(w_status_vsync),
    //         .i_status_interrupt(w_status_interrupt),
    //         .i_status_data(w_status_data),
    //         .o_status_request(w_status_request),

    //         .o_queue_data(w_queue_fill_data),
    //         .o_queue_data_valid(w_queue_fill_data_valid),
    //         .o_queue_start(w_queue_fill_start),
    //         .o_queue_end(w_queue_fill_end),

    //         .o_system_mode(w_set_rendering_mode),
    //         .o_system_mode_valid(w_set_rendering_mode_valid),

    //         .o_storage_start(w_mcu_storage_start),
    //         .o_storage_data(w_mcu_storage_data),
    //         .o_storage_data_valid(w_mcu_storage_data_valid),

    //         .o_playback_address(w_mcu_playback_address),
    //         .o_playback_address_valid(w_mcu_playback_address_valid)
    //     );

    DeviceController device_controller (
            .i_master_clk(i_master_clk),

            .i_spi_cs_n(i_spi_cs_n),
            .i_spi_clk(i_spi_clk),
            .i_spi_mosi(i_spi_mosi),
            .o_spi_miso(o_spi_miso),

            .o_status_request(w_status_request),
            .i_status_data(w_status_data),

            .o_system_mode(w_set_rendering_mode),
            .o_system_mode_valid(w_set_rendering_mode_valid),

            .o_storage_start(w_mcu_storage_start),
            .o_storage_data(w_mcu_storage_data),
            .o_storage_data_valid(w_mcu_storage_data_valid),

            .o_queue_data(w_queue_fill_data),
            .o_queue_data_valid(w_queue_fill_data_valid),
            .o_queue_start(w_queue_fill_start),
            .o_queue_end(w_queue_fill_end),

            .o_playback_address(w_mcu_playback_address),
            .o_playback_address_valid(w_mcu_playback_address_valid)
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
    wire        w_mcu_playback_available;

    StatusController status_controller (
            .i_master_clk(i_master_clk),

            .i_video_vsync_n(w_video_vsync),

            .i_status_request(w_status_request),
            .o_status_data(w_status_data),

            .i_system_rendering_mode(w_system_rendering_mode),

            .i_video_descriptor_ready(w_mcu_playback_available),

            .i_buffer_locked(w_mcu_queue_locked)



        );

    assign dbg_vsync = w_status_vsync;
    assign dbg_interrupt = w_status_interrupt;

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

    assign dbg_vmode_render = (w_system_rendering_mode==2'b01);
    assign dbg_vmode_player = (w_system_rendering_mode==2'b10);

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

            .i_queue_ready(w_queue_ready),
            .o_queue_finished(w_queue_finished),

            .o_render_start(w_render_process_start),
            .i_render_finished(w_render_process_done),
            .o_render_bank(w_render_bank)

        );

    assign dbg_display_bank = w_display_bank;



    // ***********************************************
    // **                                           **
    // **   VIDEO TIMING CONTROLLER                 **
    // **                                           **
    // ***********************************************

    wire        w_video_vsync;
    wire        w_video_hsync;
    wire        w_video_timing_pixel_first;
    wire        w_video_timing_pixel_last;
    wire        w_video_timing_blank;
    wire        w_video_timing_prefetch_start;
    wire        w_video_timing_prefetch_strobe_end;
    wire        w_video_timing_prefetch_row_first_render;
    wire        w_video_timing_prefetch_row_last_render;

    VideoTimingController video_controller (
            // clocks
            .i_pixel_clk(i_pixel_clk),
            .i_master_clk(i_master_clk),

            .o_video_vsync(w_video_vsync),
            .o_video_hsync(w_video_hsync),

            .o_timing_pixel_first(w_video_timing_pixel_first),
            .o_timing_pixel_last(w_video_timing_pixel_last),
            .o_timing_blank(w_video_timing_blank),
            .o_timing_prefetch_start(w_video_timing_prefetch_start),
            .o_timing_prefetch_strobe_end(w_video_timing_prefetch_strobe_end),
            .o_timing_prefetch_row_first_render(w_video_timing_prefetch_row_first_render),
            .o_timing_prefetch_row_last_render(w_video_timing_prefetch_row_last_render),

            .i_system_enabled(1'b1),
            .o_system_switch_allowed(w_system_video_switch_allowed)
        );

    assign o_video_vsync = w_video_vsync;
    assign o_video_hsync = w_video_hsync;

    // ***********************************************
    // **                                           **
    // **   VIDEO DATA CONTROLLER                   **
    // **                                           **
    // ***********************************************

    VideoRowBuffer video_row_buffer (
            .i_pixel_clk(i_pixel_clk),
            .i_master_clk(i_master_clk),

            .i_buffer_display_bank(w_display_bank),

            .i_system_rendering_mode(w_system_rendering_mode),

            .i_video_timing_pixel_first(w_video_timing_pixel_first),
            .i_video_timing_pixel_last(w_video_timing_pixel_last),
            .i_video_timing_blank(w_video_timing_blank),
            .i_video_timing_prefetch_start(w_video_timing_prefetch_start),
            .i_video_timing_prefetch_strobe_end(w_video_timing_prefetch_strobe_end),
            .i_video_timing_prefetch_row_first_render(w_video_timing_prefetch_row_first_render),
            .i_video_timing_prefetch_row_last_render(w_video_timing_prefetch_row_last_render),

            .o_display_address(w_video_display_address),
            .o_display_start(w_video_display_start),
            .i_display_column(w_video_display_column),
            .i_display_data(w_video_display_data),
            .i_display_data_valid(w_video_display_data_valid),

            .o_video_display_start_line(w_playback_line_start),
            .i_video_display_data_valid(w_playback_display_data_valid),
            .i_video_display_data(w_playback_display_data),
            .i_video_display_column(w_playback_display_column),

            .o_video_red(o_video_red),
            .o_video_green(o_video_green),
            .o_video_blue(o_video_blue)
        );

    // ***********************************************
    // **                                           **
    // **   QUEUE CONTROLLER                        **
    // **                                           **
    // ***********************************************

    wire[QUEUE_MSB:0]   queue_write_address;
    wire[7:0]           queue_write_data;
    wire                queue_write_request;
    wire                queue_write_done;

    wire[QUEUE_MSB:0]   queue_read_address;
    wire[7:0]           queue_read_data;
    wire                queue_read_request;
    wire                queue_read_data_valid;

    wire                w_queue_fill_start;
    wire                w_queue_fill_end;
    wire[7:0]           w_queue_fill_data;
    wire                w_queue_fill_data_valid;

    wire                w_queue_read_request;
    wire[7:0]           w_queue_read_data;
    wire                w_queue_read_data_valid;
    wire                w_queue_read_eof;

    wire                w_queue_ready;
    wire                w_queue_finished;


    QueueController #(
            .SIZE_KB(QUEUE_SIZE_KB)
        ) queue_controller (
            .i_master_clk(i_master_clk),

            .i_queue_start(w_queue_fill_start),
            .i_queue_end(w_queue_fill_end),
            .i_queue_data(w_queue_fill_data),
            .i_queue_data_valid(w_queue_fill_data_valid),

            .o_buffer_queue_ready(w_queue_ready),
            .i_buffer_queue_finished(w_queue_finished),

            .i_render_start(w_render_process_start),
            .i_render_request(w_queue_read_request),
            .o_render_data_eof(w_queue_read_eof),
            .o_render_data(w_queue_read_data),
            .o_render_data_valid(w_queue_read_data_valid),

            .o_vram_write_address(queue_write_address),
            .o_vram_write_data(queue_write_data),
            .o_vram_write_request(queue_write_request),
            .i_vram_write_done(queue_write_done),

            .o_vram_read_address(queue_read_address),
            .o_vram_read_request(queue_read_request),
            .i_vram_read_data(queue_read_data),
            .i_vram_read_data_valid(queue_read_data_valid),

            .dbg_queue_uploading(dbg_uploading),
            .dbg_queue_rendering(w_mcu_queue_locked)

        );


    // ***********************************************
    // **                                           **
    // **   COMMAND PROCESSOR                       **
    // **                                           **
    // ***********************************************

    wire            w_render_process_start;
    wire            w_render_process_done;

    wire            w_render_cmd_valid;
    wire            w_render_cmd_done;
    wire[9:0]       w_render_cmd_x1;
    wire[9:0]       w_render_cmd_y1;
    wire[9:0]       w_render_cmd_x2;
    wire[9:0]       w_render_cmd_y2;
    wire[3:0]       w_render_cmd_color_r;
    wire[3:0]       w_render_cmd_color_g;
    wire[3:0]       w_render_cmd_color_b;
    wire[3:0]       w_render_cmd_color_a;
    wire            w_render_cmd_textured;
    wire            w_render_cmd_texture_packed;
    wire            w_render_cmd_texture_copy;
    wire[19:0]      w_render_cmd_texture_base;
    wire[9:0]       w_render_cmd_texture_stripe;
    
    CommandProcessor cmd_processor (
            .i_master_clk(i_master_clk),

            .i_process_start(w_render_process_start),
            .o_process_done(w_render_process_done),

            .o_cmd_valid(w_render_cmd_valid),
            .i_cmd_finished(w_render_cmd_done),
            .o_cmd_x1(w_render_cmd_x1),
            .o_cmd_x2(w_render_cmd_x2),
            .o_cmd_y1(w_render_cmd_y1),
            .o_cmd_y2(w_render_cmd_y2),
            .o_cmd_color_r(w_render_cmd_color_r),
            .o_cmd_color_g(w_render_cmd_color_g),
            .o_cmd_color_b(w_render_cmd_color_b),
            .o_cmd_color_a(w_render_cmd_color_a),
            .o_cmd_textured(w_render_cmd_textured),
            .o_cmd_texture_packed(w_render_cmd_texture_packed),
            .o_cmd_texture_copy(w_render_cmd_texture_copy),
            .o_cmd_texture_base(w_render_cmd_texture_base),
            .o_cmd_texture_stripe(w_render_cmd_texture_stripe),

            .o_queue_request(w_queue_read_request),
            .i_queue_data(w_queue_read_data),
            .i_queue_data_valid(w_queue_read_data_valid),
            .i_queue_eof(w_queue_read_eof),

            .dbg_rendering(dbg_rendering)

        );


    // // ***********************************************
    // // **                                           **
    // // **   RENDERING ENGINE                        **
    // // **                                           **
    // // ***********************************************

    // connection between RENDER CONTROLLER & VRAM CONTROLLER
    wire[19:0]  w_vram_render_read_address; 
    wire        w_vram_render_read_request;
    wire[23:0]  w_vram_render_read_data;
    wire        w_vram_render_read_data_valid;
    wire[19:0]  w_vram_render_write_address;
    wire        w_vram_render_write_request;
    wire[23:0]  w_vram_render_write_data;
    wire        w_vram_render_write_done;


    Renderer renderer (
            .i_master_clk(i_master_clk),

            .i_process_start(w_render_cmd_valid),
            .i_process_bank(w_render_bank),
            .o_process_finished(w_render_cmd_done),

            .i_cmd_rect_x1(w_render_cmd_x1),
            .i_cmd_rect_x2(w_render_cmd_x2),
            .i_cmd_rect_y1(w_render_cmd_y1),
            .i_cmd_rect_y2(w_render_cmd_y2),
            .i_cmd_color_red(w_render_cmd_color_r),
            .i_cmd_color_green(w_render_cmd_color_g),
            .i_cmd_color_blue(w_render_cmd_color_b),
            .i_cmd_color_alpha(w_render_cmd_color_a),
            .i_cmd_textured(w_render_cmd_textured),
            .i_cmd_texture_packed(w_render_cmd_texture_packed),
            .i_cmd_texture_copy(w_render_cmd_texture_copy),
            .i_cmd_texture_base(w_render_cmd_texture_base),
            .i_cmd_texture_stripe(w_render_cmd_texture_stripe),

            .o_vram_read_address(w_vram_render_read_address),
            .o_vram_read_request(w_vram_render_read_request),
            .i_vram_read_data(w_vram_render_read_data),
            .i_vram_read_data_valid(w_vram_render_read_data_valid),
            .o_vram_write_address(w_vram_render_write_address),
            .o_vram_write_request(w_vram_render_write_request),
            .o_vram_write_data(w_vram_render_write_data),
            .i_vram_write_done(w_vram_render_write_done),

            .o_flash_read_address(w_texture_read_address),
            .o_flash_read_request(w_texture_read_request),
            .i_flash_read_data(w_texture_read_data),
            .i_flash_read_data_valid(w_texture_read_data_valid)

        );

    // ***********************************************
    // **                                           **
    // **   STORAGE CONTROLLER                      **
    // **                                           **
    // ***********************************************

    wire        w_mcu_storage_start;
    wire[7:0]   w_mcu_storage_data;
    wire        w_mcu_storage_data_valid;

    wire[18:0]  w_storage_address;
    wire[7:0]   w_storage_data;
    wire        w_storage_request;
    wire        w_storage_done;

    StorageController storage_controller (
            .i_master_clk(i_master_clk),

            .i_mcu_start(w_mcu_storage_start),
            .i_mcu_data(w_mcu_storage_data),
            .i_mcu_data_valid(w_mcu_storage_data_valid),

            .o_vram_write_address(w_storage_address),
            .o_vram_write_data(w_storage_data),
            .o_vram_write_request(w_storage_request),
            .i_vram_write_done(w_storage_done)

        );


    // ***********************************************
    // **                                           **
    // **   PLAYBACK CONTROLLER & DECODER           **
    // **                                           **
    // ***********************************************

    wire[17:0]  w_playback_address;
    wire        w_playback_address_valid;
    wire        w_playback_line_start;

    wire[18:0]  w_mcu_playback_address;
    wire        w_mcu_playback_address_valid;

    PlaybackController playback_controller (
            .i_master_clk(i_master_clk),

            .i_video_timing_vsync(w_video_vsync),

            .i_mcu_playback_address(w_mcu_playback_address[17:0]),
            .i_mcu_playback_address_valid(w_mcu_playback_address_valid),

            .o_status_playback_available(w_mcu_playback_available),

            .o_video_render_address(w_playback_address),
            .o_video_render_address_valid(w_playback_address_valid)

        );

    wire[8:0]   w_playback_display_column;
    wire[23:0]  w_playback_display_data;
    wire        w_playback_display_data_valid;

    VideoDecoder playback_decoder (
            .i_master_clk(i_master_clk),

            .i_playback_address(w_playback_address),
            .i_playback_address_valid(w_playback_address_valid),

            .i_video_start(w_playback_line_start),
            .o_video_column(w_playback_display_column),
            .o_video_data(w_playback_display_data),
            .o_video_data_valid(w_playback_display_data_valid),

            .o_vram_read_address(w_playback_read_address),
            .o_vram_read_request(w_playback_read_request),
            .i_vram_read_data(w_playback_read_data),
            .i_vram_read_data_valid(w_playback_read_data_valid)
        );


    // ***********************************************
    // **                                           **
    // **   VRAM CONTROLLER                         **
    // **                                           **
    // ***********************************************

    wire[19:0]  w_video_display_address;
    wire        w_video_display_start;
    wire[8:0]   w_video_display_column;
    wire[23:0]  w_video_display_data;
    wire        w_video_display_data_valid;

    wire[17:0]  w_texture_read_address;
    wire        w_texture_read_request;
    wire[15:0]  w_texture_read_data;
    wire        w_texture_read_data_valid;

    wire[17:0]  w_playback_read_address;
    wire        w_playback_read_request;
    wire[15:0]  w_playback_read_data;
    wire        w_playback_read_data_valid;


    VRAMController vram_controller (
            .i_master_clk(i_master_clk),

            .o_sram_addr(o_sram_address),
            .o_sram_data_out(o_sram_data_out),
            .o_sram_data_dir_out(o_sram_data_dir_out),
            .i_sram_data_in(i_sram_data_in),
            .o_sram_oe_n(o_sram_oe_n),
            .o_sram_we_n(o_sram_we_n),
            .o_sram_cs_n(o_sram_cs_n),

            .i_display_address(w_video_display_address),
            .i_display_start(w_video_display_start),
            .o_display_column(w_video_display_column),
            .o_display_data(w_video_display_data),
            .o_display_data_valid(w_video_display_data_valid),

            .i_render_read_address(w_vram_render_read_address),
            .i_render_read_request(w_vram_render_read_request),
            .o_render_read_data(w_vram_render_read_data),
            .o_render_read_data_valid(w_vram_render_read_data_valid),

            .i_render_write_address(w_vram_render_write_address),
            .i_render_write_data(w_vram_render_write_data),
            .i_render_write_request(w_vram_render_write_request),
            .o_render_write_done(w_vram_render_write_done),

            .i_queue_read_address(queue_read_address),
            .i_queue_read_request(queue_read_request),
            .o_queue_read_data(queue_read_data),
            .o_queue_read_data_valid(queue_read_data_valid),

            .i_queue_write_address(queue_write_address),
            .i_queue_write_data(queue_write_data),
            .i_queue_write_request(queue_write_request),
            .o_queue_write_done(queue_write_done),

            .i_texture_read_address(w_texture_read_address),
            .i_texture_read_request(w_texture_read_request),
            .o_texture_read_data(w_texture_read_data),
            .o_texture_read_data_valid(w_texture_read_data_valid),
            
            .i_playback_request(w_playback_read_request),
            .i_playback_address(w_playback_read_address),
            .o_playback_data(w_playback_read_data),
            .o_playback_data_valid(w_playback_read_data_valid),

            .i_mcu_store_address(w_storage_address),
            .i_mcu_store_data(w_storage_data),
            .i_mcu_store_request(w_storage_request),
            .o_mcu_store_done(w_storage_done)
        );



endmodule
