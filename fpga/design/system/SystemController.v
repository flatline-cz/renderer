
module SystemController (
        // clock
        i_master_clk,

        // STATUS CONTROLLER interface
        o_status_rendering_mode,

        // MCU CONTROLLER interface
        i_mcu_mode,
        i_mcu_mode_valid,

        // VIDEO TIMING CONTROLLER interface
        o_video_enable,
        i_video_switch_allowed
    );

    input       i_master_clk;

    output[1:0] o_status_rendering_mode;

    input[1:0]  i_mcu_mode;
    input       i_mcu_mode_valid;

    output      o_video_enable;
    input       i_video_switch_allowed;

    // ***********************************************
    // **                                           **
    // **   RENDERING MODE & CHANGE REQUESTS        **
    // **                                           **
    // ***********************************************

    // rendering modes
    localparam MODE_OFF         = 2'h0;
    localparam MODE_NORMAL      = 2'h1;
    localparam MODE_VIDEO       = 2'h2;

    // actual rendering mode
    reg[1:0]    r_rendering_mode = MODE_OFF;

    wire        w_mode_stable = (r_state == STATE_OFF || r_state == STATE_NORMAL || r_state == STATE_VIDEO);

    always @(posedge i_master_clk) begin
        if(w_mode_stable)
            r_rendering_mode <= r_state[1:0];
    end

    assign o_status_rendering_mode = r_rendering_mode;

    // requests
    reg     r_off_mode_request = 0;
    reg     r_normal_mode_request = 0;
    reg     r_video_mode_request = 0;

    always @(posedge i_master_clk) begin
        if(w_mode_stable) begin
            if(i_mcu_mode_valid) begin
                r_off_mode_request <= (i_mcu_mode == MODE_OFF);
                r_normal_mode_request <= (i_mcu_mode == MODE_NORMAL);
                r_video_mode_request <= (i_mcu_mode == MODE_VIDEO);
            end
        end else begin
            r_off_mode_request <= 1'b0;
            r_normal_mode_request <= 1'b0;
            r_video_mode_request <= 1'b0;
        end
    end


    // ***********************************************
    // **                                           **
    // **   STATE MACHINE                           **
    // **                                           **
    // ***********************************************

    // states
    localparam STATE_OFF            = 0;
    localparam STATE_NORMAL         = 1;
    localparam STATE_VIDEO          = 2;
    localparam STATE_NORMAL_ON0     = 3;
    localparam STATE_TURN_OFF0      = 4;

    reg[2:0]    r_state = STATE_OFF;
    reg[2:0]    w_next_state;

    // state machine
    always @(*) begin
        w_next_state = r_state;

        case (r_state)

            STATE_OFF: begin
                if(r_normal_mode_request)
                    w_next_state = STATE_NORMAL_ON0;
                if(r_video_mode_request)
                    w_next_state = STATE_VIDEO;
            end

            STATE_NORMAL_ON0: begin
                if(i_video_switch_allowed)
                    w_next_state = STATE_NORMAL;
            end

            STATE_NORMAL: begin
                if(r_off_mode_request && i_video_switch_allowed)
                    w_next_state = STATE_TURN_OFF0;
                if(r_video_mode_request && i_video_switch_allowed)
                    w_next_state = STATE_VIDEO;
            end

            STATE_TURN_OFF0: begin
                if(i_video_switch_allowed)
                    w_next_state = STATE_OFF;
            end

            STATE_VIDEO: begin
                if(r_off_mode_request)
                    w_next_state = STATE_OFF;
                if(r_normal_mode_request)
                    w_next_state = STATE_NORMAL_ON0;
            end

        endcase
    end

    always @(posedge i_master_clk)
        r_state <= w_next_state;


    // ***********************************************
    // **                                           **
    // **   VIDEO TIMING CONTROL                    **
    // **                                           **
    // ***********************************************
    
    // state
    reg     r_video_timing_enabled = 0;

    always @(posedge i_master_clk)
        r_video_timing_enabled <= (r_state != STATE_OFF);

    assign o_video_enable = r_video_timing_enabled;


endmodule
