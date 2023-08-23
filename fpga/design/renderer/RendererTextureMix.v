
module RendererTextureMix (
        // clock
        i_master_clk,

        // LINE COORDINATES
        i_cmd_coord_x1,
        i_cmd_coord_x2,
        i_line_address,

        // TEXTURE ADDRESS
        i_cmd_texture_address,

        // COLOR MIXER interface
        o_mixer_original_red,
        o_mixer_original_green,
        o_mixer_original_blue,
        o_mixer_color_alpha,
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
        i_vram_write_done,

        // NAND FLASH READ interface
        o_flash_read_address,
        o_flash_read_request,
        i_flash_read_data,
        i_flash_read_data_valid

    );

    input           i_master_clk;

    input[9:0]      i_cmd_coord_x1;
    input[9:0]      i_cmd_coord_x2;
    input[9:0]      i_line_address;

    input[19:0]     i_cmd_texture_address;

    output[3:0]     o_mixer_original_red;
    output[3:0]     o_mixer_original_green;
    output[3:0]     o_mixer_original_blue;
    output[3:0]     o_mixer_color_alpha;
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

    output[17:0]    o_flash_read_address;
    output          o_flash_read_request;
    input[15:0]     i_flash_read_data;
    input           i_flash_read_data_valid;


    // ***********************************************
    // **                                           **
    // **   STATE MACHINE                           **
    // **                                           **
    // ***********************************************

    localparam STATE_IDLE                   = 0;
    localparam STATE_READ_TEXTURE           = 1;
    localparam STATE_READ_TEXTURE_WAIT      = 2;
    localparam STATE_READ_TUPPLE            = 3;
    localparam STATE_READ_TUPPLE_WAIT       = 4;
    localparam STATE_MIX_PIXEL_LO           = 5;
    localparam STATE_MIX_WAIT1              = 6;
    localparam STATE_MIX_WAIT2              = 7;
    localparam STATE_MIX_WAIT3              = 8;
    localparam STATE_MIX_WAIT4              = 9;
    localparam STATE_WRITE_TUPPLE           = 10;
    localparam STATE_WRITE_TUPPLE_WAIT      = 11;
    localparam STATE_NEXT_PIXEL             = 12;
    localparam STATE_DONE                   = 13;

    reg[3:0]        r_state = STATE_IDLE;
    reg[3:0]        w_next_state;

    always @(*) begin
        w_next_state = r_state;

        case (r_state)

            STATE_IDLE: begin
                if (i_process_start)
                    w_next_state = STATE_READ_TEXTURE;
            end

            STATE_READ_TEXTURE:     w_next_state = STATE_READ_TEXTURE_WAIT;
            STATE_READ_TUPPLE:      w_next_state = STATE_READ_TUPPLE_WAIT;
            STATE_MIX_PIXEL_LO:     w_next_state = STATE_MIX_WAIT1;
            STATE_MIX_WAIT1:        w_next_state = STATE_MIX_WAIT2;
            STATE_MIX_WAIT2:        w_next_state = STATE_MIX_WAIT3;
            STATE_MIX_WAIT3:        w_next_state = STATE_MIX_WAIT4;
            STATE_MIX_WAIT4:        w_next_state = STATE_WRITE_TUPPLE;
            STATE_WRITE_TUPPLE:     w_next_state = STATE_WRITE_TUPPLE_WAIT;
            STATE_DONE:             w_next_state = STATE_IDLE;

            STATE_READ_TEXTURE_WAIT: begin
                if (i_flash_read_data_valid)
                    w_next_state = STATE_READ_TUPPLE;
            end

            STATE_READ_TUPPLE_WAIT: begin
                if (i_vram_read_data_valid)
                    w_next_state = STATE_MIX_PIXEL_LO;
            end

            STATE_WRITE_TUPPLE_WAIT: begin
                if (i_vram_write_done)
                    w_next_state = STATE_NEXT_PIXEL;
            end

            STATE_NEXT_PIXEL: begin
                if (w_last_pixel)
                    w_next_state = STATE_DONE;
                else
                    w_next_state = STATE_READ_TEXTURE;
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
    // **   PIXEL COUNTER & READER & WRITER         **
    // **                                           **
    // ***********************************************

    // pixel counter
    reg[9:0]        r_pixel_counter;

    // SIGNAL: last pixel
    wire            w_last_pixel = (r_pixel_counter == i_cmd_coord_x2);

    // tupple buffer
    reg[23:0]       r_tupple_buffer;

    always @(posedge i_master_clk) begin
        case (r_state)

            STATE_IDLE: begin
                if (i_process_start) begin
                    r_pixel_counter <= i_cmd_coord_x1;
                end
            end

            STATE_READ_TUPPLE_WAIT: begin
                if (i_vram_read_data_valid)
                    r_tupple_buffer <= i_vram_read_data;
            end

            STATE_MIX_WAIT4: begin
                if (r_pixel_counter[0]==0) begin
                    r_tupple_buffer[11:8] <= i_mixer_final_red;
                    r_tupple_buffer[7:4] <= i_mixer_final_green;
                    r_tupple_buffer[3:0] <= i_mixer_final_blue;
                end else begin
                    r_tupple_buffer[23:20] <= i_mixer_final_red;
                    r_tupple_buffer[19:16] <= i_mixer_final_green;
                    r_tupple_buffer[15:12] <= i_mixer_final_blue;
                end
            end

            STATE_NEXT_PIXEL: begin
                if (!w_last_pixel)
                    r_pixel_counter <= r_pixel_counter + 1;
            end
            
        endcase
    end

    // read request
    reg             r_pixel_read_request = 0;

    always @(posedge i_master_clk)
        r_pixel_read_request <= (w_next_state == STATE_READ_TUPPLE);

    // write request
    reg             r_pixel_write_request = 0;

    always @(posedge i_master_clk)
        r_pixel_write_request <= (w_next_state == STATE_WRITE_TUPPLE);

    // assign outputs
    assign o_vram_read_address = { i_buffer_bank, i_line_address, r_pixel_counter[9:1] };
    assign o_vram_read_request = r_pixel_read_request;

    assign o_vram_write_address = { i_buffer_bank, i_line_address, r_pixel_counter[9:1] };
    assign o_vram_write_request = r_pixel_write_request;
    assign o_vram_write_data = r_tupple_buffer;

    // ***********************************************
    // **                                           **
    // **   COLOR MIXING                            **
    // **                                           **
    // ***********************************************

    // mixer input color
    reg[3:0]    r_mixer_red;
    reg[3:0]    r_mixer_green;
    reg[3:0]    r_mixer_blue;

    always @(posedge i_master_clk) begin
        case (w_next_state)

            STATE_MIX_PIXEL_LO: begin
                if (r_pixel_counter[0] == 0) begin
                    r_mixer_red <= i_vram_read_data[11:8];
                    r_mixer_green <= i_vram_read_data[7:4];
                    r_mixer_blue <= i_vram_read_data[3:0];
                end else begin
                    r_mixer_red <= i_vram_read_data[23:20];
                    r_mixer_green <= i_vram_read_data[19:16];
                    r_mixer_blue <= i_vram_read_data[15:12];
                end
            end

        endcase
    end

    assign o_mixer_original_red = r_mixer_red;
    assign o_mixer_original_green = r_mixer_green;
    assign o_mixer_original_blue = r_mixer_blue;

    // ***********************************************
    // **                                           **
    // **   TEXTURE COUNTER & READ                  **
    // **                                           **
    // ***********************************************

    // texture address counter
    reg[19:0]        r_texture_address;

    // // texture column address
    // wire[7:0]       w_texture_column_address = r_texture_column[9:2]; 

    // texture pixel value
    reg[3:0]        r_texture_alpha;

    always @(posedge i_master_clk) begin
        case (r_state) 

            STATE_IDLE: begin
                if (i_process_start) begin
                    r_texture_address <= i_cmd_texture_address;
                end
            end

            STATE_NEXT_PIXEL: begin
                r_texture_address <= r_texture_address + 1;
            end

            STATE_READ_TEXTURE_WAIT: begin
                if (i_flash_read_data_valid) begin
                    case (r_texture_address[1:0])
                        2'b11:  r_texture_alpha <= i_flash_read_data[3:0];
                        2'b10:  r_texture_alpha <= i_flash_read_data[7:4];
                        2'b01:  r_texture_alpha <= i_flash_read_data[11:8];
                        2'b00:  r_texture_alpha <= i_flash_read_data[15:12];
                    endcase
                end
            end
        endcase

    end

    assign o_mixer_color_alpha = r_texture_alpha;

    // read request
    reg             r_texture_read_request = 0;

    always @(posedge i_master_clk)
        r_texture_read_request <= (w_next_state == STATE_READ_TEXTURE);

    assign o_flash_read_request = r_texture_read_request;
    assign o_flash_read_address = r_texture_address[19:2];


endmodule
