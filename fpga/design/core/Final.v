
module FPGA (
        CLK,
        SPI_CS_n, SPI_CLK, SPI_MISO, SPI_MOSI,
        TFT_MODE, TFT_DE, TFT_DCLK, TFT_RESET, TFT_VSYNC, TFT_HSYNC, TFT_RED, TFT_GREEN, TFT_BLUE,
        M1CS, M1OE, M1OE1, M1WE, M1A, M1D,
        PWR_VGL, PWR_VGH, PWR_VCOM, PWR_AVDD, PWR_DVDD
    );

    // clock
    input           CLK;

    // SPI
    input           SPI_CS_n;
    input           SPI_CLK;
    input           SPI_MOSI;
    output          SPI_MISO;

    // memory
    output          M1CS;
    output          M1OE;
    output          M1OE1;
    output          M1WE;
    output[19:0]    M1A;
    inout[31:0]     M1D;

    // TFT panel
    output          TFT_VSYNC;
    output          TFT_HSYNC;
    output[7:0]     TFT_RED;
    output[7:0]     TFT_GREEN;
    output[7:0]     TFT_BLUE;
    output          TFT_MODE;
    output          TFT_DE;
    output          TFT_DCLK;
    output          TFT_RESET;

    // Power control
    output          PWR_VGL;
    output          PWR_VGH;
    output          PWR_VCOM;
    output          PWR_AVDD;
    output          PWR_DVDD;

    // fixme: test
//    assign PWR_VGL = 1'b0;
//    assign PWR_VGH = 1'b1;
//    assign PWR_VCOM = 1'b1;


    // Video pixel clock
    wire w_pixel_clk;
//    wire w_tft_clk;
    PLL_51_00 pixel_clock_pll (
            .RESET(1'b1),
            .REFERENCECLK(CLK),
            .PLLOUTGLOBAL(w_pixel_clk)
//            .PLLOUTGLOBALB(w_tft_clk)
        );

    // Master clock
    wire w_master_clk;
    PLL_50_35 master_clock_pll (
            .RESET(1'b1),
            .REFERENCECLK(CLK),
            .PLLOUTGLOBAL(w_master_clk)
        );

//    SPIController spi_controller (
//            .i_master_clk(w_master_clk),
//
//            .i_spi_cs_n(SPI_CS_n),
//            .i_spi_clk(SPI_CLK),
//            .i_spi_mosi(SPI_MOSI),
//            .o_spi_miso(SPI_MISO),
//
//            .i_response_data_valid(1'b0)
//
//        );


    // Video timing controller
//    wire[10:0] counter_h;
//    wire[9:0] counter_v;
//    VideoTimingController VideoTimingController (
//            .i_pixel_clk(w_pixel_clk),
//            .i_master_clk(w_master_clk),
//
//            .i_system_enabled(1'b1),
//
//            .o_counter_h(counter_h),
//            .o_counter_v(counter_v),
//
//            .o_tft_hsync_n(TFT_HSYNC),
//            .o_tft_vsync_n(TFT_VSYNC),
//            .o_tft_reset_n(TFT_RESET)
//        );
    assign TFT_MODE = 1'b0;
    assign TFT_DE = 1'b0;
    assign TFT_DCLK = w_pixel_clk;

//    assign TFT_RED = {8{counter_v[0]^counter_h[0]}};
//    assign TFT_GREEN = {8{counter_v[0]^counter_h[0]}};
//    assign TFT_BLUE = {8{counter_v[0]^counter_h[0]}};
//    assign TFT_RED = { counter_h[9:6], counter_h[9:6] };
//    assign TFT_GREEN = { counter_v[9:6], counter_v[9:6] };
//    assign TFT_BLUE = { counter_h[9:6], counter_h[9:6] };

//    wire w_match_h = (counter_h >= (160 + 256 + 128)) && (counter_h < (160 + 256 + 256));
//    wire w_match_v = (counter_v >= (23 + 200)) && (counter_v < (23 + 200 + 200));
//    wire[3:0] red = (w_match_h && w_match_v) ? 8'hff : { counter_h[9:6], counter_h[9:6] };
//    wire[3:0] green = (w_match_h && w_match_v) ? 8'hff : { counter_v[9:6], counter_v[9:6] };
//
//    assign TFT_RED = { red, red };
//    assign TFT_GREEN = { green, green };
//    assign TFT_BLUE = { red, red };


    localparam MASTER_FREQ = 50350000;

    // SRAM data bus
    wire[31:0] w_sram_data_in;
    wire[31:0] w_sram_data_out;
    wire w_sram_data_dir_out;
    SB_IO #(
            .PIN_TYPE(6'b 1010_01),
            .PULLUP(1'b 0)
        ) sram_interface [31:0] (
            .PACKAGE_PIN(M1D),
            .OUTPUT_ENABLE(w_sram_data_dir_out),
            .D_OUT_0(w_sram_data_out),
            .D_IN_0(w_sram_data_in)
        );

    // VideoCore instance
    wire[3:0] core_red;
    wire[3:0] core_green;
    wire[3:0] core_blue;
    assign TFT_RED = {core_red, core_red};
    assign TFT_GREEN = {core_green, core_green};
    assign TFT_BLUE = {core_blue, core_blue};

    assign w_sram_data_out[31:24] = 0;

    wire m_oe;
    assign M1OE = 1'b1;
    assign M1OE1 = m_oe;

    VideoCore video_core (
            .i_pixel_clk(w_pixel_clk),
            .i_master_clk(w_master_clk),

            .i_spi_cs_n(SPI_CS_n),
            .i_spi_clk(SPI_CLK),
            .i_spi_mosi(SPI_MOSI),
            .o_spi_miso(SPI_MISO),


            .o_video_vsync(TFT_VSYNC),
            .o_video_hsync(TFT_HSYNC),
            .o_video_reset(TFT_RESET),

            .o_video_red(core_red),
            .o_video_green(core_green),
            .o_video_blue(core_blue),

            .o_sram_address(M1A),
            .o_sram_data_out(w_sram_data_out[23:0]),
            .i_sram_data_in(w_sram_data_in[23:0]),
            .o_sram_data_dir_out(w_sram_data_dir_out),
            .o_sram_oe_n(m_oe),
            .o_sram_we_n(M1WE),
            .o_sram_cs_n(M1CS)

        );

endmodule
