
module FPGA (
        clk,

        // uart_rx, uart_tx,
        SPI_CS_n, SPI_CLK, SPI_MISO, SPI_MOSI,

        vsync_o, hsync_o,

        red, green, blue,

        M1CS, M1OE, M1WE, M1A, M1D,

        PWR_VGL, PWR_VGH

    );

    input           clk;
    input           SPI_CS_n;
    input           SPI_CLK;
    input           SPI_MOSI;
    output          SPI_MISO;
    output          vsync_o;
    output          hsync_o;
    output[7:0]     red;
    output[7:0]     green;
    output[7:0]     blue;
    output          M1CS;
    output          M1OE;
    output          M1WE;
    output[19:0]    M1A;
    inout[31:0]     M1D;

    output          PWR_VGL;
    output          PWR_VGH;


    assign PWR_VGL = clk;

    // Video pixel clock
    wire w_pixel_clk;
    PLL_65_25 pixel_clock_pll (
            .RESET(1'b1),
            .REFERENCECLK(clk),
            .PLLOUTGLOBAL(w_pixel_clk)
        );
    localparam PIXEL_FREQ = 65250000;

    // Master clock
    wire w_master_clk;
    PLL_50_35 master_clock_pll (
            .RESET(1'b1),
            .REFERENCECLK(clk),
            .PLLOUTGLOBAL(w_master_clk)
        );
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
    assign red = {core_red, core_red};
    assign green = {core_green, core_green};
    assign blue = {core_blue, core_blue};
    
    VideoCore2 #(
            .MASTER_FREQ(MASTER_FREQ)
        ) video_core (
            .i_pixel_clk(w_pixel_clk),
            .i_master_clk(w_master_clk),

            .i_spi_cs_n(SPI_CS_n),
            .i_spi_clk(SPI_CLK),
            .i_spi_mosi(SPI_MOSI),
            .o_spi_miso(SPI_MISO),


            .o_video_vsync(vsync_o),
            .o_video_hsync(hsync_o),

            .o_video_red(core_red),
            .o_video_green(core_green),
            .o_video_blue(core_blue),

            .o_sram_address(M1A),
            .o_sram_data_out(w_sram_data_out[23:0]),
            .i_sram_data_in(w_sram_data_in[23:0]),
            .o_sram_data_dir_out(w_sram_data_dir_out),
            .o_sram_oe_n(M1OE),
            .o_sram_we_n(M1WE),
            .o_sram_cs_n(M1CS)

        );


    


endmodule
