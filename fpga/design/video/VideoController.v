// Physical interface: VGA 1024x768 60Hz
// Real resolution: 1024x600, lower 168 lines black
// Always enabled

module VideoController (
        // pixel clock domain
        i_pixel_clk,

        // master clock domain
        i_master_clk,

        // SYSTEM CONTROLLER interface (master clock domain)
        i_system_bank,
        o_system_switch_allowed,

        // DISPLAY interface (pixel clock domain)
        o_video_hsync,
        o_video_vsync,
        o_video_red,
        o_video_green,
        o_video_blue,

        // MEMORY ARBITER interface (master clock domain)
        o_vram_display_address,
        o_vram_display_start,
        i_vram_display_column,
        i_vram_display_data,
        i_vram_display_data_valid

    );

    input           i_pixel_clk;
    input           i_master_clk;

    input           i_system_bank;
    output          o_system_switch_allowed;

    output          o_video_hsync;
    output          o_video_vsync;
    output[3:0]     o_video_red;
    output[3:0]     o_video_green;
    output[3:0]     o_video_blue;

    output[19:0]    o_vram_display_address;
    output          o_vram_display_start;
    input[8:0]      i_vram_display_column;
    input[23:0]     i_vram_display_data;
    input           i_vram_display_data_valid;

    reg             r_enabled = 1'b1;

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

    always @(posedge i_pixel_clk)
        if(r_enabled) begin
            if(r_horizontal_counter == HSYNC_LAST)
                r_horizontal_counter <= 0;
            else
                r_horizontal_counter <= r_horizontal_counter + 1;
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
    assign o_video_hsync = !r_hsync;


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
        if(r_enabled && r_horizontal_counter == HSYNC_LAST) begin
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
    assign o_video_vsync = !r_vsync;

    // transfer falling edge of r_vertical_video_on into single clock pulse in master clock domain
    reg[2:0]    xd_switch_allowed = 3'b0;

    always @(posedge i_master_clk)
        xd_switch_allowed <= { xd_switch_allowed[1:0], r_vertical_video_on };

    assign o_system_switch_allowed = (xd_switch_allowed[2]==1 && xd_switch_allowed[1]==0);


    // ***********************************************
    // **                                           **
    // **   SCANLINE PREFETCH                       **
    // **                                           **
    // ***********************************************

    // prefetch is active
    reg r_prefetch_active = 0;

    // -- signal: next row is the first row displayed
    wire w_next_row_is_first = (r_vertical_counter == VSYNC_PULSE + VSYNC_BACK_PORCH - 2);

    // -- signal: next row is the last row displayed
    wire w_next_row_is_last = (r_vertical_counter == VSYNC_PULSE + VSYNC_BACK_PORCH + 600 - 2);

    always @(posedge i_pixel_clk) begin
        if(w_next_row_is_first)
            r_prefetch_active <= 1;
        if(w_next_row_is_last)
            r_prefetch_active <= 0;
    end


    // prefetch trigger (4 pixel cycles strobe)
    reg r_prefetch_strobe = 0;

    // -- signals: strobe start & end
    wire w_prefetch_start = (r_horizontal_counter == HSYNC_PULSE + HSYNC_BACK_PORCH + HSYNC_WIDTH);
    wire w_prefetch_strobe_end = (r_horizontal_counter == HSYNC_PULSE + HSYNC_BACK_PORCH + HSYNC_WIDTH + 4);

    always @(posedge i_pixel_clk) begin
        if(r_prefetch_active && w_prefetch_start)
            r_prefetch_strobe <= 1;
        if(r_prefetch_active && w_prefetch_strobe_end)
            r_prefetch_strobe <= 0;
    end

    // transfer DISPLAY BANK to pixel clock domain
    reg[1:0] xd_video_bank = 2'b00;

    always @(posedge i_pixel_clk)
        xd_video_bank <= { xd_video_bank[0], i_system_bank };


    // prefetch row start address (latched with riging edge of r_prefetch_strobe, address of the row that is about to be displayed)
    reg[19:0] r_prefetch_address = 20'b0;

    always @(posedge i_pixel_clk) begin
        if(r_prefetch_active && w_prefetch_start) begin
            if(w_next_row_is_first)
                r_prefetch_address <= { xd_video_bank[1], 19'b0 };
            else
                r_prefetch_address <= r_prefetch_address + 512;
        end
    end

    // ***********************************************
    // **                                           **
    // **  PREFETCH LINE BUFFER                     **
    // **                                           **
    // ***********************************************

    // buffer memory
    reg[23:0]   r_buffer_memory[511:0];


    // buffer reading (pixel clock domain)
    reg[23:0]   r_buffer_read_data;

    always @(posedge i_pixel_clk)
        if(r_cache_read_enable)
            r_buffer_read_data <= r_buffer_memory[r_cache_read_counter[9:1]];

    // buffer writing
    always @(posedge i_master_clk)
        if(i_vram_display_data_valid)
            r_buffer_memory[i_vram_display_column] <= i_vram_display_data;

    // transfer signals to VRAM to master clock domain
    reg[19:0] xd_vram_read_address_0 = 0;
    reg[19:0] xd_vram_read_address_1 = 0;

    always @(posedge i_master_clk) begin
        xd_vram_read_address_1 <= xd_vram_read_address_0;
        xd_vram_read_address_0 <= r_prefetch_address;
    end

    assign o_vram_display_address = xd_vram_read_address_1;

    reg[2:0] xd_vram_read_start = 3'b0;
    reg r_vram_read_start = 0;

    always @(posedge i_master_clk) begin
        xd_vram_read_start <= { xd_vram_read_start[1:0], r_prefetch_strobe };
        r_vram_read_start <= !xd_vram_read_start[2] && xd_vram_read_start[1];
    end

    assign o_vram_display_start = r_vram_read_start;

    // ***********************************************
    // **                                           **
    // **  VIDEO DATA GENERATOR                     **
    // **                                           **
    // ***********************************************

    // signal: cache first pixel
    wire        w_cache_pixel_first = r_vertical_video_on && (r_horizontal_counter == HSYNC_PULSE + HSYNC_BACK_PORCH - 5);
    // signal: cache last pixel
    wire        w_cache_pixel_last = r_vertical_video_on && (r_horizontal_counter == HSYNC_PULSE + HSYNC_BACK_PORCH + HSYNC_WIDTH - 5);

    // cache read address
    reg[9:0]    r_cache_read_counter ;

    always @(posedge i_pixel_clk) begin
        if(w_cache_pixel_first)
            r_cache_read_counter <= 0;
        if(r_cache_read_active)
            r_cache_read_counter <= r_cache_read_counter + 1;

    end

    // cache read active
    reg         r_cache_read_active  = 0;

    always @(posedge i_pixel_clk) begin
        if(w_cache_pixel_first)
            r_cache_read_active <= 1;
        if(w_cache_pixel_last)
            r_cache_read_active <= 0;
    end

    // cache read enable
    reg         r_cache_read_enable = 0;

    always @(posedge i_pixel_clk) 
        r_cache_read_enable <= (r_cache_read_active && r_cache_read_counter[0]==0);

    // pixel demuxing
    reg[3:0]    r_video_red_out;
    reg[3:0]    r_video_green_out;
    reg[3:0]    r_video_blue_out;

    always @(posedge i_pixel_clk) begin
        if (r_cache_read_counter[0]==0) begin
            r_video_red_out <= r_buffer_read_data[11:8];
            r_video_green_out <= r_buffer_read_data[7:4];
            r_video_blue_out <= r_buffer_read_data[3:0];
        end else begin
            r_video_red_out <= r_buffer_read_data[23:20];
            r_video_green_out <= r_buffer_read_data[19:16];
            r_video_blue_out <= r_buffer_read_data[15:12];
        end
    end

    // video output

    // -- signal: video on (blanking off screen area)
    wire w_video_on = r_vertical_video_on && r_horizontal_video_on && !r_video_blank;
    
    assign o_video_red = w_video_on ? r_video_red_out : 0;
    assign o_video_green =  w_video_on ? r_video_green_out : 0;
    assign o_video_blue =  w_video_on ? r_video_blue_out : 0;


    // @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    // @@                                               @@
    // @@  TO BE DELETED: blank last 168 lines          @@
    // @@                                               @@
    // @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

    wire w_next_row_is_last_displayed = (r_vertical_counter == VSYNC_PULSE + VSYNC_BACK_PORCH + 600 - 1);

    reg r_video_blank = 1;

    always @(posedge i_pixel_clk) begin
        if(w_prefetch_start && w_next_row_is_first)
            r_video_blank <= 0;
        if(w_prefetch_start && w_next_row_is_last_displayed)
            r_video_blank <= 1;
    end



endmodule    
