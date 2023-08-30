
module VideoRowBuffer #(parameter flip = 0)
    (
        // clock
        i_pixel_clk,
        i_master_clk,

        // SYSTEM CONTROLLER interface (master clock domain)
        i_system_rendering_mode,
        
        // BUFFER CONTROLLER interface (master clock domain)
        i_buffer_display_bank,

        // VIDEO TIMING CONTROLLER interface (pixel clock domain)
        i_video_timing_pixel_first,
        i_video_timing_pixel_last,
        i_video_timing_blank,
        i_video_timing_prefetch_start,
        i_video_timing_prefetch_strobe_end,
        i_video_timing_prefetch_row_first_render,
        i_video_timing_prefetch_row_last_render,

        // VRAM CONTROLLER interface (master clock domain)
        o_display_address,
        o_display_start,
        i_display_column,
        i_display_data,
        i_display_data_valid,

        // VIDEO DECODER interface (master clock domain)
        o_video_display_start_frame,
        o_video_display_start_line,
        i_video_display_column,
        i_video_display_data,
        i_video_display_data_valid,

        // VIDEO OUTPUT (pixel clock domain)
        o_video_red,
        o_video_green,
        o_video_blue

    );

    input           i_pixel_clk;
    input           i_master_clk;

    input[1:0]      i_system_rendering_mode;

    input           i_buffer_display_bank;

    input           i_video_timing_pixel_first;
    input           i_video_timing_pixel_last;
    input           i_video_timing_blank;
    input           i_video_timing_prefetch_start;
    input           i_video_timing_prefetch_strobe_end;
    input           i_video_timing_prefetch_row_first_render;
    input           i_video_timing_prefetch_row_last_render;

    output[19:0]    o_display_address;
    output          o_display_start;
    input[8:0]      i_display_column;
    input[23:0]     i_display_data;
    input           i_display_data_valid;

    output          o_video_display_start_frame;
    output          o_video_display_start_line;
    input[8:0]      i_video_display_column;
    input[23:0]     i_video_display_data;
    input           i_video_display_data_valid;

    output[3:0]     o_video_red;
    output[3:0]     o_video_green;
    output[3:0]     o_video_blue;

    // ***********************************************
    // **                                           **
    // **   BUFFER MEMORY                           **
    // **                                           **
    // ***********************************************

    reg[23:0] memory[511:0];

    // ***********************************************
    // **                                           **
    // **   READING ROW BUFFER                      **
    // **                                           **
    // ***********************************************

    // cache read address
    reg[9:0]    r_cache_read_counter ;

    always @(posedge i_pixel_clk) begin

        if(i_video_timing_pixel_first)
            r_cache_read_counter <= 0;

        if(r_cache_read_active)
            r_cache_read_counter <= r_cache_read_counter + 1;

    end

    // cache read active
    reg         r_cache_read_active  = 0;

    always @(posedge i_pixel_clk) begin

        if(i_video_timing_pixel_first)
            r_cache_read_active <= 1;

        if(i_video_timing_pixel_last)
            r_cache_read_active <= 0;

    end

    // cache read enable
    reg         r_cache_read_enable = 0;

    always @(posedge i_pixel_clk) 
        r_cache_read_enable <= (r_cache_read_active && (r_cache_read_counter[0]==0));

    // pixel demuxing
    reg[3:0]    r_video_red_out;
    reg[3:0]    r_video_green_out;
    reg[3:0]    r_video_blue_out;

    wire[8:0]   w_video_tupple_address;
    if (flip == 0) begin
        // normal version
         assign w_video_tupple_address = (i_system_rendering_mode == 1)
            ? r_cache_read_counter[9:1]
            : { 1'b0, !r_cache_read_counter[8], r_cache_read_counter[7:1] };
    end else begin
        // flipped version
        assign w_video_tupple_address = (i_system_rendering_mode == 1)
            ? 1023 - r_cache_read_counter[9:1]
            : { 1'b0, !r_cache_read_counter[8], r_cache_read_counter[7:1] };
    end

    reg[23:0]   r_video_tupple;
    reg         r_video_tupple_blank;

    always @(posedge i_pixel_clk) begin
        if(r_cache_read_enable) begin
            r_video_tupple <= memory[w_video_tupple_address];
            r_video_tupple_blank <= (i_system_rendering_mode==0) || ((i_system_rendering_mode==2) && r_row_buffer_valid && (r_cache_read_counter[9]==r_cache_read_counter[8]));
        end
    end

    if (flip == 0) begin
        // normal version
        always @(negedge i_pixel_clk) begin
            r_video_red_out     <= (i_video_timing_blank || r_video_tupple_blank)
                ? 4'h0
                : (r_cache_read_counter[0]
                    ? r_video_tupple[15:12]
                    : r_video_tupple[3:0]
                    );
            r_video_green_out     <= (i_video_timing_blank || r_video_tupple_blank)
                ? 4'h0
                : (r_cache_read_counter[0]
                    ? r_video_tupple[19:16]
                    : r_video_tupple[7:4]
                    );
            r_video_blue_out     <= (i_video_timing_blank || r_video_tupple_blank)
                ? 4'h0
                : (r_cache_read_counter[0]
                    ? r_video_tupple[23:20]
                    : r_video_tupple[11:8]
                    );
        end
    end else begin
        // flipped version
        always @(negedge i_pixel_clk) begin
            r_video_red_out     <= (i_video_timing_blank || r_video_tupple_blank)
                ? 4'h0
                : (!r_cache_read_counter[0]
                    ? r_video_tupple[15:12]
                    : r_video_tupple[3:0]
                    );
            r_video_green_out     <= (i_video_timing_blank || r_video_tupple_blank)
                ? 4'h0
                : (!r_cache_read_counter[0]
                    ? r_video_tupple[19:16]
                    : r_video_tupple[7:4]
                    );
            r_video_blue_out     <= (i_video_timing_blank || r_video_tupple_blank)
                ? 4'h0
                : (!r_cache_read_counter[0]
                    ? r_video_tupple[23:20]
                    : r_video_tupple[11:8]
                    );
        end
    end

    assign o_video_red = r_video_red_out;
    assign o_video_green = r_video_green_out;
    assign o_video_blue = r_video_blue_out;

    // ***********************************************
    // **                                           **
    // **   RENDERER MODE PREFETCH                  **
    // **                                           **
    // ***********************************************

    // buffer valid
    reg     r_row_buffer_valid = 0;

    // buffer writing
    always @(posedge i_master_clk) begin
        if(r_prefetch_strobe) begin
            r_row_buffer_valid <= 1'b0;
        end
        if(i_display_data_valid && (i_system_rendering_mode==1)) begin
            memory[i_display_column] <= i_display_data;
            r_row_buffer_valid <= 1'b1;
        end else if(i_video_display_data_valid && (i_system_rendering_mode==2)) begin
            memory[i_video_display_column] <= i_video_display_data;
            r_row_buffer_valid <= 1'b1;
        end
    end


    // transfer signals to VRAM to master clock domain
    reg[19:0] xd_vram_read_address_0 = 0;
    reg[19:0] xd_vram_read_address_1 = 0;

    always @(posedge i_master_clk) begin
        xd_vram_read_address_1 <= xd_vram_read_address_0;
        xd_vram_read_address_0 <= r_prefetch_address;
    end

    assign o_display_address = xd_vram_read_address_1;

    reg[2:0] xd_vram_read_start = 3'b0;
    reg r_vram_read_start = 0;
    reg r_video_decode_start = 0;

    always @(posedge i_master_clk) begin
        xd_vram_read_start <= { xd_vram_read_start[1:0], r_prefetch_strobe };
        r_vram_read_start <= !xd_vram_read_start[2] && xd_vram_read_start[1] && (i_system_rendering_mode==1);
        r_video_decode_start <= !xd_vram_read_start[2] && xd_vram_read_start[1] && (i_system_rendering_mode==2);
    end

    assign o_display_start = r_vram_read_start;
    assign o_video_display_start_line = r_video_decode_start;

    // prefetch is active
    reg r_prefetch_active = 0;

    always @(posedge i_pixel_clk) begin
        if((i_system_rendering_mode!=0) && i_video_timing_prefetch_row_first_render)
            r_prefetch_active <= 1;
        if((i_system_rendering_mode!=0) && i_video_timing_prefetch_row_last_render)
            r_prefetch_active <= 0;
    end

    // prefetch trigger (4 pixel cycles strobe)
    reg r_prefetch_strobe = 0;

    always @(posedge i_pixel_clk) begin
        if(r_prefetch_active && i_video_timing_prefetch_start)
            r_prefetch_strobe <= 1;
        if(r_prefetch_active && i_video_timing_prefetch_strobe_end)
            r_prefetch_strobe <= 0;
    end

    // transfer DISPLAY BANK to pixel clock domain
    reg[1:0] xd_video_bank = 2'b00;

    always @(posedge i_pixel_clk)
        xd_video_bank <= { xd_video_bank[0], i_buffer_display_bank };


    // prefetch row start address (latched with riging edge of r_prefetch_strobe, address of the row that is about to be displayed)
    reg[19:0] r_prefetch_address = 20'b0;

    always @(posedge i_pixel_clk) begin
        if(r_prefetch_active && i_video_timing_prefetch_start) begin
            if(i_video_timing_prefetch_row_first_render)
                r_prefetch_address <= { xd_video_bank[1], 19'b0 };
            else
                r_prefetch_address <= r_prefetch_address + 512;
        end
    end


endmodule
