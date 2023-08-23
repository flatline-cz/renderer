
module Renderer (
        // clock
        i_master_clk,

        // PROCESS interface
        i_process_start,
        o_process_finished,
        i_process_bank,

        // COMMAND DECODER interface
        i_cmd_rect_x1,
        i_cmd_rect_y1,
        i_cmd_rect_x2,
        i_cmd_rect_y2,
        i_cmd_color_red,
        i_cmd_color_green,
        i_cmd_color_blue,
        i_cmd_color_alpha,

        i_cmd_textured,
        i_cmd_texture_packed,
        i_cmd_texture_copy,
        i_cmd_texture_base,
        i_cmd_texture_stripe,

        // i_cmd_texture_address,

        // VRAM CONTROLLER interface
        o_vram_read_address,
        o_vram_read_request,
        i_vram_read_data,
        i_vram_read_data_valid,
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

    input           i_process_start;
    output          o_process_finished;
    input           i_process_bank;

    input[9:0]      i_cmd_rect_x1;
    input[9:0]      i_cmd_rect_x2;
    input[9:0]      i_cmd_rect_y1;
    input[9:0]      i_cmd_rect_y2;
    input[3:0]      i_cmd_color_red;
    input[3:0]      i_cmd_color_green;
    input[3:0]      i_cmd_color_blue;
    input[3:0]      i_cmd_color_alpha;

    input           i_cmd_textured;
    input           i_cmd_texture_packed;
    input           i_cmd_texture_copy;
    input[19:0]     i_cmd_texture_base;
    input[9:0]      i_cmd_texture_stripe;

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

    localparam STATE_IDLE           = 0;
    localparam STATE_START_ROW      = 1;
    localparam STATE_RENDERING      = 2;
    localparam STATE_NEXT_ROW       = 3;
    localparam STATE_DONE           = 4;

    reg[2:0]        r_state = STATE_IDLE;
    reg[2:0]        w_next_state;

    always @(*) begin
        w_next_state = r_state;

        case (r_state)

            STATE_IDLE: begin
                if (i_process_start)
                    w_next_state = STATE_START_ROW;
            end

            STATE_RENDERING: begin
                if (w_line_finished)
                    w_next_state = STATE_NEXT_ROW;
            end

            STATE_START_ROW:    w_next_state = STATE_RENDERING;
            STATE_DONE:         w_next_state = STATE_IDLE;

            STATE_NEXT_ROW: begin
                if (w_last_row)
                    w_next_state = STATE_DONE;
                else
                    w_next_state = STATE_START_ROW;
            end
        endcase
    end

    always @(posedge i_master_clk)
        r_state <= w_next_state;

    // finished flag
    reg         r_process_finished = 0;

    always @(posedge i_master_clk)
        r_process_finished <= (w_next_state == STATE_DONE);

    assign o_process_finished = r_process_finished;

    // line renderer start flag
    reg         r_line_start = 0;

    always @(posedge i_master_clk)
        r_line_start <= (w_next_state == STATE_START_ROW);
    
    // ***********************************************
    // **                                           **
    // **   ROW & TEXTURE ROW COUNTER               **
    // **                                           **
    // ***********************************************

    // row counter
    reg[9:0]        r_row_counter;

    // texture coordinates
    reg[19:0]       r_texture_address;

    // SIGNAL: last row
    wire            w_last_row = (r_row_counter == i_cmd_rect_y2);

    always @(posedge i_master_clk) begin
        case (r_state)

            STATE_IDLE: begin
                if (i_process_start) begin
                    r_row_counter <= i_cmd_rect_y1;
                    r_texture_address <= i_cmd_texture_base;
                end
            end

            STATE_NEXT_ROW: begin
                if (!w_last_row) begin
                    r_row_counter <= r_row_counter + 1;
                    r_texture_address <= r_texture_address + i_cmd_texture_stripe;
                end
            end

        endcase
    end

    // ***********************************************
    // **                                           **
    // **   LINE RENDERERS CONTROLLER               **
    // **                                           **
    // ***********************************************

    // mode decoder
    wire    w_mode_rect_fill = (!i_cmd_textured && i_cmd_color_alpha == 4'hf);
    wire    w_mode_rect_mix = (!i_cmd_textured && i_cmd_color_alpha != 4'hf);
    wire    w_mode_tex_mix = (i_cmd_textured);

    // combine line renderers finish flag
    wire    w_line_finished = w_rect_fill_finished || w_rect_mix_finished || w_tex_mix_finished;

    // assign start flag
    assign  w_rect_fill_start = (r_line_start && w_mode_rect_fill);
    assign  w_rect_mix_start = (r_line_start && w_mode_rect_mix);
    assign  w_tex_mix_start = (r_line_start && w_mode_tex_mix);

    // multiplex VRAM access
    assign  o_vram_read_request = w_mode_rect_fill ? w_rect_fill_vram_read_request
        : w_mode_rect_mix ? w_rect_mix_vram_read_request
        : w_mode_tex_mix ? w_tex_mix_vram_read_request
        : 1'b0;

    assign  o_vram_read_address = w_mode_rect_fill ? w_rect_fill_vram_read_address
        : w_mode_rect_mix ? w_rect_mix_vram_read_address
        : w_mode_tex_mix ? w_tex_mix_vram_read_address
        : 20'b0;

    assign  o_vram_write_request = w_mode_rect_fill ? w_rect_fill_vram_write_request
        : w_mode_rect_mix ? w_rect_mix_vram_write_request
        : w_mode_tex_mix ? w_tex_mix_vram_write_request
        : 1'b0;

    assign o_vram_write_address = w_mode_rect_fill ? w_rect_fill_vram_write_address
        : w_mode_rect_mix ? w_rect_mix_vram_write_address
        : w_mode_tex_mix ? w_tex_mix_vram_write_address
        : 20'b0;

    assign o_vram_write_data = w_mode_rect_fill ? w_rect_fill_vram_write_data
        : w_mode_rect_mix ? w_rect_mix_vram_write_data
        : w_mode_tex_mix ? w_tex_mix_vram_write_data
        : 24'b0;
    


    // ***********************************************
    // **                                           **
    // **   RECT FILL RENDERER                      **
    // **                                           **
    // ***********************************************

    wire        w_rect_fill_start;
    wire        w_rect_fill_finished;
    wire[19:0]  w_rect_fill_vram_read_address;
    wire        w_rect_fill_vram_read_request;
    wire[19:0]  w_rect_fill_vram_write_address;
    wire[23:0]  w_rect_fill_vram_write_data;
    wire        w_rect_fill_vram_write_request;

    RendererRectFill rect_fill(
            // clock
            .i_master_clk(i_master_clk),

            // line coordinates
            .i_cmd_coord_x1(i_cmd_rect_x1),
            .i_cmd_coord_x2(i_cmd_rect_x2),
            .i_line_address(r_row_counter),

            // line color
            .i_cmd_color_red(i_cmd_color_red),
            .i_cmd_color_green(i_cmd_color_green),
            .i_cmd_color_blue(i_cmd_color_blue),

            // RENDERER interface
            .i_process_start(w_rect_fill_start),
            .o_process_done(w_rect_fill_finished),

            // BUFFER CONTROLLER interface
            .i_buffer_bank(i_process_bank),

            // VIDEO RAM READ interface
            .o_vram_read_address(w_rect_fill_vram_read_address),
            .o_vram_read_request(w_rect_fill_vram_read_request),
            .i_vram_read_data(i_vram_read_data),
            .i_vram_read_data_valid(i_vram_read_data_valid),

            // VIDEO RAM WRITE interface
            .o_vram_write_address(w_rect_fill_vram_write_address),
            .o_vram_write_data(w_rect_fill_vram_write_data),
            .o_vram_write_request(w_rect_fill_vram_write_request),
            .i_vram_write_done(i_vram_write_done)
        );

    // ***********************************************
    // **                                           **
    // **   RECT MIX RENDERER                       **
    // **                                           **
    // ***********************************************

    // process interface
    wire        w_rect_mix_start;
    wire        w_rect_mix_finished;

    // VRAM interface
    wire[19:0]  w_rect_mix_vram_read_address;
    wire        w_rect_mix_vram_read_request;
    wire[19:0]  w_rect_mix_vram_write_address;
    wire[23:0]  w_rect_mix_vram_write_data;
    wire        w_rect_mix_vram_write_request;

    // Mixer interface
    wire[3:0]   w_rect_mix_orig_red;
    wire[3:0]   w_rect_mix_orig_green;
    wire[3:0]   w_rect_mix_orig_blue;

    RendererRectMix rect_mix (
            // clock
            .i_master_clk(i_master_clk),

            // line coordinates
            .i_cmd_coord_x1(i_cmd_rect_x1),
            .i_cmd_coord_x2(i_cmd_rect_x2),
            .i_line_address(r_row_counter),

            // COLOR MIXER interface
            .o_mixer_original_red(w_rect_mix_orig_red),
            .o_mixer_original_green(w_rect_mix_orig_green),
            .o_mixer_original_blue(w_rect_mix_orig_blue),
            .i_mixer_final_red(w_mixer_final_red),
            .i_mixer_final_green(w_mixer_final_green),
            .i_mixer_final_blue(w_mixer_final_blue),

            // RENDERER interface
            .i_process_start(w_rect_mix_start),
            .o_process_done(w_rect_mix_finished),

            // BUFFER CONTROLLER interface
            .i_buffer_bank(i_process_bank),

            // VIDEO RAM READ interface
            .o_vram_read_address(w_rect_mix_vram_read_address),
            .o_vram_read_request(w_rect_mix_vram_read_request),
            .i_vram_read_data(i_vram_read_data),
            .i_vram_read_data_valid(i_vram_read_data_valid),

            // VIDEO RAM WRITE interface
            .o_vram_write_address(w_rect_mix_vram_write_address),
            .o_vram_write_data(w_rect_mix_vram_write_data),
            .o_vram_write_request(w_rect_mix_vram_write_request),
            .i_vram_write_done(i_vram_write_done)

        );

    // ***********************************************
    // **                                           **
    // **   TEXTURE MIX RENDERER                    **
    // **                                           **
    // ***********************************************

    // process interface
    wire        w_tex_mix_start;
    wire        w_tex_mix_finished;

    // VRAM interface
    wire[19:0]  w_tex_mix_vram_read_address;
    wire        w_tex_mix_vram_read_request;
    wire[19:0]  w_tex_mix_vram_write_address;
    wire[23:0]  w_tex_mix_vram_write_data;
    wire        w_tex_mix_vram_write_request;

    // Mixer interface
    wire[3:0]   w_tex_mix_orig_red;
    wire[3:0]   w_tex_mix_orig_green;
    wire[3:0]   w_tex_mix_orig_blue;
    wire[3:0]   w_tex_mix_alpha;

    RendererTextureMix tex_mix (
            // clock
            .i_master_clk(i_master_clk),

            // LINE COORDINATES
            .i_cmd_coord_x1(i_cmd_rect_x1),
            .i_cmd_coord_x2(i_cmd_rect_x2),
            .i_line_address(r_row_counter),

            // TEXTURE COORDINATES
            .i_cmd_texture_address(r_texture_address),
        
            // COLOR MIXER interface
            .o_mixer_original_red(w_tex_mix_orig_red),
            .o_mixer_original_green(w_tex_mix_orig_green),
            .o_mixer_original_blue(w_tex_mix_orig_blue),
            .i_mixer_final_red(w_mixer_final_red),
            .i_mixer_final_green(w_mixer_final_green),
            .i_mixer_final_blue(w_mixer_final_blue),
            .o_mixer_color_alpha(w_tex_mix_alpha),

            // RENDERER interface
            .i_process_start(w_tex_mix_start),
            .o_process_done(w_tex_mix_finished),

            // BUFFER CONTROLLER interface
            .i_buffer_bank(i_process_bank),

            // VIDEO RAM READ interface
            .o_vram_read_address(w_tex_mix_vram_read_address),
            .o_vram_read_request(w_tex_mix_vram_read_request),
            .i_vram_read_data(i_vram_read_data),
            .i_vram_read_data_valid(i_vram_read_data_valid),

            // VIDEO RAM WRITE interface
            .o_vram_write_address(w_tex_mix_vram_write_address),
            .o_vram_write_data(w_tex_mix_vram_write_data),
            .o_vram_write_request(w_tex_mix_vram_write_request),
            .i_vram_write_done(i_vram_write_done),

            // FLASH READ interface
            .o_flash_read_address(o_flash_read_address),
            .o_flash_read_request(o_flash_read_request),
            .i_flash_read_data(i_flash_read_data),
            .i_flash_read_data_valid(i_flash_read_data_valid)

        );

    // ***********************************************
    // **                                           **
    // **   COLOR MIXER                             **
    // **                                           **
    // ***********************************************

    // mixer input
    wire[3:0]   w_mixer_original_red;
    wire[3:0]   w_mixer_original_green;
    wire[3:0]   w_mixer_original_blue;
    wire[3:0]   w_mixer_alpha;

    assign w_mixer_original_red = w_mode_rect_mix ? w_rect_mix_orig_red
        : w_mode_tex_mix ? w_tex_mix_orig_red
        : 3'h0;

    assign w_mixer_original_green = w_mode_rect_mix ? w_rect_mix_orig_green
        : w_mode_tex_mix ? w_tex_mix_orig_green
        : 3'h0;

    assign w_mixer_original_blue = w_mode_rect_mix ? w_rect_mix_orig_blue
        : w_mode_tex_mix ? w_tex_mix_orig_blue
        : 3'h0;

    assign w_mixer_alpha = w_mode_tex_mix ? w_tex_mix_alpha : i_cmd_color_alpha;

    // mixer output
    wire[3:0]   w_mixer_final_red;
    wire[3:0]   w_mixer_final_green;
    wire[3:0]   w_mixer_final_blue;

    RendererMixer mixer (
            .i_master_clk(i_master_clk),

            .i_original_red(w_mixer_original_red),
            .i_original_green(w_mixer_original_green),
            .i_original_blue(w_mixer_original_blue),

            .i_color_red(i_cmd_color_red),
            .i_color_green(i_cmd_color_green),
            .i_color_blue(i_cmd_color_blue),
            .i_color_alpha(w_mixer_alpha),

            .o_final_red(w_mixer_final_red),
            .o_final_green(w_mixer_final_green),
            .o_final_blue(w_mixer_final_blue)
        );





endmodule
