// Physical interface: VGA 1024x768 60Hz
// Real resolution: 1024x600, lower 168 lines black

module VideoTimingController (
        // clock
        i_pixel_clk,
        i_master_clk,

        // VIDEO signals
        o_tft_hsync_n,
        o_tft_vsync_n,
//        o_tft_blank,
        o_tft_reset_n,

        // SYSTEM CONTROLLER interface
        i_system_enabled,
        o_system_switch_allowed,

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

    output      o_tft_hsync_n;
    output      o_tft_vsync_n;
//    output      o_tft_blank;
    output      o_tft_reset_n;

    input       i_system_enabled;
    output      o_system_switch_allowed;

    output      o_timing_pixel_first;
    output      o_timing_pixel_last;
    output      o_timing_blank;
    output      o_timing_prefetch_start;
    output      o_timing_prefetch_strobe_end;
    output      o_timing_prefetch_row_first_render;
    output      o_timing_prefetch_row_last_render;

    output[10:0] o_counter_h;
    output[9:0] o_counter_v;

    // reset not used for VGA
    assign      o_tft_reset_n = 1'b1;

    // ***********************************************
    // **                                           **
    // **   HORIZONTAL TIMING                       **
    // **                                           **
    // ***********************************************

    // timing parameters
    localparam HSYNC_WIDTH          = 1024;
    localparam HSYNC_PULSE          = 136;
    localparam HSYNC_FRONT_PORCH    = 24;
    localparam HSYNC_BACK_PORCH     = 160;
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

    // timing signals
    reg r_hsync = 0;
    reg r_horizontal_video_on = 0;
    reg r_horizontal_front_porch = 0;

    always @(posedge i_pixel_clk) begin
        if(r_horizontal_counter == HSYNC_LAST)
            r_hsync <= 1;
        if(r_horizontal_counter == HSYNC_PULSE - 1)
            r_hsync <= 0;
    end

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

    // export HSYNC (negative polarity)
    assign o_tft_hsync_n = !r_hsync;

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
    localparam VSYNC_HEIGHT         = 768;
    localparam VSYNC_PULSE          = 6;
    localparam VSYNC_FRONT_PORCH    = 3;
    localparam VSYNC_BACK_PORCH     = 29;
    localparam VSYNC_LAST           = VSYNC_PULSE + VSYNC_BACK_PORCH + VSYNC_FRONT_PORCH + VSYNC_HEIGHT - 1;
    localparam VSYNC_MSB            = $clog2(VSYNC_LAST) - 1;    

    // counting register
    reg[VSYNC_MSB:0] r_vertical_counter = 0;

    always @(posedge i_pixel_clk)
        if(i_system_enabled && r_horizontal_counter == HSYNC_LAST) begin
            if(r_vertical_counter == VSYNC_LAST)
                r_vertical_counter <= 0;
            else
                r_vertical_counter <= r_vertical_counter + 1;
        end

    // timing signals
    reg r_vsync = 0;
    reg r_vertical_video_on = 0;

    always @(posedge i_pixel_clk) begin
        if(r_vertical_counter == VSYNC_LAST)
            r_vsync <= 1;
        if(r_vertical_counter == VSYNC_PULSE - 1)
            r_vsync <= 0;
    end

    always @(posedge i_pixel_clk) begin
        if(r_vertical_counter == VSYNC_PULSE + VSYNC_BACK_PORCH - 1)
            r_vertical_video_on <= 1;
        if(r_vertical_counter == VSYNC_PULSE + VSYNC_BACK_PORCH + VSYNC_HEIGHT - 1)
            r_vertical_video_on <= 0;
    end

    // export VSYNC (negative polarity)
    assign o_tft_vsync_n = !r_vsync;

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


endmodule
