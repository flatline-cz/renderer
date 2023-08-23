
module RenderingController (
        // master clock domain
        i_master_clk,

        // VRAM CONTROLLER interface (master clock domain)
        o_vram_read_address,
        o_vram_read_request,
        i_vram_read_data,
        i_vram_read_data_valid,
        o_vram_write_address,
        o_vram_write_request,
        o_vram_write_data,
        i_vram_write_done,

        // BUFFER CONTROLLER interface (master clock domain)
        i_process_start,
        o_process_done,
        i_process_bank,

        // COMMAND QUEUE interface (master clock domain)
        o_queue_request,
        i_queue_data,
        i_queue_data_valid,
        i_queue_eof,

        // NAND FLASH READ interface
        o_flash_read_address,
        o_flash_read_request,
        i_flash_read_data,
        i_flash_read_data_valid,

        // DEBUG interface (master clock domain)
        dbg_rendering
    );

    input           i_master_clk;

    input           i_process_start;
    output          o_process_done;
    input           i_process_bank;

    output[19:0]    o_vram_read_address;
    output          o_vram_read_request;
    input[23:0]     i_vram_read_data;
    input           i_vram_read_data_valid;
    output[19:0]    o_vram_write_address;
    output          o_vram_write_request;
    output[23:0]    o_vram_write_data;
    input           i_vram_write_done;

    output          i_queue_request;
    input[7:0]      i_queue_data;
    input           i_queue_data_valid;
    input           i_queue_eof;

    output[31:0]    o_flash_read_address;
    output          o_flash_read_request;
    input[15:0]     i_flash_read_data;
    input           i_flash_read_data_valid;


    output          dbg_rendering;


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
        endcase

    end

    always @(posedge i_master_clk)
        r_fetch_state <= w_next_fetch_state;

    // ***********************************************
    // **                                           **
    // **   COMMAND DECODER                         **
    // **                                           **
    // ***********************************************

    // SIGNAL: last byte of the command
    wire        w_last_byte = 1;

    // // queue fetching
    // reg         r_queue_fetch = 0;

    // always @(posedge i_master_clk)
    //     r_queue_fetch <= (w_state_read_queue && !r_state[0]);
    


    // // state machine
    // localparam STATE_IDLE           = 6'b000000;
    // localparam STATE_RENDER         = 6'b000001;
    // localparam STATE_WAIT           = 6'b000010;
    // localparam STATE_DONE           = 6'b000011;

    // localparam STATE_CMD_READ       = 6'b100000;
    // localparam STATE_CMD_DECODE     = 6'b100001;
    // localparam STATE_X_READ         = 6'b100010;
    // localparam STATE_X_DECODE       = 6'b100011;
    // localparam STATE_Y_READ         = 6'b100100;
    // localparam STATE_Y_DECODE       = 6'b100101;
    // localparam STATE_W_READ         = 6'b100110;
    // localparam STATE_W_DECODE       = 6'b100111;
    // localparam STATE_H_READ         = 6'b101000;
    // localparam STATE_H_DECODE       = 6'b101001;
    // localparam STATE_HI_READ        = 6'b101010;
    // localparam STATE_HI_DECODE      = 6'b101011;
    // localparam STATE_C0_READ        = 6'b101100;
    // localparam STATE_C0_DECODE      = 6'b101101;
    // localparam STATE_C1_READ        = 6'b101110;
    // localparam STATE_C1_DECODE      = 6'b101111;
    // localparam STATE_T0_READ        = 6'b110000;
    // localparam STATE_T0_DECODE      = 6'b110001;
    // localparam STATE_T1_READ        = 6'b110010;
    // localparam STATE_T1_DECODE      = 6'b110011;
    // localparam STATE_T2_READ        = 6'b110100;
    // localparam STATE_T2_DECODE      = 6'b110101;
    // localparam STATE_T3_READ        = 6'b110110;
    // localparam STATE_T3_DECODE      = 6'b110111;
    

    // reg[5:0]    r_state = STATE_IDLE;
    // wire        w_state_read_queue = r_state[5];

    // assign dbg_rendering = (r_state != STATE_IDLE);

    // always @(posedge i_master_clk) begin
    //     // IDLE?
    //     if(r_state == STATE_IDLE && i_process_start) begin
    //         r_state <= STATE_CMD_READ;
    //     end else if(r_state == STATE_RENDER) begin
    //         r_state <= STATE_WAIT;
    //     end else if(r_state == STATE_WAIT) begin
    //         if(w_cmd_finished)
    //             r_state <= STATE_CMD_READ;
    //     end else if(r_state==STATE_DONE) begin
    //         r_state <= STATE_IDLE;
    //     end else if(w_state_read_queue) begin
    //         // fetching data?
    //         if(r_state[0]) begin
    //             if(w_queue_data_valid) begin
    //                 if(r_state == STATE_CMD_DECODE && r_queue_data[7])
    //                     r_state <= STATE_DONE;
    //                 else if(r_state == STATE_T3_DECODE)
    //                     r_state <= STATE_RENDER;
    //                 else
    //                     r_state <= r_state + 1;
    //             end
    //         end else begin
    //             r_state <= r_state + 1;
    //         end
    //     end
    // end

    // always @(posedge i_master_clk) begin
    //     if(r_state[5] && r_state[0] && w_queue_data_valid) begin
    //         case (r_state[4:1])
    //             0: begin
    //                 r_cmd <= r_queue_data;
    //             end
    //             1: begin
    //                 r_cmd_rect_x1[7:0] <= r_queue_data;
    //             end
    //             2: begin
    //                 r_cmd_rect_y1[7:0] <= r_queue_data;
    //             end
    //             3: begin
    //                 r_cmd_rect_x2[7:0] <= r_queue_data;
    //             end
    //             4: begin
    //                 r_cmd_rect_y2[7:0] <= r_queue_data;
    //             end
    //             5: begin
    //                 r_cmd_rect_x1[9:8] <= r_queue_data[1:0];
    //                 r_cmd_rect_y1[9:8] <= r_queue_data[3:2];
    //                 r_cmd_rect_x2[9:8] <= r_queue_data[5:4];
    //                 r_cmd_rect_y2[9:8] <= r_queue_data[7:6];
    //             end
    //             6: begin
    //                 r_cmd_color_red <= r_queue_data[3:0];
    //                 r_cmd_color_green <= r_queue_data[7:4];
    //             end
    //             7: begin
    //                 r_cmd_color_blue <= r_queue_data[3:0];
    //                 r_cmd_color_alpha <= r_queue_data[7:4];
    //             end
    //             8: begin
    //                 r_cmd_tex_base[7:0] <= r_queue_data;
    //             end
    //             9: begin
    //                 r_cmd_tex_base[15:8] <= r_queue_data;
    //             end
    //             10: begin
    //                 r_cmd_tex_base[23:16] <= r_queue_data;
    //             end
    //             11: begin
    //                 r_cmd_tex_base[31:24] <= r_queue_data;
    //             end
    //         endcase
    //     end
    // end

    // // finished flag
    // reg         r_process_done = 0;

    // always @(posedge i_master_clk)
    //     r_process_done <= (r_state == STATE_DONE);

    // assign o_process_done = r_process_done;

    // // command to execute
    // reg[7:0]    r_cmd = 0;

    // wire        w_cmd_start = (r_state == STATE_RENDER);


    // // ***********************************************
    // // **                                           **
    // // **   RENDERER                                **
    // // **                                           **
    // // ***********************************************

    // // renderer parameters
    // reg[9:0]    r_cmd_rect_x1       = 10'hx;
    // reg[9:0]    r_cmd_rect_y1       = 10'hx;
    // reg[9:0]    r_cmd_rect_x2       = 10'hx;
    // reg[9:0]    r_cmd_rect_y2       = 10'hx;
    // reg[3:0]    r_cmd_color_red     = 4'hx;
    // reg[3:0]    r_cmd_color_green   = 4'hx;
    // reg[3:0]    r_cmd_color_blue    = 4'hx;
    // reg[3:0]    r_cmd_color_alpha   = 4'hx;

    // reg[31:0]   r_cmd_tex_base      = 32'hx;

    // wire        w_cmd_finished;

    // // renderer block
    // Renderer renderer (
    //         .i_master_clk(i_master_clk),

    //         .i_process_start(w_cmd_start),
    //         .o_process_finished(w_cmd_finished),
    //         .i_process_bank(i_process_bank),

    //         .i_cmd_rect_x1(r_cmd_rect_x1),
    //         .i_cmd_rect_y1(r_cmd_rect_y1),
    //         .i_cmd_rect_x2(r_cmd_rect_x2),
    //         .i_cmd_rect_y2(r_cmd_rect_y2),
    //         .i_cmd_color_red(r_cmd_color_red),
    //         .i_cmd_color_green(r_cmd_color_green),
    //         .i_cmd_color_blue(r_cmd_color_blue),
    //         .i_cmd_color_alpha(r_cmd_color_alpha),
    //         .i_cmd_texture_address(r_cmd_tex_base),

    //         .o_vram_read_address(o_vram_read_address),
    //         .o_vram_read_request(o_vram_read_request),
    //         .i_vram_read_data(i_vram_read_data),
    //         .i_vram_read_data_valid(i_vram_read_data_valid),
    //         .o_vram_write_address(o_vram_write_address),
    //         .o_vram_write_request(o_vram_write_request),
    //         .o_vram_write_data(o_vram_write_data),
    //         .i_vram_write_done(i_vram_write_done),

    //         .o_flash_read_address(o_flash_read_address),
    //         .o_flash_read_request(o_flash_read_request),
    //         .i_flash_read_data(i_flash_read_data),
    //         .i_flash_read_data_valid(i_flash_read_data_valid)

    //     );




endmodule
