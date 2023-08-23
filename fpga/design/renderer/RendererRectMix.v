
module RendererRectMix(
        // clock
        i_master_clk,

        // line coordinates
        i_cmd_coord_x1,
        i_cmd_coord_x2,
        i_line_address,

        // COLOR MIXER interface
        o_mixer_original_red,
        o_mixer_original_green,
        o_mixer_original_blue,
        i_mixer_final_red,
        i_mixer_final_green,
        i_mixer_final_blue,

        // RENDERER interface
        i_process_start,
        o_process_done,

        // BUFFER CONTROLLER interface
        i_buffer_bank,

        // VIDEO RAM READ interface
        o_vram_read_address,
        o_vram_read_request,
        i_vram_read_data,
        i_vram_read_data_valid,

        // VIDEO RAM WRITE interface
        o_vram_write_address,
        o_vram_write_data,
        o_vram_write_request,
        i_vram_write_done

    );

    input           i_master_clk;

    input[9:0]      i_cmd_coord_x1;
    input[9:0]      i_cmd_coord_x2;
    input[9:0]      i_line_address;

    output[3:0]     o_mixer_original_red;
    output[3:0]     o_mixer_original_green;
    output[3:0]     o_mixer_original_blue;
    input[3:0]      i_mixer_final_red;
    input[3:0]      i_mixer_final_green;
    input[3:0]      i_mixer_final_blue;

    input           i_process_start;
    output          o_process_done;

    input           i_buffer_bank;

    output[19:0]    o_vram_read_address;
    output          o_vram_read_request;
    input[23:0]     i_vram_read_data;
    input           i_vram_read_data_valid;

    output[19:0]    o_vram_write_address;
    output[23:0]    o_vram_write_data;
    output          o_vram_write_request;
    input           i_vram_write_done;

    // ***********************************************
    // **                                           **
    // **   STATE MACHINE                           **
    // **                                           **
    // ***********************************************

    localparam STATE_IDLE                   = 0;
    localparam STATE_READ_TUPPLE            = 1;
    localparam STATE_READ_TUPPLE_WAIT       = 2;
    localparam STATE_MIX_PIXEL_LO           = 3;
    localparam STATE_MIX_PIXEL_HI           = 4;
    localparam STATE_MIX_WAIT1              = 5;
    localparam STATE_MIX_WAIT2              = 6;
    localparam STATE_MIX_WAIT3              = 7;
    localparam STATE_MIX_WAIT4              = 8;
    localparam STATE_WRITE_TUPPLE           = 9;
    localparam STATE_WRITE_TUPPLE_WAIT      = 10;
    localparam STATE_DONE                   = 11;

    reg[3:0]        r_state = STATE_IDLE;
    reg[3:0]        w_next_state;

    always @(*) begin
        w_next_state = r_state;

        case (r_state)

            STATE_IDLE: begin
                if (i_process_start)
                    w_next_state = STATE_READ_TUPPLE;
            end

            STATE_READ_TUPPLE:      w_next_state = STATE_READ_TUPPLE_WAIT;
            STATE_MIX_PIXEL_LO:     w_next_state = STATE_MIX_PIXEL_HI;
            STATE_MIX_PIXEL_HI:     w_next_state = STATE_MIX_WAIT1;
            STATE_MIX_WAIT1:        w_next_state = STATE_MIX_WAIT2;
            STATE_MIX_WAIT2:        w_next_state = STATE_MIX_WAIT3;
            STATE_MIX_WAIT3:        w_next_state = STATE_MIX_WAIT4;
            STATE_MIX_WAIT4:        w_next_state = STATE_WRITE_TUPPLE;
            STATE_WRITE_TUPPLE:     w_next_state = STATE_WRITE_TUPPLE_WAIT;
            STATE_DONE:             w_next_state = STATE_IDLE;

            STATE_READ_TUPPLE_WAIT: begin
                if (i_vram_read_data_valid)
                    w_next_state = STATE_MIX_PIXEL_LO;
            end

            STATE_WRITE_TUPPLE_WAIT: begin
                if (i_vram_write_done) begin
                    if (r_last_tupple)
                        w_next_state = STATE_DONE;
                    else
                        w_next_state = STATE_READ_TUPPLE;
                end
            end

        endcase
    end

    always @(posedge i_master_clk)
        r_state <= w_next_state;

    // done flag
    reg     r_flag_done = 0;

    always @(posedge i_master_clk)
        r_flag_done = (w_next_state == STATE_DONE);

    assign o_process_done = r_flag_done;

    // ***********************************************
    // **                                           **
    // **   TUPPLE COUNTER & READ                   **
    // **                                           **
    // ***********************************************

    // tupple address
    reg[8:0]    r_tupple_address;

    // last tupple
    wire        w_last_tupple = (r_tupple_address == i_cmd_coord_x2[9:1]);
    reg         r_last_tupple = 0;

    // first tupple
    wire        w_first_tupple = (i_process_start || r_tupple_address == i_cmd_coord_x1[9:1]);

    always @(posedge i_master_clk) begin
        case (r_state)

            STATE_IDLE: begin
                if (i_process_start)
                    r_tupple_address <= i_cmd_coord_x1[9:1];
                r_last_tupple <= w_last_tupple;
            end

            STATE_WRITE_TUPPLE: begin
                if (!w_last_tupple)
                    r_tupple_address <= r_tupple_address + 1;
                r_last_tupple <= w_last_tupple;
            end

        endcase
    end

    assign o_vram_read_address = { i_buffer_bank, i_line_address, r_tupple_address };
    

    // ***********************************************
    // **                                           **
    // **   READ TUPPLE                             **
    // **                                           **
    // ***********************************************

    // request
    reg         r_tupple_read_request = 0;

    always @(posedge i_master_clk)
        r_tupple_read_request <= (w_next_state == STATE_READ_TUPPLE);

    assign o_vram_read_request = r_tupple_read_request;
    
    // ***********************************************
    // **                                           **
    // **   WRITE TUPPLE                            **
    // **                                           **
    // ***********************************************

    // write request
    reg         r_write_request = 0;

    always @(posedge i_master_clk)
        r_write_request <= (w_next_state == STATE_WRITE_TUPPLE);

    assign o_vram_write_request = r_write_request;
    assign o_vram_write_address = { i_buffer_bank, i_line_address, r_tupple_address };
    assign o_vram_write_data = r_tupple_value;


    // ***********************************************
    // **                                           **
    // **   COLOR MIXING                            **
    // **                                           **
    // ***********************************************

    // tupple masking
    wire    w_mask_lo = (w_first_tupple && i_cmd_coord_x1[0]==1);
    wire    w_mask_hi = (w_last_tupple && i_cmd_coord_x2[0]==0);

    // mixer input color
    reg[3:0]    r_mixer_red;
    reg[3:0]    r_mixer_green;
    reg[3:0]    r_mixer_blue;

    always @(posedge i_master_clk) begin
        case (w_next_state)

            STATE_MIX_PIXEL_LO: begin
                r_mixer_red <= i_vram_read_data[11:8];
                r_mixer_green <= i_vram_read_data[7:4];
                r_mixer_blue <= i_vram_read_data[3:0];
            end

            STATE_MIX_PIXEL_HI: begin
                r_mixer_red <= i_vram_read_data[23:20];
                r_mixer_green <= i_vram_read_data[19:16];
                r_mixer_blue <= i_vram_read_data[15:12];
            end

        endcase
    end

    assign o_mixer_original_red = r_mixer_red;
    assign o_mixer_original_green = r_mixer_green;
    assign o_mixer_original_blue = r_mixer_blue;

    // final tuple value
    reg[23:0]   r_tupple_value;

    always @(posedge i_master_clk) begin
        case (w_next_state)

            STATE_MIX_PIXEL_LO:
                r_tupple_value <= i_vram_read_data;

            STATE_MIX_WAIT4: begin
                if (!w_mask_lo) begin
                    r_tupple_value[11:8] <= i_mixer_final_red;
                    r_tupple_value[7:4] <= i_mixer_final_green;
                    r_tupple_value[3:0] <= i_mixer_final_blue;
                end
            end

            STATE_WRITE_TUPPLE: begin
                if (!w_mask_hi) begin
                    r_tupple_value[23:20] <= i_mixer_final_red;
                    r_tupple_value[19:16] <= i_mixer_final_green;
                    r_tupple_value[15:12] <= i_mixer_final_blue;
                end
            end

        endcase
    end

endmodule    
