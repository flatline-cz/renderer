
module Prototype1 (
        clk,

        uart_rx, uart_tx,

        vsync_o, hsync_o,

        red, green, blue,

        M1CS, M1OE, M1WE, M1A, M1D,

        FCEn,

        LED
    );

    input           clk;
    input           uart_rx;
    output          uart_tx;
    output          vsync_o;
    output          hsync_o;
    output[2:0]     LED;
    output[7:5]     red;
    output[7:5]     green;
    output[7:5]     blue;
    output          M1CS;
    output          M1OE;
    output          M1WE;
    output[19:0]    M1A;
    input[15:0]     M1D;

    output          FCEn;
    
    assign FCEn = 1;


    // Video pixel clock
    wire w_pixel_clk;
    PLL_65_25 pixel_clock_pll (
            .RESET(1'b1),
            .REFERENCECLK(clk),
            .PLLOUTGLOBAL(w_pixel_clk),
        );
    localparam PIXEL_FREQ = 65250000;

    // Master clock
    wire w_master_clk;
    PLL_50_35 master_clock_pll (
            .RESET(1'b1),
            .REFERENCECLK(clk),
            .PLLOUTGLOBAL(w_master_clk),
        );
    localparam MASTER_FREQ = 50350000;

    // SRAM data bus
    wire[15:0] w_mem_data_in;
    wire[15:0] w_mem_data_out;
    wire w_sram_data_dir_out;
    SB_IO #(
            .PIN_TYPE(6'b 1010_01),
            .PULLUP(1'b 0)
        ) sram1_interface [15:0] (
            .PACKAGE_PIN(M1D),
            .OUTPUT_ENABLE(w_sram_data_dir_out),
            .D_OUT_0(w_mem_data_out),
            .D_IN_0(w_mem_data_in)
        );

    // memory mapping
    wire[23:0] w_sram_data_in;
    wire[23:0] w_sram_data_out;

    assign w_mem_data_out =  { 
        w_sram_data_out[23:22], w_sram_data_out[19:18], w_sram_data_out[15:14], 2'b00,
        w_sram_data_out[11:10], w_sram_data_out[7:6], w_sram_data_out[3:2], 2'b00
        };

    assign w_sram_data_in = {
        w_mem_data_in[15:14], 2'b00, w_mem_data_in[13:12], 2'b00, w_mem_data_in[11:10], 2'b00,
        w_mem_data_in[7:6], 2'b00, w_mem_data_in[5:4], 2'b00, w_mem_data_in[3:2], 2'b00
        };


    // video mapping
    wire[3:0] w_video_red;
    wire[3:0] w_video_green;
    wire[3:0] w_video_blue;

    assign red      = { 1'b0, w_video_red[3:2] };
    assign green    = { 1'b0, w_video_green[3:2] };
    assign blue     = { 1'b0, w_video_blue[3:2] };


    // VideoCore instance
    VideoCore #(
            .MASTER_FREQ(MASTER_FREQ)
        ) video_core (
            .i_pixel_clk(w_pixel_clk),
            .i_master_clk(w_master_clk),

            .o_uart_tx(uart_tx),
            .i_uart_rx(uart_rx),

            .o_video_vsync(vsync_o),
            .o_video_hsync(hsync_o),

            .o_video_red(w_video_red),
            .o_video_green(w_video_green),
            .o_video_blue(w_video_blue),

            .o_sram_address(M1A),
            .o_sram_data_out(w_sram_data_out),
            .i_sram_data_in(w_sram_data_in),
            .o_sram_data_dir_out(w_sram_data_dir_out),
            .o_sram_oe_n(M1OE),
            .o_sram_we_n(M1WE),
            .o_sram_cs_n(M1CS),

            .dbg_rendering(LED[2])

        );


endmodule
