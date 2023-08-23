
module VRAMController (
        // master clock domain
        i_master_clk,

        // CHIP INTERFACE (master clock domain)
        o_sram_addr,
        o_sram_data_out,
        i_sram_data_in,
        o_sram_data_dir_out,
        o_sram_oe_n,
        o_sram_we_n,
        o_sram_cs_n,

        // VIDEO CONTROLLER interface (master clock domain)
        i_display_address,
        i_display_start,
        o_display_column,
        o_display_data,
        o_display_data_valid,

        // RENDERER interface (master clock domain)
        i_render_read_address,
        i_render_read_request,
        o_render_read_data,
        o_render_read_data_valid,
        i_render_write_address,
        i_render_write_request,
        i_render_write_data,
        o_render_write_done,

        // TEXTURE CONTROLLER interface (master clock domain)
        i_texture_read_address,
        i_texture_read_request,
        o_texture_read_data,
        o_texture_read_data_valid,

        // VIDEO PLAYBACK DECODER interface
        i_playback_address,
        i_playback_request,
        o_playback_data,
        o_playback_data_valid,

        // COMMAND QUEUE INTERFACE
        i_queue_read_address,
        i_queue_read_request,
        o_queue_read_data,
        o_queue_read_data_valid,
        i_queue_write_address,
        i_queue_write_data,
        i_queue_write_request,
        o_queue_write_done,

        // MCU CONTROLLER interface
        i_mcu_store_address,
        i_mcu_store_request,
        i_mcu_store_data,
        o_mcu_store_done

    );

    input               i_master_clk;

    output reg[19:0]    o_sram_addr;
    output reg[23:0]    o_sram_data_out;
    input[23:0]         i_sram_data_in;
    output reg          o_sram_data_dir_out;
    output reg          o_sram_cs_n;
    output reg          o_sram_oe_n;
    output reg          o_sram_we_n;

    input[19:0]         i_display_address;
    input               i_display_start;
    output[8:0]         o_display_column;
    output[23:0]        o_display_data;
    output              o_display_data_valid;

    input[19:0]         i_render_read_address;
    input               i_render_read_request;
    output[23:0]        o_render_read_data;
    output              o_render_read_data_valid;
    input[19:0]         i_render_write_address;
    input               i_render_write_request;
    input[23:0]         i_render_write_data;
    output              o_render_write_done;

    input[17:0]         i_texture_read_address;
    input               i_texture_read_request;
    output reg[15:0]    o_texture_read_data;
    output reg          o_texture_read_data_valid;

    input[17:0]         i_playback_address;
    input               i_playback_request;
    output reg[15:0]    o_playback_data;
    output reg          o_playback_data_valid;

    input[17:0]         i_queue_read_address;
    input               i_queue_read_request;
    output reg[7:0]     o_queue_read_data;
    output reg          o_queue_read_data_valid;
    input[17:0]         i_queue_write_address;
    input[7:0]          i_queue_write_data;
    input               i_queue_write_request;
    output reg          o_queue_write_done;

    input[18:0]         i_mcu_store_address;
    input               i_mcu_store_request;
    input[7:0]          i_mcu_store_data;
    output reg          o_mcu_store_done;


    // ***********************************************
    // **                                           **
    // **   STATE MACHINE                           **
    // **                                           **
    // ***********************************************

    localparam STATE_IDLE               = 0;
    localparam STATE_DISPLAY_FIRST      = 1;
    localparam STATE_DISPLAY_NEXT       = 2;
    localparam STATE_RENDER_READ        = 3;
    localparam STATE_RENDER_WRITE_ADDR  = 4;
    localparam STATE_RENDER_WRITE_WE    = 5;
    localparam STATE_RENDER_WRITE_WAIT  = 6;
    localparam STATE_DISPLAY_START      = 7;
    localparam STATE_TEXTURE_READ       = 8;
    localparam STATE_PLAYBACK_READ      = 9;
    localparam STATE_QUEUE_READ         = 10;
    localparam STATE_QUEUE_WRITE_READ   = 11;
    localparam STATE_QUEUE_WRITE_ADDR   = 12;
    localparam STATE_QUEUE_WRITE_WE     = 13;
    localparam STATE_QUEUE_WRITE_WAIT   = 14;
    localparam STATE_MCU_WRITE_READ     = 15;
    localparam STATE_MCU_WRITE_ADDR     = 16;
    localparam STATE_MCU_WRITE_WE       = 17;
    localparam STATE_MCU_WRITE_WAIT     = 18;
    

    reg[4:0] r_state = STATE_IDLE;
    reg[4:0] w_next_state;
    reg w_next_cs_n;
    reg w_next_oe_n;
    reg w_next_we_n;
    reg[19:0] w_next_addr;
    reg[23:0] w_next_data_out;
    reg w_next_data_out_dir;

    always @(*) begin
        w_next_state = r_state;
        w_next_cs_n = 1'b1;
        w_next_oe_n = 1'b1;
        w_next_we_n = 1'b1;
        w_next_data_out = 24'h000000;
        w_next_data_out_dir = 1'b0;
        w_next_addr = 20'h00000;

        case (r_state)

            STATE_IDLE: begin
                if(r_display_request) begin
                    w_next_state = STATE_DISPLAY_START;
                    w_next_cs_n = 1'b0;
                end else if(r_queue_write_request) begin
                    w_next_state = STATE_QUEUE_WRITE_READ;
                    w_next_cs_n = 1'b0;
                    w_next_oe_n = 1'b0;
                    w_next_addr = { r_queue_write_address[17], 2'b11, r_queue_write_address[16:0] };
                end else if(r_mcu_write_request) begin
                    w_next_state = STATE_MCU_WRITE_READ;
                    w_next_cs_n = 1'b0;
                    w_next_oe_n = 1'b0;
                    w_next_addr = { r_mcu_write_address[18], 2'b11, r_mcu_write_address[17:1] };
                end else if(r_render_read_request) begin
                    w_next_state = STATE_RENDER_READ;
                    w_next_cs_n = 1'b0;
                    w_next_oe_n = 1'b0;
                    w_next_addr = r_render_read_address;
                end else if(r_render_write_request) begin
                    w_next_state = STATE_RENDER_WRITE_ADDR;
                    w_next_cs_n = 1'b0;
                    w_next_addr = r_render_write_address;
                end else if(r_queue_read_request) begin
                    w_next_state = STATE_QUEUE_READ;
                    w_next_cs_n = 1'b0;
                    w_next_oe_n = 1'b0;
                    w_next_addr = { r_queue_read_address[17], 2'b11, r_queue_read_address[16:0] };
                end else if(r_texture_read_request) begin
                    w_next_state = STATE_TEXTURE_READ;
                    w_next_cs_n = 1'b0;
                    w_next_oe_n = 1'b0;
                    w_next_addr = { r_texture_read_address[17], 2'b11, r_texture_read_address[16:0] };
                end else if(r_playback_request) begin
                    w_next_state = STATE_PLAYBACK_READ;
                    w_next_cs_n = 1'b0;
                    w_next_oe_n = 1'b0;
                    w_next_addr = { r_playback_address[17], 2'b11, r_playback_address[16:0] };
                end
            end

            STATE_DISPLAY_START: begin
                w_next_state = STATE_DISPLAY_FIRST;
                w_next_cs_n = 1'b0;
                w_next_oe_n = 1'b0;
                w_next_addr = r_display_address;
            end

            STATE_DISPLAY_FIRST: begin
                w_next_state = STATE_DISPLAY_NEXT;
                w_next_cs_n = 1'b0;
                w_next_oe_n = 1'b0;
                w_next_addr = r_display_address;
            end

            STATE_DISPLAY_NEXT: begin
                if(r_display_column == 9'h1ff) begin
                    w_next_state = STATE_IDLE;
                end else begin
                    w_next_cs_n = 1'b0;
                    w_next_oe_n = 1'b0;
                    w_next_addr = r_display_address;
                end
            end

            STATE_QUEUE_WRITE_READ: begin
                w_next_state = STATE_QUEUE_WRITE_ADDR;
                w_next_cs_n = 1'b0;
                w_next_addr = { r_queue_write_address[17], 2'b11, r_queue_write_address[16:0] };
            end

            STATE_QUEUE_WRITE_ADDR: begin
                w_next_state = STATE_QUEUE_WRITE_WE;
                w_next_cs_n = 1'b0;
                w_next_data_out = { r_queue_write_data, r_queue_write_cache };
                w_next_data_out_dir = 1'b1;
                w_next_addr = { r_queue_write_address[17], 2'b11, r_queue_write_address[16:0] };
            end

            STATE_QUEUE_WRITE_WE: begin
                w_next_state = STATE_QUEUE_WRITE_WAIT;
                w_next_cs_n = 1'b0;
                w_next_we_n = 1'b0;
                w_next_data_out = { r_queue_write_data, r_queue_write_cache };
                w_next_data_out_dir = 1'b1;
                w_next_addr = { r_queue_write_address[17], 2'b11, r_queue_write_address[16:0] };
            end

            STATE_QUEUE_WRITE_WAIT: begin
                w_next_state = STATE_IDLE;
                w_next_cs_n = 1'b0;
                w_next_data_out = { r_queue_write_data, r_queue_write_cache };
                w_next_data_out_dir = 1'b1;
                w_next_addr = { r_queue_write_address[17], 2'b11, r_queue_write_address[16:0] };
            end

            STATE_MCU_WRITE_READ: begin
                w_next_state = STATE_MCU_WRITE_ADDR;
                w_next_cs_n = 1'b0;
                w_next_addr = { r_mcu_write_address[18], 2'b11, r_mcu_write_address[17:1] };
            end

            STATE_MCU_WRITE_ADDR: begin
                w_next_state = STATE_MCU_WRITE_WE;
                w_next_cs_n = 1'b0;
                w_next_data_out = r_mcu_write_address[0]
                    ? { r_mcu_write_cache[15:0], r_mcu_write_data }
                    : { r_mcu_write_cache[15:8], r_mcu_write_data, r_mcu_write_cache[7:0] };
                w_next_data_out_dir = 1'b1;
                w_next_addr = { r_mcu_write_address[18], 2'b11, r_mcu_write_address[17:1] };
            end

            STATE_MCU_WRITE_WE: begin
                w_next_state = STATE_MCU_WRITE_WAIT;
                w_next_cs_n = 1'b0;
                w_next_we_n = 1'b0;
                w_next_data_out = r_mcu_write_address[0]
                    ? { r_mcu_write_cache[15:0], r_mcu_write_data }
                    : { r_mcu_write_cache[15:8], r_mcu_write_data, r_mcu_write_cache[7:0] };
                w_next_data_out_dir = 1'b1;
                w_next_addr = { r_mcu_write_address[18], 2'b11, r_mcu_write_address[17:1] };
            end

            STATE_MCU_WRITE_WAIT: begin
                w_next_state = STATE_IDLE;
                w_next_cs_n = 1'b0;
                w_next_data_out = r_mcu_write_address[0]
                    ? { r_mcu_write_cache[15:0], r_mcu_write_data }
                    : { r_mcu_write_cache[15:8], r_mcu_write_data, r_mcu_write_cache[7:0] };
                w_next_data_out_dir = 1'b1;
                w_next_addr = { r_mcu_write_address[18], 2'b11, r_mcu_write_address[17:1] };
            end

            STATE_RENDER_READ:
                w_next_state = STATE_IDLE;

            STATE_RENDER_WRITE_ADDR: begin
                w_next_state = STATE_RENDER_WRITE_WE;
                w_next_cs_n = 1'b0;
                w_next_data_out = r_render_write_data;
                w_next_data_out_dir = 1'b1;
                w_next_addr = r_render_write_address;
            end

            STATE_RENDER_WRITE_WE: begin
                w_next_state = STATE_RENDER_WRITE_WAIT;
                w_next_cs_n = 1'b0;
                w_next_we_n = 1'b0;
                w_next_data_out = r_render_write_data;
                w_next_data_out_dir = 1'b1;
                w_next_addr = r_render_write_address;
            end

            STATE_RENDER_WRITE_WAIT: begin
                w_next_state = STATE_IDLE;
                w_next_cs_n = 1'b0;
                w_next_data_out = r_render_write_data;
                w_next_data_out_dir = 1'b1;
                w_next_addr = r_render_write_address;
            end

            STATE_QUEUE_READ:
                w_next_state = STATE_IDLE;

            STATE_TEXTURE_READ:
                w_next_state = STATE_IDLE;

            STATE_PLAYBACK_READ:
                w_next_state = STATE_IDLE;

        endcase

    end

    always @(posedge i_master_clk) begin
        r_state <= w_next_state;
        o_sram_addr <= w_next_addr;
        o_sram_cs_n <= w_next_cs_n;
        o_sram_oe_n <= w_next_oe_n;
        o_sram_we_n <= w_next_we_n;
        o_sram_data_out <= w_next_data_out;
        o_sram_data_dir_out <= w_next_data_out_dir;
    end

    // always @(posedge i_master_clk) begin
    //     case (r_state)

    //         STATE_IDLE: begin
    //             if(r_display_request)
    //                 r_state <= STATE_DISPLAY_START;
    //             else if(r_render_read_request)
    //                 r_state <= STATE_RENDER_READ;
    //             else if(r_render_write_request)
    //                 r_state <= STATE_RENDER_WRITE_ADDR;
    //             else if(r_texture_read_request)
    //                 r_state <= STATE_TEXTURE_READ;
    //             else if(r_playback_request)
    //                 r_state <= STATE_PLAYBACK_READ;
    //             else if(r_queue_read_request)
    //                 r_state <= STATE_QUEUE_READ;
    //             else if(r_queue_write_request)
    //                 r_state <= STATE_QUEUE_WRITE_READ;
                
    //         end

    //         STATE_DISPLAY_START: 
    //             r_state <= STATE_DISPLAY_FIRST;
            
    //         STATE_DISPLAY_FIRST: 
    //             r_state <= STATE_DISPLAY_NEXT;
            
    //         STATE_DISPLAY_NEXT: begin
    //             if(r_display_column == 9'h1ff)
    //                 r_state <= STATE_IDLE;
    //         end

    //         STATE_RENDER_READ: 
    //             r_state <= STATE_IDLE;
            
    //         STATE_RENDER_WRITE_ADDR: 
    //             r_state <= STATE_RENDER_WRITE_WE;

    //         STATE_RENDER_WRITE_WE: 
    //             r_state <= STATE_RENDER_WRITE_WAIT;
            
    //         STATE_RENDER_WRITE_WAIT:
    //             r_state <= STATE_IDLE;
            
    //         STATE_TEXTURE_READ:
    //             r_state <= STATE_IDLE;

    //         STATE_PLAYBACK_READ:
    //             r_state <= STATE_IDLE;

    //         STATE_QUEUE_READ:
    //             r_state <= STATE_IDLE;

    //         STATE_QUEUE_WRITE_READ:
    //             r_state <= STATE_QUEUE_WRITE_IDLE;

    //         STATE_QUEUE_WRITE_IDLE:
    //             r_state <= STATE_QUEUE_WRITE_ADDR;

    //         STATE_QUEUE_WRITE_ADDR:
    //             r_state <= STATE_QUEUE_WRITE_WE;

    //         STATE_QUEUE_WRITE_WE:
    //             r_state <= STATE_QUEUE_WRITE_WAIT;

    //         STATE_QUEUE_WRITE_WAIT:
    //             r_state <= STATE_IDLE;

    //     endcase
    // end

    // // combine control signals
    // wire w_display_cs = (r_state == STATE_DISPLAY_NEXT || r_state == STATE_DISPLAY_FIRST || r_state == STATE_DISPLAY_START );
    // wire w_display_oe = (r_state == STATE_DISPLAY_NEXT || r_state == STATE_DISPLAY_FIRST);
    // wire w_render_oe = (r_state == STATE_RENDER_READ);
    // wire w_render_cs = (r_state == STATE_RENDER_READ || r_state == STATE_RENDER_WRITE_ADDR || r_state == STATE_RENDER_WRITE_WE || r_state === STATE_RENDER_WRITE_WAIT);
    // wire w_render_dir_out = (r_state == STATE_RENDER_WRITE_ADDR || r_state == STATE_RENDER_WRITE_WE || r_state == STATE_RENDER_WRITE_WAIT);
    // wire w_render_we = (r_state == STATE_RENDER_WRITE_WE);

    // wire w_queue_cs = (r_state == STATE_QUEUE_READ || r_state == STATE_QUEUE_WRITE_READ || r_state == STATE_QUEUE_WRITE_ADDR || r_state == STATE_QUEUE_WRITE_WE || r_state == STATE_QUEUE_WRITE_WAIT);
    // wire w_queue_oe = (r_state == STATE_QUEUE_READ || r_state == STATE_QUEUE_WRITE_READ);
    // wire w_queue_we = (r_state == STATE_QUEUE_WRITE_WE);
    // wire w_queue_dir_out = (r_state == STATE_QUEUE_WRITE_ADDR || r_state == STATE_QUEUE_WRITE_WE || r_state == STATE_QUEUE_WRITE_WAIT);

    // assign o_sram_cs_n = ! (w_display_cs || w_render_cs || w_queue_cs);

    // assign o_sram_oe_n = ! (w_display_oe || w_render_oe || w_queue_oe);

    // assign o_sram_we_n = ! (w_render_we || w_queue_we);

    // assign o_sram_data_out = w_render_dir_out ? r_render_write_data 
    //         : w_queue_dir_out ? { r_queue_write_data, r_queue_write_cache }
    //         : 24'b0;

    // assign o_sram_data_dir_out = (w_render_dir_out || w_queue_dir_out);

    // assign o_sram_addr = w_display_oe ? r_display_address 
    //     : w_render_oe ? r_render_read_address 
    //     : w_render_dir_out ? r_render_write_address
    //     : w_queue_oe ? { r_queue_read_address[17], 2'b11, r_queue_read_address[16:0] }
    //     : w_queue_dir_out ? { r_queue_write_address[17], 2'b11, r_queue_write_address[16:0] }
    //     : 20'h0;


    // ***********************************************
    // **                                           **
    // **   DISPLAY READ                            **
    // **                                           **
    // ***********************************************  

    // request
    reg r_display_request = 0;

    always @(posedge i_master_clk) begin
        if(i_display_start)
            r_display_request <= 1;
        else if(r_state == STATE_DISPLAY_FIRST)
            r_display_request <= 0;
    end

    // column counter & address
    reg[8:0] r_display_column = 0;
    reg[19:0] r_display_address = 0;

    always @(posedge i_master_clk) begin
        if(i_display_start) begin
            r_display_column <= 0;
            r_display_address <= i_display_address;
        end
        if(r_state == STATE_DISPLAY_NEXT)
            r_display_column <= r_display_column + 1;
        if(w_next_state == STATE_DISPLAY_NEXT || w_next_state == STATE_DISPLAY_FIRST)
            r_display_address <= r_display_address + 1;
    end

    // output buffer
    reg[23:0] r_display_data = 0;
    reg r_display_data_valid =0;

    always @(posedge i_master_clk) begin
        if(w_next_state == STATE_DISPLAY_NEXT) begin
            r_display_data <= i_sram_data_in;
            r_display_data_valid <= 1;
        end else begin
            r_display_data_valid <= 0;
        end
    end

    // output signals
    assign o_display_column = r_display_column;
    assign o_display_data = r_display_data;
    assign o_display_data_valid = r_display_data_valid;


    // ***********************************************
    // **                                           **
    // **   RENDER READ/WRITE                       **
    // **                                           **
    // ***********************************************  

    // address buffer
    reg[19:0]   r_render_read_address = 0;
    reg[19:0]   r_render_write_address = 0;

    always @(posedge i_master_clk) begin
        if(i_render_read_request)
            r_render_read_address <= i_render_read_address;
        if(i_render_write_request)
            r_render_write_address <= i_render_write_address;
    end

    // read request
    reg r_render_read_request = 0;

    always @(posedge i_master_clk) begin
        if(i_render_read_request)
            r_render_read_request <= 1;
        else if(r_state == STATE_RENDER_READ)
            r_render_read_request <= 0;
    end

    // read data latch
    reg[23:0] r_render_read_data = 0;
    reg r_render_read_data_valid = 0;

    always @(posedge i_master_clk) begin
        if(r_state == STATE_RENDER_READ) begin
            r_render_read_data <= i_sram_data_in;
            r_render_read_data_valid <= 1;
        end else begin
            r_render_read_data_valid <= 0;
        end
    end

    assign o_render_read_data = r_render_read_data;
    assign o_render_read_data_valid = r_render_read_data_valid;


    // write data buffer
    reg[23:0] r_render_write_data = 0;

    always @(posedge i_master_clk) begin
        if(i_render_write_request)
            r_render_write_data <= i_render_write_data;
    end

    // write request
    reg r_render_write_request = 0;

    always @(posedge i_master_clk) begin
        if(i_render_write_request)
            r_render_write_request <= 1;
        else if(r_state == STATE_RENDER_WRITE_ADDR)
            r_render_write_request <= 0;
    end

    // write done flag
    reg r_render_write_done = 0;

    always @(posedge i_master_clk)
        r_render_write_done <= (r_state == STATE_RENDER_WRITE_WAIT);

    assign o_render_write_done = r_render_write_done;


    // ***********************************************
    // **                                           **
    // **   TEXTURE READ                            **
    // **                                           **
    // ***********************************************

    // request & address latch
    reg         r_texture_read_request = 0;
    reg[17:0]   r_texture_read_address;

    always @(posedge i_master_clk) begin
        if(i_texture_read_request) begin
            r_texture_read_request <= 1'b1;
            r_texture_read_address <= i_texture_read_address;
        end else if(r_state == STATE_TEXTURE_READ) begin
            r_texture_read_request <= 1'b0;
        end
    end

    // data & validity flag
    always @(posedge i_master_clk) begin
        if(r_state == STATE_TEXTURE_READ) begin
            o_texture_read_data <= i_sram_data_in[15:0];
            o_texture_read_data_valid <= 1'b1;
        end else begin
            o_texture_read_data_valid <= 1'b0;
        end
    end


    // ***********************************************
    // **                                           **
    // **   PLAYBACK READ                           **
    // **                                           **
    // ***********************************************

    // request & address latch
    reg         r_playback_request = 0;
    reg[17:0]   r_playback_address;

    always @(posedge i_master_clk) begin
        if(i_playback_request) begin
            r_playback_request <= 1'b1;
            r_playback_address <= i_playback_address;
        end else if(r_state == STATE_PLAYBACK_READ) begin
            r_playback_request <= 1'b0;
        end
    end

    // data & validity flag
    always @(posedge i_master_clk) begin
        if(r_state == STATE_PLAYBACK_READ) begin
            o_playback_data <= i_sram_data_in[15:0];
            o_playback_data_valid <= 1'b1;
        end else begin
            o_playback_data_valid <= 1'b0;
        end
    end


    // ***********************************************
    // **                                           **
    // **   QUEUE READ & WRITE                      **
    // **                                           **
    // ***********************************************

    // requests & address latch
    reg[17:0]       r_queue_read_address = 0;
    reg[17:0]       r_queue_write_address = 0;
    reg             r_queue_read_request = 0;
    reg             r_queue_write_request = 0;
    reg[7:0]        r_queue_write_data;

    always @(posedge i_master_clk) begin
        if(i_queue_write_request) begin
            r_queue_write_address <= i_queue_write_address; 
            r_queue_write_data <= i_queue_write_data;
            r_queue_write_request <= 1'b1;
        end else if(i_queue_read_request) begin
            r_queue_read_address <= i_queue_read_address;
            r_queue_read_request <= 1'b1;
        end else if(r_state == STATE_QUEUE_READ) begin
            r_queue_read_request <= 1'b0;
        end else if(r_state == STATE_QUEUE_WRITE_WE) begin
            r_queue_write_request <= 1'b0;
        end
    end

    // data reading
    always @(posedge i_master_clk) begin
        if(r_state == STATE_QUEUE_READ) begin
            o_queue_read_data <= i_sram_data_in[23:16];
            o_queue_read_data_valid <= 1'b1;
        end else begin
            o_queue_read_data_valid <= 1'b0;
        end
    end

    // data cache
    reg[15:0]    r_queue_write_cache;

    always @(posedge i_master_clk) begin
        if(r_state == STATE_QUEUE_WRITE_READ)
            r_queue_write_cache <= i_sram_data_in[15:0];
    end

    // write done flag
    always @(posedge i_master_clk) begin
        o_queue_write_done <= (r_state == STATE_QUEUE_WRITE_WAIT);
    end

    // ***********************************************
    // **                                           **
    // **   MCU WRITE                               **
    // **                                           **
    // ***********************************************

    // request latch
    reg[18:0]   r_mcu_write_address;
    reg[7:0]    r_mcu_write_data;
    reg         r_mcu_write_request = 0;

    always @(posedge i_master_clk) begin
        if(i_mcu_store_request) begin
            r_mcu_write_address <= i_mcu_store_address;
            r_mcu_write_data <= i_mcu_store_data;
            r_mcu_write_request <= 1'b1;
        end else if(r_state == STATE_MCU_WRITE_WE) begin
            r_mcu_write_request <= 1'b0;
        end
    end

    // data cache
    reg[15:0]   r_mcu_write_cache;

    always @(posedge i_master_clk) begin
        if(r_state == STATE_MCU_WRITE_READ) begin
            r_mcu_write_cache <= r_mcu_write_address[0]
                ? {i_sram_data_in[23:8] }
                : {i_sram_data_in[23:16], i_sram_data_in[7:0] };
        end
    end

    // write done flag
    always @(posedge i_master_clk) begin
        o_mcu_store_done <= (r_state == STATE_MCU_WRITE_WAIT);
    end

endmodule
