/*
* Copyright (c) 2023. All rights reserved.
* Created by tumap, 8/23/23
*/

module VideoTimingController (
    // clocks
    i_pixel_clk,
    i_master_clk,

    // control signals (master clock domain)
    i_system_enabled,
    o_system_switch_allowed,
    i_reset_request,

    // TFT panel timing (pixel clock domain)
    o_tft_reset_n,
    o_tft_vsync_n,
    o_tft_hsync_n,

    // DEBUG
    o_counter_h,
    o_counter_v,

    // VIDEO ROW BUFFER
    o_timing_pixel_first,
    o_timing_pixel_last,
    o_timing_blank,
    o_timing_prefetch_start,
    o_timing_prefetch_strobe_end,
    o_timing_prefetch_row_first_render,
    o_timing_prefetch_row_last_render

);

    input       i_pixel_clk;
    input       i_master_clk;

    input       i_system_enabled;
    output      o_system_switch_allowed;
    input       i_reset_request;

    output      o_tft_reset_n;
    output      o_tft_vsync_n;
    output      o_tft_hsync_n;
//    output      o_tft_blanc;

    output      o_timing_pixel_first;
    output      o_timing_pixel_last;
    output      o_timing_blank;
    output      o_timing_prefetch_start;
    output      o_timing_prefetch_strobe_end;
    output      o_timing_prefetch_row_first_render;
    output      o_timing_prefetch_row_last_render;

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
        if(i_system_enabled) begin
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
    reg r_horizontal_video_on = 0;
    reg r_horizontal_front_porch = 0;

    always @(posedge i_pixel_clk) begin
        if(r_horizontal_counter == HSYNC_LAST)
            r_hsync_n <= 1'b0;
        if(r_horizontal_counter == HSYNC_PULSE - 1)
            r_hsync_n <= 1'b1;
    end
    assign o_tft_hsync_n = r_hsync_n;

    always @(posedge i_pixel_clk) begin
        if(r_horizontal_counter == HSYNC_PULSE + HSYNC_BACK_PORCH - 1)
            r_horizontal_video_on <= 1;
        if(r_horizontal_counter == HSYNC_PULSE + HSYNC_BACK_PORCH + HSYNC_WIDTH - 4)
            r_horizontal_video_on <= 0;
    end

    always @(posedge i_pixel_clk) begin
        if(r_horizontal_counter == HSYNC_PULSE + HSYNC_BACK_PORCH + HSYNC_WIDTH - 1)
            r_horizontal_front_porch <= 1;
        if(r_horizontal_counter == HSYNC_LAST)
            r_horizontal_front_porch <= 0;
    end

    assign o_timing_pixel_first = r_vertical_video_on && (r_horizontal_counter == HSYNC_PULSE + HSYNC_BACK_PORCH - 5);
    // signal: cache last pixel
    assign o_timing_pixel_last = r_vertical_video_on && (r_horizontal_counter == HSYNC_PULSE + HSYNC_BACK_PORCH + HSYNC_WIDTH - 5);

    assign o_timing_prefetch_start = (r_horizontal_counter == HSYNC_PULSE + HSYNC_BACK_PORCH + HSYNC_WIDTH);
    assign o_timing_prefetch_strobe_end = (r_horizontal_counter == HSYNC_PULSE + HSYNC_BACK_PORCH + HSYNC_WIDTH + 4);

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
        if(i_system_enabled && r_horizontal_counter == HSYNC_LAST) begin
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
    reg r_vertical_video_on = 0;

    always @(posedge i_pixel_clk) begin
        if(i_system_enabled && r_horizontal_counter == HSYNC_LAST) begin
            if(r_vertical_counter == VSYNC_LAST)
                r_vsync <= 0;
            if(r_vertical_counter == VSYNC_PULSE - 1)
                r_vsync <= 1;
        end
    end
    assign o_tft_vsync_n = r_vsync;

    always @(posedge i_pixel_clk) begin
        if(r_vertical_counter == VSYNC_PULSE + VSYNC_BACK_PORCH - 1)
            r_vertical_video_on <= 1;
        if(r_vertical_counter == VSYNC_PULSE + VSYNC_BACK_PORCH + VSYNC_HEIGHT - 1)
            r_vertical_video_on <= 0;
    end

    // transfer falling edge of r_vertical_video_on into single clock pulse in master clock domain
    reg[2:0]    xd_switch_allowed = 3'b0;

    always @(posedge i_master_clk)
        xd_switch_allowed <= { xd_switch_allowed[1:0], r_vertical_video_on };

    assign o_system_switch_allowed = (xd_switch_allowed[2]==1 && xd_switch_allowed[1]==0);

    // -- signal: next row is the first row displayed
    wire w_next_row_is_first = (r_vertical_counter == VSYNC_PULSE + VSYNC_BACK_PORCH - 2);

    // blanking last 168 lines
    wire w_next_row_is_last_displayed = (r_vertical_counter == VSYNC_PULSE + VSYNC_BACK_PORCH + 600 - 2);

    reg r_video_blank = 1;

    always @(posedge i_pixel_clk) begin
        if(w_next_row_is_first)
            r_video_blank <= 0;
        if(w_next_row_is_last_displayed)
            r_video_blank <= 1;
    end

    assign o_timing_blank = !(r_vertical_video_on && r_horizontal_video_on && !r_video_blank);

    // -- signal: next row is the first row displayed
    assign o_timing_prefetch_row_first_render = w_next_row_is_first;

    // -- signal: next row is the last row displayed
    assign o_timing_prefetch_row_last_render = w_next_row_is_last_displayed;

    reg r_vsync_start = 0;

    always @(posedge i_pixel_clk) begin
        if(i_system_enabled && r_horizontal_counter == HSYNC_LAST && r_vertical_counter == VSYNC_LAST)
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
