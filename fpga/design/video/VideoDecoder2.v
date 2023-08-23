
module VideoDecoder (
        i_master_clk,

        // VIDEO PLAYBACK CONTROLLER
        i_playback_address,
        i_playback_address_valid,

        // VIDEO ROW BUFFER interface
        i_video_start,
        o_video_column,
        o_video_data,
        o_video_data_valid,

        // VRAM CONTROLLER interface
        o_vram_read_address,
        o_vram_read_request,
        i_vram_read_data,
        i_vram_read_data_valid

    );

    input               i_master_clk;

    input[17:0]         i_playback_address;
    input               i_playback_address_valid;

    input               i_video_start;
    output[8:0]         o_video_column;
    output reg[23:0]    o_video_data;
    output              o_video_data_valid;

    output[17:0]        o_vram_read_address;
    output reg          o_vram_read_request = 0;
    input[15:0]         i_vram_read_data;
    input               i_vram_read_data_valid;

    // ***********************************************
    // **                                           **
    // **   DECODER STATE MACHINE                   **
    // **                                           **
    // ***********************************************

    localparam STATE_IDLE           = 0;
    localparam STATE_DECODE         = 1;
    localparam STATE_FILL           = 2;
    localparam STATE_CONSUME        = 3;
    localparam STATE_CONTINUE       = 4;

    reg[3:0]        r_state = STATE_IDLE;

    always @(posedge i_master_clk) begin
        
        // start?
        if((r_state == STATE_IDLE) && i_video_start)
            r_state <= STATE_DECODE;
        
        // decoded?
        if((r_state == STATE_DECODE) && w_inst_complete)
            r_state <= STATE_FILL;

        // filled?
        if(r_state == STATE_FILL) begin
            if(w_last_column || w_last_pixel) begin
                r_state <= STATE_CONSUME;
            end
        end

        // consumed?
        if(r_state == STATE_CONSUME) begin
            if(w_last_column)
                r_state <= STATE_IDLE;
            else
                r_state <= STATE_DECODE;
        end

        // waiting for continuation?
        if((r_state == STATE_CONTINUE) && i_video_start) begin
            r_state <= STATE_FILL;
        end
    end


    // ***********************************************
    // **                                           **
    // **   INSTRUCTION REGISTER HANDLING           **
    // **                                           **
    // ***********************************************

    // current instruction
    reg[15:0]   r_instruction;
    reg[4:0]    r_instruction_bits;

    // next cache
    reg[15:0]   r_next_cache;
    reg[4:0]    r_next_cache_bits;

    always @(posedge i_master_clk) begin


        // initialize?
        if(i_playback_address_valid) begin
            r_next_cache_bits <= 0;
            r_instruction_bits <= 0;
        end

        // cache filled?
        if((r_fetch_state == STATE_FETCH_WAIT) && i_vram_read_data_valid) begin
            r_next_cache <= i_vram_read_data;
            r_next_cache_bits <= 16;
        end
        
        // refill bits from from cache
        if((r_state == STATE_DECODE) && (r_fetch_state == STATE_FETCH_IDLE)) begin

            case (r_instruction_bits)

                5'h0: r_instruction[15:0] <= r_next_cache[15:0];
                5'h1: begin
                    r_instruction[14:0] <= r_next_cache[15:1];
                    r_next_cache[15:15] <= r_next_cache[0:0]; 
                end
                5'h2: begin
                    r_instruction[13:0] <= r_next_cache[15:2];
                    r_next_cache[15:14] <= r_next_cache[1:0];
                end
                5'h3: begin
                    r_instruction[12:0] <= r_next_cache[15:3];
                    r_next_cache[15:13] <= r_next_cache[2:0];
                end
                5'h4: begin
                    r_instruction[11:0] <= r_next_cache[15:4];
                    r_next_cache[15:12] <= r_next_cache[3:0];
                end
                5'h5: begin
                    r_instruction[10:0] <= r_next_cache[15:5];
                    r_next_cache[15:11] <= r_next_cache[4:0];
                end
                5'h6: begin
                    r_instruction[9:0] <= r_next_cache[15:6];
                    r_next_cache[15:10] <= r_next_cache[5:0];
                end
                5'h7: begin
                    r_instruction[8:0] <= r_next_cache[15:7];
                    r_next_cache[15:9] <= r_next_cache[6:0];
                end
                5'h8: begin
                    r_instruction[7:0] <= r_next_cache[15:8];
                    r_next_cache[15:8] <= r_next_cache[7:0];
                end
                5'h9: begin
                    r_instruction[6:0] <= r_next_cache[15:9];
                    r_next_cache[15:7] <= r_next_cache[8:0];
                end
                5'ha: begin
                    r_instruction[5:0] <= r_next_cache[15:10];
                    r_next_cache[15:6] <= r_next_cache[9:0];
                end
                5'hb: begin
                    r_instruction[4:0] <= r_next_cache[15:11];
                    r_next_cache[15:5] <= r_next_cache[10:0];
                end
                5'hc: begin
                    r_instruction[3:0] <= r_next_cache[15:12];
                    r_next_cache[15:4] <= r_next_cache[11:0];
                end
                5'hd: begin
                    r_instruction[2:0] <= r_next_cache[15:13];
                    r_next_cache[15:3] <= r_next_cache[12:0];
                end
                5'he: begin
                    r_instruction[1:0] <= r_next_cache[15:14];
                    r_next_cache[15:2] <= r_next_cache[13:0];
                end
                5'hf: begin
                    r_instruction[0:0] <= r_next_cache[15:15];
                    r_next_cache[15:1] <= r_next_cache[14:0];
                end

            endcase

            r_instruction_bits <= r_instruction_bits + w_instruction_pulled_bits;
            r_next_cache_bits <= r_next_cache_bits - w_instruction_pulled_bits;
        end

        // consume bits
        if(r_state == STATE_CONSUME) begin

            case (r_inst_combined)

                5'b10000: r_instruction[15:5] <= r_instruction[10:0];

                5'b01000: r_instruction[15:10] <= r_instruction[5:0];

                5'b00100: r_instruction[15] <= r_instruction[0];

                5'b00010: r_instruction[15:8] <= r_instruction[7:0];

                5'b00001: r_instruction[15:13] <= r_instruction[2:0];

            endcase

            case (r_inst_combined)
                5'b10000: r_instruction_bits <= r_instruction_bits - 5;
                5'b01000: r_instruction_bits <= r_instruction_bits - 10;
                5'b00100: r_instruction_bits <= r_instruction_bits - 15;
                5'b00010: r_instruction_bits <= r_instruction_bits - 8;
                5'b00001: r_instruction_bits <= r_instruction_bits - 13;
            endcase
        end

    end

    // update bit counts
    wire[4:0]   w_instruction_missing_bits = 16 - r_instruction_bits;
    wire[4:0]   w_instruction_pulled_bits = (w_instruction_missing_bits < r_next_cache_bits) 
        ? w_instruction_missing_bits 
        : r_next_cache_bits;


    // ***********************************************
    // **                                           **
    // **   INSTRUCTION FETCHING                    **
    // **                                           **
    // ***********************************************


    // SIGNAL: need data
    wire        w_fetch_need_data = (r_next_cache_bits == 0) && (r_state == STATE_DECODE);

    // fetching state machine
    localparam  STATE_FETCH_IDLE        = 0;
    localparam  STATE_FETCH_REQUEST     = 1;
    localparam  STATE_FETCH_WAIT        = 2;

    reg[1:0]    r_fetch_state = STATE_FETCH_IDLE;

    always @(posedge i_master_clk) begin

        case (r_fetch_state)

            STATE_FETCH_IDLE: begin
                if(w_fetch_need_data)
                    r_fetch_state <= STATE_FETCH_REQUEST;
            end

            STATE_FETCH_REQUEST:
                r_fetch_state <= STATE_FETCH_WAIT;

            STATE_FETCH_WAIT: begin
                if(i_vram_read_data_valid)
                    r_fetch_state <= STATE_IDLE;
            end

        endcase
    end

    // VRAM request
    always @(posedge i_master_clk)
        o_vram_read_request <= (r_fetch_state == STATE_FETCH_REQUEST);


    // VRAM address
    reg[17:0]   r_fetch_address;

    always @(posedge i_master_clk) begin
        if(i_playback_address_valid)
            r_fetch_address <= i_playback_address;
        else if((r_fetch_state == STATE_FETCH_WAIT) && i_vram_read_data_valid)
            r_fetch_address <= r_fetch_address + 1;
    end
    
    assign o_vram_read_address = r_fetch_address;


    // ***********************************************
    // **                                           **
    // **   COLUMN COUNTING                         **
    // **                                           **
    // ***********************************************

    // column counter
    reg[8:0]    r_column_counter = 0;

    wire        w_last_column = (r_column_counter == 9'h1ff);

    always @(posedge i_master_clk) begin

        if((r_state == STATE_IDLE) || (r_state == STATE_CONTINUE))
            r_column_counter <= 0;

        if((r_state == STATE_FILL) && !w_last_column)
            r_column_counter <= r_column_counter + 1;

    end

    reg[8:0]    r_video_column = 0;
    reg         r_video_data_valid = 0;

    always @(posedge i_master_clk) begin
        if(r_state == STATE_FILL) begin
            r_video_column <= { 1'b0, r_column_counter[8:1] };
            if(r_column_counter[0])
                o_video_data[23:12] <= { r_fill_color, r_fill_color, r_fill_color };
            else
                o_video_data[11:0] <= { r_fill_color, r_fill_color, r_fill_color };
            // o_video_data <= { r_fetch_address[11:0], r_fetch_address[11:0] };
        end
    end

    always @(posedge i_master_clk)
        r_video_data_valid <= (r_state == STATE_FILL) && r_column_counter[0];

    assign o_video_column = r_video_column;
    assign o_video_data_valid = r_video_data_valid;


    // ***********************************************
    // **                                           **
    // **   PIXEL COUNTING                          **
    // **                                           **
    // ***********************************************

    // pixel counter
    reg[9:0]    r_pixel_counter = 0;
    
    wire        w_last_pixel = (r_pixel_counter == r_fill_count);

    always @(posedge i_master_clk) begin

        if(r_state == STATE_DECODE)
            r_pixel_counter <= 0;

        if((r_state == STATE_FILL) && !w_last_pixel)
            r_pixel_counter <= r_pixel_counter + 1;
    end

    // ***********************************************
    // **                                           **
    // **   COLOR & COUNT DECODER                   **
    // **                                           **
    // ***********************************************

    // SIGNAL: Type valid
    wire        w_inst_type_valid = (r_instruction_bits[4:2] != 0);

    // SIGNAL: Single color
    wire        w_inst_type_single_color = r_instruction[15];
    wire        w_inst_type_single_color_valid = (r_instruction_bits >= 5);
    wire        w_inst_single_color = w_inst_type_single_color && w_inst_type_single_color_valid;
    wire[3:0]   w_inst_single_color_color = w_inst_single_color ? r_instruction[14:11] : 4'h0;

    // SIGNAL: Small color stripe
    wire        w_inst_type_small_color = r_instruction[15:14] == 2'b01;
    wire        w_inst_type_small_color_valid = (r_instruction_bits >= 10);
    wire        w_inst_small_color = w_inst_type_small_color && w_inst_type_small_color_valid;
    wire[3:0]   w_inst_small_color_color = w_inst_small_color ? r_instruction[9:6] : 4'h0;

    // SIGNAL: Large color stripe
    wire        w_inst_type_large_color = r_instruction[15:13] == 3'b001;
    wire        w_inst_type_large_color_valid = (r_instruction_bits >= 15);
    wire        w_inst_large_color = w_inst_type_large_color && w_inst_type_large_color_valid; 
    wire[3:0]   w_inst_large_color_color = w_inst_large_color ? r_instruction[4:1] : 4'h0;

    // SIGNAL: Small black stripe
    wire        w_inst_type_small_black = r_instruction[15:12] == 4'b0001;
    wire        w_inst_type_small_black_valid = (r_instruction_bits >= 8);
    wire        w_inst_small_black = w_inst_type_small_black && w_inst_type_small_black_valid;

    // SIGNAL: Large black stripe
    wire        w_inst_type_large_black = r_instruction[15:12] == 4'b0000; 
    wire        w_inst_type_large_black_valid = (r_instruction_bits >= 13);
    wire        w_inst_large_black = w_inst_type_large_black && w_inst_type_large_black_valid;

    // SIGNAL: Instruction complete
    wire        w_inst_complete = (
        w_inst_single_color || w_inst_small_color || w_inst_large_color ||
        w_inst_small_black || w_inst_large_black);

    // filling color & count & mode
    wire[3:0]   w_fill_color = w_inst_single_color_color | w_inst_small_color_color | w_inst_large_color_color;
    wire[9:0]   w_fill_count =
        w_inst_single_color ? (10'h0)
        : w_inst_small_color ? ({ 6'h0, r_instruction[13:10] } + 1)
        : w_inst_large_color ? ({ 2'h0, r_instruction[12:5] } + 17)
        : w_inst_small_black ? ({ 6'h0, r_instruction[11:8] } + 1)
        : ({ 1'h0, r_instruction[11:3] } + 17);

    reg[3:0]    r_fill_color = 0;
    reg[9:0]    r_fill_count = 0;
    reg[4:0]    r_inst_combined = 0;

    always @(posedge i_master_clk) begin
        if((r_state == STATE_DECODE) && w_inst_complete) begin
            r_fill_color <= w_fill_color;
            r_fill_count <= w_fill_count;
            r_inst_combined <= { w_inst_single_color, w_inst_small_color, w_inst_large_color, w_inst_small_black, w_inst_large_black };
        end
    end





endmodule