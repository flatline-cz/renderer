

module BufferController (
        // clock
        i_master_clk,

        // SYSTEM CONTROLLER interface
        i_system_rendering_mode,

        // VIDEO CONTROLLER interface
        i_video_switch_allowed,
        o_video_bank,

        // RENDER CONTROLLER interface
        o_render_bank,
        o_render_start,
        i_render_finished,

        // MCU interface
        i_queue_ready,
        o_queue_finished

    );

    input       i_master_clk;

    input[1:0]  i_system_rendering_mode;

    input       i_video_switch_allowed;
    output      o_video_bank;

    output      o_render_bank;
    output      o_render_start;
    input       i_render_finished;

    input       i_queue_ready;
    output      o_queue_finished;

    // global enable signal
    wire w_enabled = (i_system_rendering_mode == 2'h1);

    // ***********************************************
    // **                                           **
    // **   QUEUE STATE                             **
    // **                                           **
    // ***********************************************

    // queue is filled (ready to be rendered)
    reg     r_queue_filled = 0;

    always @(posedge i_master_clk) begin

        if (i_queue_ready && w_enabled) begin
            r_queue_filled <= 1;
        end 

        if (r_queue_filled && r_buffer0_rendered && r_buffer1_rendered) begin
            r_queue_filled <= 0;
        end

    end

    reg     r_queue_rendered = 0;

    always @(posedge i_master_clk)
        r_queue_rendered <= (r_queue_filled && r_buffer0_rendered && r_buffer1_rendered);

    assign o_queue_finished = r_queue_rendered;


    // ***********************************************
    // **                                           **
    // **   RENDERING                               **
    // **                                           **
    // ***********************************************

    reg     r_render_bank = 0;
    reg     r_rendering_active = 0;

    // SIGNAL: Buffer #1 can be rendered
    wire    w_buffer1_can_render = !r_rendering_active && r_queue_filled && !r_buffer0_rendered && r_video_bank;

    // SIGNAL: Buffer #2 can be rendered
    wire    w_buffer2_can_render = !r_rendering_active && r_queue_filled && !r_buffer1_rendered && !r_video_bank;

    always @(posedge i_master_clk) begin

        // possible to render buffer #1?
        if (w_buffer1_can_render) begin
            r_rendering_active <= 1;
            r_render_bank <= 0;
        end else

        // possible to render buffer #2?
        if (w_buffer2_can_render) begin
            r_rendering_active <= 1;
            r_render_bank <= 1;
        end else 

        // rendering done?
        if (r_rendering_active && i_render_finished) begin
            r_rendering_active <= 0;
        end
        
    end

    assign o_render_bank = r_render_bank;

    // trigger rendering
    reg     r_render_start = 0;

    always @(posedge i_master_clk)
        r_render_start <= (w_buffer1_can_render || w_buffer2_can_render);

    assign o_render_start = r_render_start;


    // ***********************************************
    // **                                           **
    // **   VIDEO DISPLAY                           **
    // **                                           **
    // ***********************************************

    // current buffer displayed
    reg     r_video_bank = 0;

    // SIGNAL: can switch video banks?
    wire    w_can_switch = ((r_video_bank==0) && r_buffer1_rendered && i_video_switch_allowed) || ((r_video_bank==1) && r_buffer0_rendered && i_video_switch_allowed);

    always @(posedge i_master_clk) begin
        if (w_can_switch) begin
            r_video_bank = !r_video_bank;
        end
    end

    assign o_video_bank = r_video_bank;

    // ***********************************************
    // **                                           **
    // **   BUFFER STATE                            **
    // **                                           **
    // ***********************************************

    reg     r_buffer0_rendered = 0;
    reg     r_buffer1_rendered = 0;

    always @(posedge i_master_clk) begin

        // new queue?
        if (i_queue_ready) begin
            r_buffer0_rendered <= 1'b0;
            r_buffer1_rendered <= 1'b0;
        end else

        // buffer #1 rendered?
        if (i_render_finished && (r_render_bank==0)) begin
            r_buffer0_rendered <= 1'b1;
        end else

        // buffer #2 rendered?
        if (i_render_finished && (r_render_bank==1)) begin
            r_buffer1_rendered <= 1'b1;
        end

    end


endmodule    
