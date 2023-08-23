

module StatusController (
        // clock
        i_master_clk,

        // VIDEO CONTROLLER interface (pixel clock domain)
        i_video_vsync_n,

        // SERIAL CONTROLLER interface (master clock domain)
        i_status_request,
        o_status_data,

        // BUFFER CONTROLLER interface (master clock domain)
        i_buffer_locked,

        // SYSTEM CONTROLLER interface (master clock domain)
        i_system_rendering_mode,

        // VIDEO DESCRIPTOR interface (master clock domain)
        i_video_descriptor_ready

    );

    input       i_master_clk;

    input       i_video_vsync_n;

    input       i_status_request;
    output[7:0] o_status_data;

    input       i_buffer_locked;

    input[1:0]  i_system_rendering_mode;

    input       i_video_descriptor_ready;

    // ***********************************************
    // **                                           **
    // **   VSYNC EVENT                             **
    // **                                           **
    // ***********************************************

    // transfer VSYNC from pixel to master clock domain
    reg[2:0]    xd_video_vsync = 3'b000;

    always @(posedge i_master_clk)
        xd_video_vsync <= { xd_video_vsync[1:0], ~i_video_vsync_n };

    wire w_vsync = !xd_video_vsync[2] && xd_video_vsync[1];

    reg r_vsync = 0;

    always @(posedge i_master_clk) begin
        if(w_vsync)
            r_vsync <= 1'b1;
        else if(i_status_request)
            r_vsync <= 1'b0;
    end

    // ***********************************************
    // **                                           **
    // **   Status register                         **
    // **                                           **
    // ***********************************************

    reg[7:0]    r_status = 0;

    always @(posedge i_master_clk) begin
        if(i_status_request)
            r_status <= { 1'b1, 2'b00, i_video_descriptor_ready, i_system_rendering_mode, ~i_buffer_locked, r_vsync };        
    end

    assign o_status_data = r_status;

endmodule
