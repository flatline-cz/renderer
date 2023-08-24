/*
* Copyright (c) 2023. All rights reserved.
* Created by tumap, 8/23/23
*/

module VideoTimingController (
    // clocks
    i_pixel_clk,
    i_master_clk,

    // control signals (master clock domain)
    i_enabled,
    i_reset_request,

    // TFT panel timing (pixel clock domain)
    o_tft_reset_n,
    o_tft_vsync,
    o_tft_hsync_n

    // FIXME: remove
    ,
    o_counter_h,
    o_counter_v
);
    input       i_pixel_clk;
    input       i_master_clk;

    input       i_enabled;
    input       i_reset_request;

    output      o_tft_reset_n;
    output      o_tft_vsync;
    output      o_tft_hsync_n;

    // FIXME: remove
    output[10:0] o_counter_h;
    output[9:0] o_counter_v;

    // ***********************************************
    // **                                           **
    // **   CONTROL SIGNAL DOMAIN CROSSING          **
    // **                                           **
    // ***********************************************

    // ***********************************************
    // **                                           **
    // **   HORIZONTAL TIMING                       **
    // **                                           **
    // ***********************************************

    // timing parameters
    localparam HSYNC_WIDTH          = 1024;
    localparam HSYNC_PULSE          = 10;
    localparam HSYNC_FRONT_PORCH    = 16;
    localparam HSYNC_BACK_PORCH     = 150;
    localparam HSYNC_LAST           = HSYNC_BACK_PORCH + HSYNC_FRONT_PORCH + HSYNC_PULSE + HSYNC_WIDTH - 1;
    localparam HSYNC_MSB            = $clog2(HSYNC_LAST) - 1;

    // counting register
    reg[HSYNC_MSB:0] r_horizontal_counter = 0;

    always @(posedge i_pixel_clk) begin
        if(i_enabled) begin             // FIXME: use internal signal
            if(r_horizontal_counter == HSYNC_LAST)
                r_horizontal_counter <= 0;
            else
                r_horizontal_counter <= r_horizontal_counter + 1;
        end else begin
            r_horizontal_counter <= 0;
        end
    end

    // FIXME: remove
    assign o_counter_h = r_horizontal_counter;

    // timing signals
    reg r_hsync_n = 1'b1;

    always @(posedge i_pixel_clk) begin
        if(r_horizontal_counter == HSYNC_LAST)
            r_hsync_n <= 1'b0;
        if(r_horizontal_counter == HSYNC_PULSE - 1)
            r_hsync_n <= 1'b1;
    end
    assign o_tft_hsync_n = r_hsync_n;

    // ***********************************************
    // **                                           **
    // **   VERTICAL TIMING                         **
    // **                                           **
    // ***********************************************

    // timing parameters
    localparam VSYNC_HEIGHT         = 600;
    localparam VSYNC_PULSE          = 2;
    localparam VSYNC_FRONT_PORCH    = 64;
    localparam VSYNC_BACK_PORCH     = 21;
    localparam VSYNC_LAST           = VSYNC_PULSE + VSYNC_BACK_PORCH + VSYNC_FRONT_PORCH + VSYNC_HEIGHT - 1;
    localparam VSYNC_MSB            = $clog2(VSYNC_LAST) - 1;

    // counting register
    reg[VSYNC_MSB:0] r_vertical_counter = 0;

    always @(posedge i_pixel_clk) begin
        if(i_enabled && r_horizontal_counter == HSYNC_LAST) begin       // FIXME: use internal signal
            if(r_vertical_counter == VSYNC_LAST)
                r_vertical_counter <= 0;
            else
                r_vertical_counter <= r_vertical_counter + 1;
        end
    end

    // FIXME: remove
    assign o_counter_v = r_vertical_counter;

    // timing signals
    reg r_vsync = 0;

    always @(posedge i_pixel_clk) begin
        if(i_enabled && r_horizontal_counter == HSYNC_LAST) begin
            if(r_vertical_counter == VSYNC_LAST)
                r_vsync <= 0;
            if(r_vertical_counter == VSYNC_PULSE - 1)
                r_vsync <= 1;
        end
    end
    assign o_tft_vsync = r_vsync;

    reg r_vsync_start = 0;

    always @(posedge i_pixel_clk) begin
        if(i_enabled && r_horizontal_counter == HSYNC_LAST && r_vertical_counter == VSYNC_LAST)
            r_vsync_start <= 1'b1;
        else
            r_vsync_start <= 1'b0;
    end

    // ***********************************************
    // **                                           **
    // **   RESET TIMING                            **
    // **                                           **
    // ***********************************************

    reg[1:0]    r_reset = 2'b01;

    always @(posedge i_pixel_clk) begin
        if(r_vsync_start)
            r_reset <= { r_reset[0], 1'b0 };
    end

    wire w_reset = r_reset == 2'b00;

    assign o_tft_reset_n = w_reset;

endmodule
