
module PlaybackController (
        i_master_clk,

        // MCU CONTROLLER interface
        i_mcu_playback_address,
        i_mcu_playback_address_valid,

        // STATUS CONTROLLER interface
        o_status_playback_available,

        // VIDEO DECODER interface
        o_video_render_address,
        o_video_render_address_valid,

        // VIDEO TIMING CONTROLLER interface (pixel clock domain)
        i_video_timing_vsync

    );

    input           i_master_clk;

    input[17:0]     i_mcu_playback_address;
    input           i_mcu_playback_address_valid;

    output          o_status_playback_available;

    output[17:0]    o_video_render_address;
    output          o_video_render_address_valid;

    input           i_video_timing_vsync;

    // ***********************************************
    // **                                           **
    // **   VSYNC SYNCHRONIZER                      **
    // **                                           **
    // ***********************************************

    // cross clock domain
    reg[2:0]        xd_vsync = 3'b0;

    always @(posedge i_master_clk)
        xd_vsync <= { xd_vsync[1:0], i_video_timing_vsync };

    // edge detector
    reg             r_vsync = 0;

    always @(posedge i_master_clk)
        r_vsync <= xd_vsync[2] && !xd_vsync[1];


    // ***********************************************
    // **                                           **
    // **   FRAME BASE ADDRESS BUFFER               **
    // **                                           **
    // ***********************************************

    // next buffer
    reg[17:0]       r_base_next =0 ;
    reg             r_base_next_valid = 0;

    // one after next buffer
    reg[17:0]       r_base_after_next = 0;
    reg             r_base_after_next_valid = 0;

    // next buffer
    always @(posedge i_master_clk) begin
        if(r_vsync && r_base_after_next_valid) begin
            r_base_next_valid <= 1'b1;
            r_base_next <= r_base_after_next;
        end
    end

    // after next buffer
    always @(posedge i_master_clk) begin
        if(i_mcu_playback_address_valid) begin
            r_base_after_next <= i_mcu_playback_address;
            r_base_after_next_valid <= 1'b1;
        end else if(r_vsync) begin
            r_base_after_next_valid <= 1'b0;
        end
    end

    // buffer available flag
    reg         r_buffer_available = 0;

    always @(posedge i_master_clk)
        r_buffer_available <= !r_base_after_next_valid;

    assign o_status_playback_available = r_buffer_available;


    // ***********************************************
    // **                                           **
    // **   FRAME BASE ADDRESS PULL OUT             **
    // **                                           **
    // ***********************************************

    reg             r_render_address_valid = 0;

    always @(posedge i_master_clk) begin
        if(r_vsync) begin
            r_render_address_valid <= 1'b1;
        end else begin
            r_render_address_valid <= 1'b0;
        end
    end

    assign o_video_render_address = r_base_next;
    assign o_video_render_address_valid = r_render_address_valid;


endmodule
