

module MCUController (
        // clock
        i_master_clk,

        // UART interface
        i_uart_rx,
        o_uart_tx,

        // STATUS CONTROLLER interface (master clock domain)
        i_status_vsync,
        i_status_interrupt,
        o_status_request,
        i_status_data,

        // SYSTEM CONTROLLER interface (master clock domain)
        o_system_mode,
        o_system_mode_valid,

        // QUEUE CONTROLLER interface (master clock domain)
        o_queue_data,
        o_queue_data_valid,
        o_queue_start,
        o_queue_end,

        // STORAGE CONTROLLER interface (master clock domain)
        o_storage_data,
        o_storage_data_valid,
        o_storage_start,

        // PLAYBACK CONTROLLER interface (master clock domain)
        o_playback_address,
        o_playback_address_valid
    );

    input       i_master_clk;

    input       i_uart_rx;
    output      o_uart_tx;

    input       i_status_vsync;
    input       i_status_interrupt;
    output      o_status_request;
    input[7:0]  i_status_data;

    output[1:0] o_system_mode;
    output      o_system_mode_valid;

    output[7:0] o_queue_data;
    output      o_queue_data_valid;
    output      o_queue_start;
    output      o_queue_end;

    output[7:0] o_storage_data;
    output      o_storage_data_valid;
    output      o_storage_start;

    output[17:0]    o_playback_address;
    output          o_playback_address_valid;


    parameter   CLOCK_FREQ  = 12000000;
    parameter   BOUD_RATE   = 115200;

    // ***********************************************
    // **                                           **
    // **   UART DECODER                            **
    // **                                           **
    // ***********************************************

    wire[7:0]   w_rx_cmd;
    wire        w_rx_cmd_valid;
    wire[7:0]   w_rx_data;
    wire        w_rx_data_valid;
    wire        w_rx_end;

    UARTDecoder #(
            .CLOCK_FREQ(CLOCK_FREQ),
            .BOUD_RATE(BOUD_RATE)
    ) uart_decoder (
            .i_master_clk(i_master_clk),

            .i_uart_rx(i_uart_rx),

            .o_data(w_rx_data),
            .o_data_valid(w_rx_data_valid),
            .o_cmd(w_rx_cmd),
            .o_cmd_valid(w_rx_cmd_valid),
            .o_end(w_rx_end),
            .i_response_sent(r_response_sent)
        );

    // ***********************************************
    // **                                           **
    // **   VSYNC REQUEST                           **
    // **                                           **
    // ***********************************************

    // edge detector
    reg     r_vsync_prev = 0;

    always @(posedge i_master_clk)
        r_vsync_prev <= i_status_vsync;

    wire    w_vsync_trigger = i_status_vsync && !r_vsync_prev;

    // request
    reg     r_vsync_request = 0;

    always @(posedge i_master_clk) begin
        if(w_vsync_trigger)
            r_vsync_request <= 1'b1;
        else if(r_state == STATE_SEND_VSYNC)
            r_vsync_request <= 1'b0;
    end

    // ***********************************************
    // **                                           **
    // **   INTERRUPT REQUEST                       **
    // **                                           **
    // ***********************************************

    // ***********************************************
    // **                                           **
    // **   STATE MACHINE                           **
    // **                                           **
    // ***********************************************

    // commands
    localparam CMD_GET_STATUS               = 8'h00;
    localparam CMD_FILL_QUEUE               = 8'h01;
    localparam CMD_SET_MODE                 = 8'h07;
    localparam CMD_STORE_DATA               = 8'h02;
    localparam CMD_VIDEO_FRAME              = 8'h03;

    // states
    localparam STATE_IDLE                   = 0;
    localparam STATE_SEND_VSYNC             = 1;
    localparam STATE_00_END_WAIT            = 2;
    localparam STATE_00_SEND_START          = 3;
    localparam STATE_00_SEND_CMD            = 4;
    localparam STATE_00_SEND_STATUS         = 5;
    localparam STATE_00_SEND_END            = 6;
    localparam STATE_DONE                   = 7;
    localparam STATE_07_DATA                = 8;
    localparam STATE_07_END_WAIT            = 9;
    localparam STATE_01_START               = 10;
    localparam STATE_01_NEXT                = 11;
    localparam STATE_01_END                 = 12;
    localparam STATE_02_START               = 13;
    localparam STATE_02_NEXT                = 14;
    localparam STATE_02_END                 = 15;
    localparam STATE_03_BYTE0               = 16;
    localparam STATE_03_BYTE1               = 17;
    localparam STATE_03_BYTE2               = 18;
    localparam STATE_03_WAIT_END            = 19;

    reg[4:0] r_state = STATE_IDLE;
    reg[4:0] w_next_state;

    always @(*) begin
        w_next_state = r_state;

        case (r_state)

            STATE_IDLE: begin
                if(w_rx_cmd_valid) begin
                    case (w_rx_cmd)

                        CMD_GET_STATUS:
                            w_next_state = STATE_00_END_WAIT;

                        CMD_SET_MODE:
                            w_next_state = STATE_07_DATA;

                        CMD_FILL_QUEUE:
                            w_next_state = STATE_01_START;

                        CMD_STORE_DATA:
                            w_next_state = STATE_02_START;

                        CMD_VIDEO_FRAME:
                            w_next_state = STATE_03_BYTE0;

                    endcase
                end else if(r_vsync_request)
                    w_next_state = STATE_SEND_VSYNC;
            end

            STATE_00_END_WAIT: begin
                if(w_rx_end)
                    w_next_state = STATE_00_SEND_START;
            end

            STATE_00_SEND_START: begin
                if(!w_uart_tx_busy)
                    w_next_state = STATE_00_SEND_CMD;
            end

            STATE_00_SEND_CMD: begin
                if(!w_uart_tx_busy)
                    w_next_state = STATE_00_SEND_STATUS;
            end

            STATE_00_SEND_STATUS: begin
                if(!w_uart_tx_busy)
                    w_next_state = STATE_00_SEND_END;
            end

            STATE_00_SEND_END: begin
                if(!w_uart_tx_busy)
                    w_next_state = STATE_DONE;
            end

            STATE_DONE:
                w_next_state = STATE_IDLE;

            STATE_SEND_VSYNC: begin
                if(!w_uart_tx_busy)
                    w_next_state = STATE_IDLE;
            end

            STATE_07_DATA: begin
                if(w_rx_data_valid)
                    w_next_state = STATE_07_END_WAIT;
            end

            STATE_07_END_WAIT: begin
                if(w_rx_end)
                    w_next_state = STATE_DONE;
            end

            STATE_01_START:
                w_next_state = STATE_01_NEXT;

            STATE_01_NEXT: begin
                if(w_rx_end)
                    w_next_state = STATE_01_END;
            end

            STATE_01_END:
                w_next_state = STATE_DONE;

            STATE_02_START:
                w_next_state = STATE_02_NEXT;

            STATE_02_NEXT: begin
                if(w_rx_end)
                    w_next_state = STATE_02_END;
            end

            STATE_02_END:
                w_next_state = STATE_DONE;

            STATE_03_BYTE0: begin
                if(w_rx_data_valid)
                    w_next_state = STATE_03_BYTE1;
            end

            STATE_03_BYTE1: begin
                if(w_rx_data_valid)
                    w_next_state = STATE_03_BYTE2;
            end

            STATE_03_BYTE2: begin
                if(w_rx_data_valid)
                    w_next_state = STATE_03_WAIT_END;
            end

            STATE_03_WAIT_END: begin
                if(w_rx_end)
                    w_next_state = STATE_DONE;
            end

        endcase
    end

    always @(posedge i_master_clk)
        r_state <= w_next_state;

    // ***********************************************
    // **                                           **
    // **   RESPONSE SENDER                         **
    // **                                           **
    // ***********************************************

    // UART encoder
    UARTEncoder #(
            .CLOCK_FREQ(CLOCK_FREQ),
            .BOUD_RATE(BOUD_RATE)
        ) uart_encoder (
            .i_master_clk(i_master_clk),

            .o_uart_tx(o_uart_tx),

            .i_tx_data(r_response_data),
            .i_tx_data_request(r_response_request),
            .o_tx_busy(w_uart_tx_busy),
            .i_tx_start_request(r_response_start),
            .i_tx_end_request(r_response_end),
            .i_tx_vsync_request(r_response_vsync),
            .i_tx_interrupt_request(1'b0)  // TODO:
        );

    wire w_uart_tx_busy;

    // response data providers
    reg         r_response_start    = 0;
    reg         r_response_end      = 0;
    reg         r_response_vsync    = 0;
    reg         r_response_request  = 0;
    reg[7:0]    r_response_data;

    always @(posedge i_master_clk) begin
        r_response_vsync <= (w_next_state == STATE_SEND_VSYNC);
        r_response_start <= (w_next_state == STATE_00_SEND_START);
        r_response_end <= (w_next_state == STATE_00_SEND_END);
        r_response_request <= (w_next_state == STATE_00_SEND_CMD || w_next_state == STATE_00_SEND_STATUS);

        case (w_next_state)

            STATE_00_SEND_CMD:
                r_response_data <= CMD_GET_STATUS;

            STATE_00_SEND_STATUS:
                r_response_data <= i_status_data;

        endcase
    end

    // response send flag
    reg     r_response_sent = 0;

    always @(posedge i_master_clk)
        r_response_sent <= (r_state == STATE_DONE);

    // status request
    reg     r_status_request = 0;

    always @(posedge i_master_clk)
        r_status_request <= (w_next_state == STATE_00_SEND_CMD);

    assign o_status_request = r_status_request;

    // ***********************************************
    // **                                           **
    // **   0x07 - SET MODE                         **
    // **                                           **
    // ***********************************************

    reg[1:0]    r_system_mode;
    reg         r_system_mode_valid = 0;

    always @(posedge i_master_clk) begin
        if(r_state == STATE_07_DATA && w_rx_data_valid) begin
            r_system_mode_valid <= 1'b1;
            r_system_mode <= w_rx_data[1:0];
        end else begin
            r_system_mode_valid <= 1'b0;
        end
    end

    assign o_system_mode = r_system_mode;
    assign o_system_mode_valid = r_system_mode_valid;


    // ***********************************************
    // **                                           **
    // **   0x01 - FILL QUEUE                       **
    // **                                           **
    // ***********************************************
    
    reg[7:0]    r_queue_data;
    reg         r_queue_data_valid;
    reg         r_queue_start;
    reg         r_queue_end;

    always @(posedge i_master_clk) begin
        if(r_state == STATE_01_NEXT) begin
            r_queue_data <= w_rx_data;
            r_queue_data_valid <= w_rx_data_valid;
        end
    end

    always @(posedge i_master_clk) begin
        r_queue_start <= (r_state == STATE_01_START);
        r_queue_end <= (r_state == STATE_01_END);
    end

    assign o_queue_data = r_queue_data;
    assign o_queue_data_valid = r_queue_data_valid;
    assign o_queue_start = r_queue_start;
    assign o_queue_end = r_queue_end;

    // ***********************************************
    // **                                           **
    // **   0x02 - STORE DATA                       **
    // **                                           **
    // ***********************************************
    
    reg[7:0]    r_store_data;
    reg         r_store_data_valid;
    reg         r_store_start;

    always @(posedge i_master_clk) begin
        if(r_state == STATE_02_NEXT) begin
            r_store_data <= w_rx_data;
            r_store_data_valid <= w_rx_data_valid;
        end else begin
            r_store_data_valid <= 1'b0;
        end
    end

    always @(posedge i_master_clk) begin
        r_store_start <= (r_state == STATE_02_START);
    end

    assign o_storage_data = r_store_data;
    assign o_storage_data_valid = r_store_data_valid;
    assign o_storage_start = r_store_start;

    // ***********************************************
    // **                                           **
    // **   0x03 - VIDEO FRAME                      **
    // **                                           **
    // ***********************************************

    reg[17:0]   r_frame_address = 0;
    reg         r_frame_address_valid = 0;

    always @(posedge i_master_clk) begin
        
        case (r_state)

            STATE_03_BYTE0: begin
                if(w_rx_data_valid)
                    r_frame_address[17:16] <= w_rx_data[1:0];
            end

            STATE_03_BYTE1: begin
                if(w_rx_data_valid)
                    r_frame_address[15:8] <= w_rx_data;
            end

            STATE_03_BYTE2: begin
                if(w_rx_data_valid)
                    r_frame_address[7:0] <= w_rx_data;
            end

        endcase

    end

    always @(posedge i_master_clk)
        r_frame_address_valid <= (r_state == STATE_03_WAIT_END) && w_rx_end;

    assign o_playback_address = r_frame_address;
    assign o_playback_address_valid = r_frame_address_valid;


endmodule

