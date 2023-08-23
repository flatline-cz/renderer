
module RendererRectFill(
        // clock
        i_master_clk,

        // line coordinates
        i_cmd_coord_x1,
        i_cmd_coord_x2,
        i_line_address,

        // line color
        i_cmd_color_red,
        i_cmd_color_green,
        i_cmd_color_blue,

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

    input[3:0]      i_cmd_color_red;
    input[3:0]      i_cmd_color_green;
    input[3:0]      i_cmd_color_blue;

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
    localparam STATE_1ST_READ               = 1;
    localparam STATE_1ST_READ_WAIT          = 2;
    localparam STATE_1ST_WRITE              = 3;
    localparam STATE_1ST_WRITE_WAIT         = 4;
    localparam STATE_FILLING                = 5;
    localparam STATE_FILLING_WAIT           = 6;
    localparam STATE_LAST_READ              = 7;
    localparam STATE_LAST_READ_WAIT         = 8;
    localparam STATE_LAST_WRITE             = 9;
    localparam STATE_LAST_WRITE_WAIT        = 10;
    localparam STATE_DONE                   = 11;
    localparam STATE_FILLING_LAST           = 12;
    localparam STATE_FILLING_LAST_WAIT      = 13;

    reg[3:0]        r_state = STATE_IDLE;

    wire            w_partial_start = (i_cmd_coord_x1[0]);
    wire            w_partial_end = (!i_cmd_coord_x2[0]);

    reg[3:0]       w_next_state;

    always @(*) begin
        w_next_state = r_state;

        case (r_state)

            STATE_IDLE: begin
                if(i_process_start) begin
                    if(w_partial_start)
                        w_next_state = STATE_1ST_READ;
                    else begin
                        w_next_state = STATE_FILLING;
                    end
                end
            end

            STATE_1ST_READ:     w_next_state = STATE_1ST_READ_WAIT;
            STATE_1ST_WRITE:    w_next_state = STATE_1ST_WRITE_WAIT;
            STATE_FILLING:      w_next_state = STATE_FILLING_WAIT;
            STATE_FILLING_LAST: w_next_state = STATE_FILLING_LAST_WAIT;
            STATE_LAST_READ:    w_next_state = STATE_LAST_READ_WAIT;
            STATE_LAST_WRITE:   w_next_state = STATE_LAST_WRITE_WAIT;

            STATE_1ST_READ_WAIT: begin
                if (i_vram_read_data_valid)
                    w_next_state = STATE_1ST_WRITE;
            end

            STATE_LAST_READ_WAIT: begin
                if (i_vram_read_data_valid)
                    w_next_state = STATE_LAST_WRITE;
            end

            STATE_1ST_WRITE_WAIT: begin
                if (i_vram_write_done) begin
                    if (w_last_tupple) begin
                        if (w_partial_end)
                            w_next_state = STATE_LAST_READ;
                        else begin
                            if(i_cmd_coord_x1 == i_cmd_coord_x2)
                                w_next_state = STATE_DONE;
                            else
                                w_next_state = STATE_FILLING_LAST;
                        end
                    end else begin
                        w_next_state = STATE_FILLING;   
                    end
                end
            end

            STATE_FILLING_WAIT: begin
                if (i_vram_write_done) begin
                    if (w_last_tupple) begin
                        if (w_partial_end)
                            w_next_state = STATE_LAST_READ;
                        else
                            w_next_state = STATE_FILLING_LAST;
                    end else
                        w_next_state = STATE_FILLING;
                end
            end

            STATE_FILLING_LAST_WAIT,
            STATE_LAST_WRITE_WAIT: begin
                if (i_vram_write_done)
                    w_next_state = STATE_DONE;
            end

            STATE_DONE:
                w_next_state = STATE_IDLE;

        endcase
    end

    always @(posedge i_master_clk) 
        r_state <= w_next_state;


    // done flag
    reg         r_flag_done = 0;

    always @(posedge i_master_clk) begin
        if (w_next_state == STATE_DONE)
            r_flag_done <= 1'b1;
        else
            r_flag_done <= 1'b0;
    end

    assign o_process_done = r_flag_done;


    // ***********************************************
    // **                                           **
    // **   PIXEL COUNTER                           **
    // **                                           **
    // ***********************************************

    // pixel tupple counter
    reg[8:0]        r_column_address;

    // next pixel tupple is last partial
    wire[8:0]       w_next_column_address = r_column_address + 1;
    wire            w_next_last_partial = (w_next_column_address == i_cmd_coord_x2[9:1]) && !i_cmd_coord_x2[0];

    // last tupple flag
    wire            w_last_tupple = r_column_address == i_cmd_coord_x2[9:1];

    always @(posedge i_master_clk) begin
        case (r_state)

            STATE_IDLE: begin
                if (i_process_start)
                    r_column_address <= i_cmd_coord_x1[9:1];
            end

            STATE_1ST_WRITE, 
            STATE_FILLING,
            STATE_FILLING_LAST,
            STATE_LAST_WRITE: begin
                if (!w_last_tupple)
                    r_column_address <= w_next_column_address;
            end

        endcase
    end

    assign o_vram_read_address = { i_buffer_bank, i_line_address, r_column_address };
    assign o_vram_write_address = { i_buffer_bank, i_line_address, r_column_address };

    // ***********************************************
    // **                                           **
    // **   PIXEL READING                           **
    // **                                           **
    // ***********************************************

    // reading request
    reg         r_read_pixel_request = 0;

    always @(posedge i_master_clk) begin
        case (w_next_state)

            STATE_1ST_READ,
            STATE_LAST_READ:
                r_read_pixel_request <= 1'b1;

            STATE_1ST_READ_WAIT,
            STATE_LAST_READ_WAIT:
                r_read_pixel_request <= 1'b0;

        endcase
    end

    assign o_vram_read_request = r_read_pixel_request;

    // ***********************************************
    // **                                           **
    // **   PIXEL WRITING                           **
    // **                                           **
    // ***********************************************

    // data to be written
    reg[23:0]   r_write_pixel_data;
    
    always @(posedge i_master_clk) begin
        case (w_next_state)

            STATE_1ST_WRITE:
                r_write_pixel_data <= { i_cmd_color_red, i_cmd_color_green, i_cmd_color_blue, i_vram_read_data[11:0] };

            STATE_FILLING,
            STATE_FILLING_LAST:
                r_write_pixel_data <= { i_cmd_color_red, i_cmd_color_green, i_cmd_color_blue, i_cmd_color_red, i_cmd_color_green, i_cmd_color_blue };

            STATE_LAST_WRITE:
                r_write_pixel_data <= { i_vram_read_data[23:12], i_cmd_color_red, i_cmd_color_green, i_cmd_color_blue };

        endcase
    end

    // write signal
    reg         r_write_pixel_request = 0;

    always @(posedge i_master_clk) begin
        case (w_next_state)

            STATE_1ST_WRITE,
            STATE_FILLING,
            STATE_FILLING_LAST,
            STATE_LAST_WRITE:
                r_write_pixel_request <= 1'b1;

            STATE_1ST_WRITE_WAIT,
            STATE_FILLING_WAIT,
            STATE_FILLING_LAST_WAIT,
            STATE_LAST_WRITE_WAIT:
                r_write_pixel_request <= 1'b0;

        endcase
    end

    assign o_vram_write_data = r_write_pixel_data;
    assign o_vram_write_request = r_write_pixel_request;

endmodule
