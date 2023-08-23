
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
    output reg          o_vram_read_request;
    input[15:0]         i_vram_read_data;
    input               i_vram_read_data_valid;

    // ***********************************************
    // **                                           **
    // **   STATE MACHINE                           **
    // **                                           **
    // ***********************************************

    localparam STATE_IDLE           = 0;
    localparam STATE_START          = 1;
    localparam STATE_FETCH          = 2;
    localparam STATE_FETCH_WAIT     = 3;
    localparam STATE_SINGLE         = 4;
    localparam STATE_COUNTING       = 5;
    localparam STATE_WRITEBACK      = 6;

    reg[2:0]        r_state = STATE_IDLE;
    reg[2:0]        w_next_state;

    always @(*) begin
        w_next_state = r_state;

        case (r_state) 

            STATE_IDLE: begin
                if(i_video_start)
                    w_next_state = STATE_START;
            end

            STATE_START:
                w_next_state = STATE_FETCH;

            STATE_FETCH:
                w_next_state = STATE_FETCH_WAIT;

            STATE_FETCH_WAIT: begin
                if(i_vram_read_data_valid)
                    w_next_state = (i_vram_read_data[15:12]==4'h1)? STATE_SINGLE : STATE_COUNTING;
            end

            STATE_SINGLE: begin
                if(w_last_column)
                    w_next_state = STATE_IDLE;
                else
                    w_next_state = STATE_FETCH;
            end

            STATE_COUNTING: begin
                if(w_last_column)
                    w_next_state = STATE_IDLE;
                else if(w_count == r_pixel_counter)
                    w_next_state = STATE_FETCH;
            end

            STATE_WRITEBACK:
                w_next_state = STATE_FETCH;
        endcase

    end

    always @(posedge i_master_clk)
        r_state <= w_next_state;

    // ***********************************************
    // **                                           **
    // **   ADDRESS COUNTING                        **
    // **                                           **
    // ***********************************************

    reg[17:0]   r_address = 0;

    always @(posedge i_master_clk) begin
        if(i_playback_address_valid)
            r_address <= i_playback_address;
        else if(r_state == STATE_FETCH)
            r_address <= r_address + 1;
    end

    assign o_vram_read_address = r_address;

    always @(posedge i_master_clk)
        o_vram_read_request <= (w_next_state == STATE_FETCH);

    // ***********************************************
    // **                                           **
    // **   COLUMN COUNTING                         **
    // **                                           **
    // ***********************************************

    reg[9:0]    r_column = 0;

    // SIGNAL: counting
    wire        w_column_counting = (r_state == STATE_SINGLE) || (r_state == STATE_COUNTING);

    // reg         r_column_counting = 0;
    // always @(posedge i_master_clk)
    //     r_column_counting <= w_column_counting;

    always @(posedge i_master_clk) begin
        if(w_next_state == STATE_START)
            r_column <= 0;
        else if(w_column_counting && !w_last_column)
            r_column <= r_column + 1;
    end

    wire        w_last_column = (r_column == 10'h1ff);

    // video column
    reg[8:0]    r_video_column = 0;

    always @(posedge i_master_clk)
        r_video_column <= r_column[9:1];

    assign o_video_column = r_video_column;

    // video data valid
    reg         r_video_data_valid = 0;
    always @(posedge i_master_clk)
        r_video_data_valid <= w_column_counting && r_column[0];

    assign o_video_data_valid = r_video_data_valid;

    // video data
    always @(posedge i_master_clk) begin
        if(w_column_counting) begin
            if(r_column[0])
                o_video_data[23:12] <= w_color;
            else
                o_video_data[11:0] <= w_color;
        end
    end

    // always @(posedge i_master_clk) begin
    //     if((w_next_state == STATE_SINGLE) || (w_next_state == STATE_COUNTING)) begin
    //         if(r_column[0])
    //             o_video_data[23:12] <= w_color;
    //         else
    //             o_video_data[11:0] <= w_color;
    //     end else begin
    //         o_video_data_valid <= 1'b0;
    //     end
    //     o_video_data_valid <= r_column[0] && ((w_next_state == STATE_SINGLE) || (w_next_state == STATE_COUNTING) || (w_next_state == STATE_WRITEBACK));
    // end

    // ***********************************************
    // **                                           **
    // **   DECODER                                 **
    // **                                           **
    // ***********************************************

    // decode value format
    wire        w_long_black    = (i_vram_read_data[15:12] == 4'h0);
    wire        w_counted_color = (i_vram_read_data[15:12] != 4'h0);

    // decode count
    wire[10:0]   w_count = w_long_black ? i_vram_read_data[10:0] : { 7'h00, i_vram_read_data[15:12] };

    // pixel counter
    reg[10:0]    r_pixel_counter = 0;

    always @(posedge i_master_clk) begin
        case (r_state)

            STATE_FETCH:
                r_pixel_counter <= 1;

            STATE_COUNTING:
                r_pixel_counter <= r_pixel_counter + 1;
        endcase
    end

    // decode color
    wire[11:0]  w_color = w_long_black ? 12'h000 : i_vram_read_data[11:0];

endmodule
