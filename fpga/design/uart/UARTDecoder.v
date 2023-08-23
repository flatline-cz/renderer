
module UARTDecoder (
        // clock
        i_master_clk,

        // UART interface
        i_uart_rx,

        // MCU CONTROLLER interface
        o_data,
        o_data_valid,
        o_cmd,
        o_cmd_valid,
        o_end,
        i_response_sent

    );

    input       i_master_clk;

    input       i_uart_rx;

    output[7:0] o_data;
    output      o_data_valid;
    output[7:0] o_cmd;
    output      o_cmd_valid;
    output      o_end;

    input       i_response_sent;

    parameter   CLOCK_FREQ  = 12000000;
    parameter   BOUD_RATE   = 115200;

    // ***********************************************
    // **                                           **
    // **   UART INTERFACE                          **
    // **                                           **
    // ***********************************************

    wire[7:0]   w_uart_rx_data;
    wire        w_uart_rx_data_valid;

    UART_RX #(
            .CLOCK_FREQ(CLOCK_FREQ),
            .BOUD_RATE(BOUD_RATE)
        ) uart (
            .i_master_clk(i_master_clk),

            .i_uart_rx(i_uart_rx),

            .o_rx_data(w_uart_rx_data),
            .o_rx_data_valid(w_uart_rx_data_valid)
        );

    // ***********************************************
    // **                                           **
    // **   UART RX DECODER                         **
    // **                                           **
    // ***********************************************

    // HEX decoder
    reg         w_rx_uart_start;
    reg         w_rx_uart_end;
    reg[4:0]    w_rx_nibble;

    always @(*) begin
        w_rx_uart_start = 0;
        w_rx_uart_end = 0;
        w_rx_nibble = 0;

        case (w_uart_rx_data)
            "0": w_rx_nibble = 5'h10;
            "1": w_rx_nibble = 5'h11;
            "2": w_rx_nibble = 5'h12;
            "3": w_rx_nibble = 5'h13;
            "4": w_rx_nibble = 5'h14;
            "5": w_rx_nibble = 5'h15;
            "6": w_rx_nibble = 5'h16;
            "7": w_rx_nibble = 5'h17;
            "8": w_rx_nibble = 5'h18;
            "9": w_rx_nibble = 5'h19;

            "a": w_rx_nibble = 5'h1a;
            "b": w_rx_nibble = 5'h1b;
            "c": w_rx_nibble = 5'h1c;
            "d": w_rx_nibble = 5'h1d;
            "e": w_rx_nibble = 5'h1e;
            "f": w_rx_nibble = 5'h1f;

            "A": w_rx_nibble = 5'h1a;
            "B": w_rx_nibble = 5'h1b;
            "C": w_rx_nibble = 5'h1c;
            "D": w_rx_nibble = 5'h1d;
            "E": w_rx_nibble = 5'h1e;
            "F": w_rx_nibble = 5'h1f;

            ":": w_rx_uart_start = 1;
            ";": w_rx_uart_end = 1;
        endcase
    end

    // pipeline data
    reg         r_rx_start = 0;
    reg         r_rx_end = 0;
    reg[3:0]    r_rx_nibble = 0;
    reg         r_rx_nibble_valid = 0;
    reg         r_rx_valid = 0;

    always @(posedge i_master_clk) begin
        if (w_uart_rx_data_valid) begin
            r_rx_start <= w_rx_uart_start;
            r_rx_end <= w_rx_uart_end;
            r_rx_nibble <= w_rx_nibble[3:0];
            r_rx_nibble_valid <= w_rx_nibble[4];
            r_rx_valid <= 1;
        end else begin
            r_rx_valid <= 0;
        end
    end

    // ***********************************************
    // **                                           **
    // **   UART RX STATE MACHINE                   **
    // **                                           **
    // ***********************************************


    // states
    localparam STATE_IDLE                   = 0;
    localparam STATE_CMD_HI_WAIT            = 1;
    localparam STATE_CMD_HI_DECODE          = 2;
    localparam STATE_CMD_LO_WAIT            = 3;
    localparam STATE_CMD_LO_DECODE          = 4;
    localparam STATE_DATA_HI_WAIT           = 5;
    localparam STATE_DATA_HI_DECODE         = 6;
    localparam STATE_DATA_LO_WAIT           = 7;
    localparam STATE_DATA_LO_DECODE         = 8;
    localparam STATE_END                    = 9;

    reg[3:0]    r_state = STATE_IDLE;
    reg[3:0]    w_next_state;

    always @(*) begin
        w_next_state = r_state;

        case (r_state)

            STATE_IDLE: begin
                if(r_rx_valid && r_rx_start)
                    w_next_state = STATE_CMD_HI_WAIT;
            end

            STATE_CMD_HI_WAIT: begin
                if(r_rx_valid) begin
                    if(r_rx_end)
                        w_next_state = STATE_IDLE;
                    if(r_rx_nibble_valid)
                        w_next_state = STATE_CMD_HI_DECODE;
                    else
                        w_next_state = STATE_CMD_HI_WAIT;
                end
            end

            STATE_CMD_HI_DECODE:
                w_next_state = STATE_CMD_LO_WAIT;

            STATE_CMD_LO_WAIT: begin
                if(r_rx_valid) begin
                    if(r_rx_end)
                        w_next_state = STATE_IDLE;
                    if(r_rx_nibble_valid)
                        w_next_state = STATE_CMD_LO_DECODE;
                    else
                        w_next_state = STATE_CMD_HI_WAIT;
                end
            end

            STATE_CMD_LO_DECODE:
                w_next_state = STATE_DATA_HI_WAIT;

            STATE_DATA_HI_WAIT: begin
                if(r_rx_valid) begin
                    if(r_rx_end)
                        w_next_state = STATE_END;
                    else if(r_rx_nibble_valid)
                        w_next_state = STATE_DATA_HI_DECODE;
                    else
                        w_next_state = STATE_CMD_HI_WAIT;
                end
            end

            STATE_DATA_HI_DECODE:
                w_next_state = STATE_DATA_LO_WAIT;

            STATE_DATA_LO_WAIT: begin
                if(r_rx_valid) begin
                    if(r_rx_end)
                        w_next_state = STATE_IDLE;
                    else if(r_rx_nibble_valid)
                        w_next_state = STATE_DATA_LO_DECODE;
                    else
                        w_next_state = STATE_CMD_HI_WAIT;
                end
            end

            STATE_DATA_LO_DECODE:
                w_next_state = STATE_DATA_HI_WAIT;

            STATE_END: begin
                if(i_response_sent)
                    w_next_state = STATE_IDLE;
            end
                    
                
        endcase
    end

    always @(posedge i_master_clk)
        r_state <= w_next_state;


    reg[7:0]    r_rx_data           = 0;
    reg         r_rx_data_valid     = 0;
    reg[7:0]    r_rx_cmd            = 0;
    reg         r_rx_cmd_valid      = 0;
    reg         r_rx_cmd_end        = 0;

    always @(posedge i_master_clk) begin
        case (w_next_state)

            STATE_CMD_HI_DECODE:
                r_rx_cmd[7:4] <= r_rx_nibble;

            STATE_CMD_LO_DECODE:
                r_rx_cmd[3:0] <= r_rx_nibble;

            STATE_DATA_HI_DECODE:
                r_rx_data[7:4] <= r_rx_nibble;

            STATE_DATA_LO_DECODE:
                r_rx_data[3:0] <= w_rx_nibble;

        endcase

        r_rx_cmd_valid <= (w_next_state == STATE_CMD_LO_DECODE);
        r_rx_data_valid <= (w_next_state == STATE_DATA_LO_DECODE);
        r_rx_cmd_end <= (w_next_state == STATE_END);
    end

    assign o_cmd = r_rx_cmd;
    assign o_cmd_valid = r_rx_cmd_valid;
    assign o_data = r_rx_data;
    assign o_data_valid = r_rx_data_valid;
    assign o_end = r_rx_cmd_end;


endmodule
