
module VideoDataController(
        // clocks
        i_pixel_clk,
        i_master_clk,

        // SYSTEM CONTROLLER interface (master clock domain)
        i_system_video_bank,
        i_system_rendering_mode,

        // VIDEO TIMING CONTROLLER interface (pixel clock domain)
        i_video_horizontal_on,
        i_video_vertival_on,
        i_video_blank,
        i_video_prefetch

        // VIDEO output (pixel clock domain)
        o_video_red,
        o_video_green,
        o_video_blue,

        // MEMORY ARBITER interface (master clock domain)
        o_vram_display_address,
        o_vram_display_start,
        i_vram_display_column,
        i_vram_display_data,
        i_vram_display_data_valid,

        // VIDEO DECODER interface (master clock domain)
        o_video_display_start,
        i_video_display_column,
        i_video_display_data,
        i_video_display_data_valid

    );



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
    wire w_video_on = i_video_vertival_on && i_video_horizontal_on && !i_video_blank;
    
    assign o_video_red = w_video_on ? r_video_red_out : 0;
    assign o_video_green =  w_video_on ? r_video_green_out : 0;
    assign o_video_blue =  w_video_on ? r_video_blue_out : 0;


endmodule
