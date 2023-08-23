
module CommandProcessor (
        // master clock domain
        i_master_clk,

        // BUFFER CONTROLLER interface (master clock domain)
        i_process_start,
        o_process_done,

        // COMMAND QUEUE interface (master clock domain)
        o_queue_request,
        i_queue_data,
        i_queue_data_valid,
        i_queue_eof,

        // RENDERER interface
        o_cmd_valid,
        i_cmd_finished,
        o_cmd_x1,
        o_cmd_y1,
        o_cmd_x2,
        o_cmd_y2,
        o_cmd_color_r,
        o_cmd_color_g,
        o_cmd_color_b,
        o_cmd_color_a,
        o_cmd_textured,
        o_cmd_texture_packed,
        o_cmd_texture_copy,
        o_cmd_texture_base,
        o_cmd_texture_stripe,

        // DEBUG interface
        dbg_rendering

    );

    input           i_master_clk;

    input           i_process_start;
    output          o_process_done;

    output          o_queue_request;
    input[7:0]      i_queue_data;
    input           i_queue_data_valid;
    input           i_queue_eof;

    output          o_cmd_valid;
    input           i_cmd_finished;
    output[9:0]     o_cmd_x1;
    output[9:0]     o_cmd_y1;
    output[9:0]     o_cmd_x2;
    output[9:0]     o_cmd_y2;
    output[3:0]     o_cmd_color_r;
    output[3:0]     o_cmd_color_g;
    output[3:0]     o_cmd_color_b;
    output[3:0]     o_cmd_color_a;
    output          o_cmd_textured;
    output          o_cmd_texture_packed;
    output          o_cmd_texture_copy;
    output[19:0]    o_cmd_texture_base;
    output[9:0]     o_cmd_texture_stripe;

    output reg      dbg_rendering;

    // ***********************************************
    // **                                           **
    // **   COMMAND FETCHER                         **
    // **                                           **
    // ***********************************************

    // states
    localparam STATE_FETCH_IDLE             = 0;
    localparam STATE_FETCH_START            = 1;
    localparam STATE_FETCH_REQUEST          = 2;
    localparam STATE_FETCH_WAIT             = 3;
    localparam STATE_FETCH_PROCESS_START    = 4;
    localparam STATE_FETCH_PROCESS_WAIT     = 5;
    localparam STATE_FETCH_DONE             = 6;

    // state machine
    reg[2:0]    r_fetch_state = STATE_FETCH_IDLE;
    reg[2:0]    w_next_fetch_state;

    always @(*) begin
        w_next_fetch_state = r_fetch_state;

        case (r_fetch_state)

            STATE_FETCH_IDLE: begin
                if(i_process_start)
                    w_next_fetch_state = STATE_FETCH_START;
            end

            STATE_FETCH_START:
                w_next_fetch_state = STATE_FETCH_REQUEST;

            STATE_FETCH_REQUEST:
                w_next_fetch_state = STATE_FETCH_WAIT;

            STATE_FETCH_WAIT: begin
                if(i_queue_data_valid) begin
                    if(i_queue_eof)
                        w_next_fetch_state = STATE_FETCH_DONE;
                    else if(w_last_byte)
                        w_next_fetch_state = STATE_FETCH_PROCESS_START;
                    else
                        w_next_fetch_state = STATE_FETCH_REQUEST;
                end
            end

            STATE_FETCH_PROCESS_START:
                w_next_fetch_state = STATE_FETCH_PROCESS_WAIT;

            STATE_FETCH_PROCESS_WAIT: begin
                if(i_cmd_finished)
                    w_next_fetch_state = STATE_FETCH_START;
            end

            STATE_FETCH_DONE:
                w_next_fetch_state = STATE_FETCH_IDLE;

        endcase

    end

    always @(posedge i_master_clk)
        r_fetch_state <= w_next_fetch_state;

    // queue fetch request
    reg     r_queue_request = 0;

    always @(posedge i_master_clk)
        r_queue_request <= (w_next_fetch_state == STATE_FETCH_REQUEST);

    assign o_queue_request = r_queue_request;


    // queue processed flag
    reg     r_queue_finished = 0;

    always @(posedge i_master_clk)
        r_queue_finished <= r_fetch_state == STATE_FETCH_DONE;

    assign o_process_done = r_queue_finished;

    // command ready flag
    reg     r_cmd_ready = 0;

    always @(posedge i_master_clk)
        r_cmd_ready <= r_fetch_state == STATE_FETCH_PROCESS_START;

    assign o_cmd_valid = r_cmd_ready;

    // rendering flag
    always @(posedge i_master_clk)
        dbg_rendering <= r_fetch_state != STATE_FETCH_IDLE;

    // ***********************************************
    // **                                           **
    // **   COMMAND DECODER                         **
    // **                                           **
    // ***********************************************

    // command content
    reg[9:0]    r_cmd_x1;
    reg[9:0]    r_cmd_y1;
    reg[9:0]    r_cmd_x2;
    reg[9:0]    r_cmd_y2;
    reg[3:0]    r_cmd_color_r;
    reg[3:0]    r_cmd_color_g;
    reg[3:0]    r_cmd_color_b;
    reg[3:0]    r_cmd_color_a;
    reg         r_cmd_textured = 0;
    reg         r_cmd_texture_packed;
    reg         r_cmd_texture_copy;
    reg[9:0]    r_cmd_texture_stripe;
    reg[19:0]   r_cmd_texture_base;

    // byte counter
    reg[3:0]    r_cmd_byte;

    always @(posedge i_master_clk) begin

        case (r_fetch_state)

            STATE_FETCH_START: 
                r_cmd_byte <= 0;

            STATE_FETCH_WAIT: begin
                if(i_queue_data_valid && !w_last_byte)
                    r_cmd_byte <= r_cmd_byte + 1;
            end
            
        endcase

    end

    // SIGNAL: last byte of the command
    wire        w_last_byte = r_cmd_textured
        ? (r_cmd_texture_packed
            ? (r_cmd_byte == 11) 
            : (r_cmd_byte == 9))
        : (r_cmd_byte == 7);

    // decode command
    always @(posedge i_master_clk) begin
        if((r_fetch_state == STATE_FETCH_WAIT) && i_queue_data_valid) begin
            case (r_cmd_byte)

                4'h0:
                    r_cmd_y1[7:0] <= i_queue_data;

                4'h1:
                    r_cmd_x1[7:0] <= i_queue_data;

                4'h2:
                    r_cmd_y2[7:0] <= i_queue_data;

                4'h3:
                    r_cmd_x2[7:0] <= i_queue_data;

                4'h4: begin
                    r_cmd_y1[9:8] <= i_queue_data[1:0];
                    r_cmd_x1[9:8] <= i_queue_data[3:2];
                    r_cmd_y2[9:8] <= i_queue_data[5:4];
                    r_cmd_x2[9:8] <= i_queue_data[7:6];
                end

                4'h5: begin
                    r_cmd_textured <= i_queue_data[0];
                    r_cmd_texture_copy <= i_queue_data[0] && i_queue_data[1];
                    r_cmd_texture_packed <= i_queue_data[0] && !i_queue_data[2];
                    r_cmd_texture_stripe[9:8] <= i_queue_data[7:6];
                end

                4'h6: begin
                    if(r_cmd_textured) begin
                        r_cmd_texture_stripe[7:0] <= i_queue_data;
                    end else begin
                        r_cmd_color_g <= i_queue_data[7:4];
                        r_cmd_color_r <= i_queue_data[3:0];
                    end
                end

                4'h7: begin
                    if(r_cmd_textured) begin
                        r_cmd_texture_base[7:0] <= i_queue_data;
                    end else begin
                        r_cmd_color_a <= i_queue_data[7:4];
                        r_cmd_color_b <= i_queue_data[3:0];
                    end
                end
                
                4'h8:
                    r_cmd_texture_base[15:8] <= i_queue_data;

                4'h9:
                    r_cmd_texture_base[19:16] <= i_queue_data[3:0]; 

                4'ha: begin
                    r_cmd_color_g <= i_queue_data[7:4];
                    r_cmd_color_r <= i_queue_data[3:0];
                end

                4'hb: begin
                    r_cmd_color_a <= 0;
                    r_cmd_color_b <= i_queue_data[3:0];
                end

            endcase
        end
    end

    assign o_cmd_x1             = r_cmd_x1;
    assign o_cmd_y1             = r_cmd_y1;
    assign o_cmd_x2             = r_cmd_x2;
    assign o_cmd_y2             = r_cmd_y2;
    assign o_cmd_color_r        = r_cmd_color_r;
    assign o_cmd_color_g        = r_cmd_color_g;
    assign o_cmd_color_b        = r_cmd_color_b;
    assign o_cmd_color_a        = r_cmd_color_a;
    assign o_cmd_textured       = r_cmd_textured;
    assign o_cmd_texture_packed = r_cmd_texture_packed;
    assign o_cmd_texture_copy   = r_cmd_texture_copy;
    assign o_cmd_texture_base   = r_cmd_texture_base;
    assign o_cmd_texture_stripe = r_cmd_texture_stripe;
    


endmodule
