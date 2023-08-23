

module RendererMixer(
        // clock
        i_master_clk,

        // original color
        i_original_red,
        i_original_green,
        i_original_blue,

        // new color
        i_color_red,
        i_color_green,
        i_color_blue,

        // alpha
        i_color_alpha,

        // output color
        o_final_red,
        o_final_green,
        o_final_blue
    );

    input       i_master_clk;

    input[3:0]  i_original_red;
    input[3:0]  i_original_green;
    input[3:0]  i_original_blue;

    input[3:0]  i_color_red;
    input[3:0]  i_color_green;
    input[3:0]  i_color_blue;

    input[3:0]  i_color_alpha;

    output[3:0] o_final_red;
    output[3:0] o_final_green;
    output[3:0] o_final_blue;

    // ***********************************************
    // **                                           **
    // **   ALPHA INITIALIZATION                    **
    // **                                           **
    // ***********************************************

    // compute opposite alpha
    wire[3:0]   w_mixer_opposite_alpha = ~ i_color_alpha;
    
    // extend alphas
    wire[7:0] w_mixer_alpha1_dup = { i_color_alpha, i_color_alpha };
    wire[7:0] w_mixer_alpha2_dup = { w_mixer_opposite_alpha, w_mixer_opposite_alpha };

    // ***********************************************
    // **                                           **
    // **   STAGE #1: MULTIPLY                      **
    // **                                           **
    // ***********************************************

    reg[11:0]   r_mixer_multiply_red1;
    reg[11:0]   r_mixer_multiply_green1;
    reg[11:0]   r_mixer_multiply_blue1;

    reg[11:0]   r_mixer_multiply_red2;
    reg[11:0]   r_mixer_multiply_green2;
    reg[11:0]   r_mixer_multiply_blue2;

    always @(posedge i_master_clk) begin
        r_mixer_multiply_red1 <= (w_mixer_alpha1_dup * i_color_red);
        r_mixer_multiply_green1 <= (w_mixer_alpha1_dup * i_color_green);
        r_mixer_multiply_blue1 <= (w_mixer_alpha1_dup * i_color_blue);

        r_mixer_multiply_red2 <= (w_mixer_alpha2_dup * i_original_red);
        r_mixer_multiply_green2 <= (w_mixer_alpha2_dup * i_original_green);
        r_mixer_multiply_blue2 <= (w_mixer_alpha2_dup * i_original_blue);
    end

    // ***********************************************
    // **                                           **
    // **   STAGE #2: ADJUST FRACTION               **
    // **                                           **
    // ***********************************************

    reg[8:0]    r_mixer_adjust_red1;
    reg[8:0]    r_mixer_adjust_green1;
    reg[8:0]    r_mixer_adjust_blue1;

    reg[8:0]    r_mixer_adjust_red2;
    reg[8:0]    r_mixer_adjust_green2;
    reg[8:0]    r_mixer_adjust_blue2;

    always @(posedge i_master_clk) begin
        r_mixer_adjust_red1 <= r_mixer_multiply_red1[11:3] + 5'b10001;
        r_mixer_adjust_green1 <= r_mixer_multiply_green1[11:3] + 5'b10001;
        r_mixer_adjust_blue1 <= r_mixer_multiply_blue1[11:3] + 5'b10001;

        r_mixer_adjust_red2 <= r_mixer_multiply_red2[11:3] + 5'b10001;
        r_mixer_adjust_green2 <= r_mixer_multiply_green2[11:3] + 5'b10001;
        r_mixer_adjust_blue2 <= r_mixer_multiply_blue2[11:3] + 5'b10001;
    end

    // ***********************************************
    // **                                           **
    // **   STAGE #3: MIX COLORS                    **
    // **                                           **
    // ***********************************************

    reg[4:0]    r_mixer_blend_red;
    reg[4:0]    r_mixer_blend_green;
    reg[4:0]    r_mixer_blend_blue;

    always @(posedge i_master_clk) begin
        r_mixer_blend_red <= r_mixer_adjust_red1[8:5] + r_mixer_adjust_red2[8:5];
        r_mixer_blend_green <= r_mixer_adjust_green1[8:5] + r_mixer_adjust_green2[8:5];
        r_mixer_blend_blue <= r_mixer_adjust_blue1[8:5] + r_mixer_adjust_blue2[8:5];
    end


    // ***********************************************
    // **                                           **
    // **   STAGE #4: CLIP FINAL COLORS             **
    // **                                           **
    // ***********************************************

    reg[3:0]    r_final_red;
    reg[3:0]    r_final_green;
    reg[3:0]    r_final_blue;

    always @(posedge i_master_clk) begin
        r_final_red <= r_mixer_blend_red[4] ? 4'hf : r_mixer_blend_red[3:0];
        r_final_green <= r_mixer_blend_green[4] ? 4'hf : r_mixer_blend_green[3:0];
        r_final_blue <= r_mixer_blend_blue[4] ? 4'hf : r_mixer_blend_blue[3:0];
    end

    assign o_final_red = r_final_red;
    assign o_final_green = r_final_green;
    assign o_final_blue = r_final_blue;

endmodule
