
module UARTEncoder(
        // clock
        i_master_clk,

        // UART interface
        o_uart_tx,

        // MCU CONTROLLER interface
        i_tx_data,
        i_tx_data_request,
        o_tx_busy,
        i_tx_start_request,
        i_tx_end_request,
        i_tx_vsync_request,
        i_tx_interrupt_request

    );

    input       i_master_clk;

    output      o_uart_tx;

    input[7:0]  i_tx_data;
    input       i_tx_data_request;
    output      o_tx_busy;
    input       i_tx_start_request;
    input       i_tx_end_request;
    input       i_tx_vsync_request;
    input       i_tx_interrupt_request;


    parameter CLOCK_FREQ = 12000000;
    parameter BOUD_RATE = 115200;

    localparam CLKS_PER_BIT = CLOCK_FREQ / BOUD_RATE;
    localparam COUNTER_MSB = $clog2(CLKS_PER_BIT) - 1;

    // ***********************************************
    // **                                           **
    // **   UART INTERFACE                          **
    // **                                           **
    // ***********************************************

    reg[7:0]    r_uart_tx_data;
    reg         r_uart_tx_data_request = 0;
    wire        w_uart_tx_busy;

    UART_TX #(
            .CLOCK_FREQ(CLOCK_FREQ),
            .BOUD_RATE(BOUD_RATE)
        ) uart (
            .i_master_clk(i_master_clk),

            .o_uart_tx(o_uart_tx),

            .i_tx_data(r_uart_tx_data),
            .i_tx_data_request(r_uart_tx_data_request),
            .o_tx_busy(w_uart_tx_busy)
        );

    // ***********************************************
    // **                                           **
    // **   UART TX ENCODER                         **
    // **                                           **
    // ***********************************************

    // states
    localparam STATE_IDLE           = 0;
    localparam STATE_START          = 1;
    localparam STATE_START_WAIT     = 2;
    localparam STATE_END            = 3;
    localparam STATE_END_WAIT       = 4;
    localparam STATE_HI             = 5;
    localparam STATE_HI_WAIT        = 6;
    localparam STATE_LO             = 7;
    localparam STATE_LO_WAIT        = 8;
    localparam STATE_VSYNC          = 9;
    localparam STATE_VSYNC_WAIT     = 10;
    localparam STATE_INT            = 11;
    localparam STATE_INT_WAIT       = 12;


    reg[3:0]    r_state = STATE_IDLE;
    reg[3:0]    w_next_state;

    // state machine
    always @(*) begin
        w_next_state = r_state;

        case (r_state)

            STATE_IDLE: begin
                if(i_tx_start_request)
                    w_next_state = STATE_START;
                else if(i_tx_end_request)
                    w_next_state = STATE_END;
                else if(i_tx_vsync_request)
                    w_next_state = STATE_VSYNC;
                else if(i_tx_interrupt_request)
                    w_next_state = STATE_INT;
                else if(i_tx_data_request)
                    w_next_state = STATE_HI;
            end

            STATE_START:
                w_next_state = STATE_START_WAIT;

            STATE_END:
                w_next_state = STATE_END_WAIT;

            STATE_VSYNC:
                w_next_state = STATE_VSYNC_WAIT;

            STATE_INT:
                w_next_state = STATE_INT_WAIT;

            STATE_START_WAIT,
            STATE_END_WAIT,
            STATE_VSYNC_WAIT,
            STATE_INT_WAIT: begin
                if(!w_uart_tx_busy)
                    w_next_state = STATE_IDLE;
            end

            STATE_HI:
                w_next_state = STATE_HI_WAIT;

            STATE_HI_WAIT: begin
                if(!w_uart_tx_busy)
                    w_next_state = STATE_LO;
            end

            STATE_LO:
                w_next_state = STATE_LO_WAIT;

            STATE_LO_WAIT: begin
                if(!w_uart_tx_busy)
                    w_next_state = STATE_IDLE;
            end

        endcase
    end

    always @(posedge i_master_clk)
        r_state <= w_next_state;

    // data encoder
    reg[7:0]    w_nibble_lo;
    
    always @(*) begin
        case (i_tx_data[3:0])
            4'h0: w_nibble_lo = "0";
            4'h1: w_nibble_lo = "1";
            4'h2: w_nibble_lo = "2";
            4'h3: w_nibble_lo = "3";
            4'h4: w_nibble_lo = "4";
            4'h5: w_nibble_lo = "5";
            4'h6: w_nibble_lo = "6";
            4'h7: w_nibble_lo = "7";
            4'h8: w_nibble_lo = "8";
            4'h9: w_nibble_lo = "9";
            4'ha: w_nibble_lo = "A";
            4'hb: w_nibble_lo = "B";
            4'hc: w_nibble_lo = "C";
            4'hd: w_nibble_lo = "D";
            4'he: w_nibble_lo = "E";
            4'hf: w_nibble_lo = "F";
        endcase
    end

    reg[7:0]    w_nibble_hi;

    always @(*) begin
        case (i_tx_data[7:4])
            4'h0: w_nibble_hi = "0";
            4'h1: w_nibble_hi = "1";
            4'h2: w_nibble_hi = "2";
            4'h3: w_nibble_hi = "3";
            4'h4: w_nibble_hi = "4";
            4'h5: w_nibble_hi = "5";
            4'h6: w_nibble_hi = "6";
            4'h7: w_nibble_hi = "7";
            4'h8: w_nibble_hi = "8";
            4'h9: w_nibble_hi = "9";
            4'ha: w_nibble_hi = "A";
            4'hb: w_nibble_hi = "B";
            4'hc: w_nibble_hi = "C";
            4'hd: w_nibble_hi = "D";
            4'he: w_nibble_hi = "E";
            4'hf: w_nibble_hi = "F";
        endcase
    end

    reg[7:0]    r_nibble_lo;

    always @(posedge i_master_clk) begin
        if(w_next_state == STATE_HI)
            r_nibble_lo <= w_nibble_lo;
    end
    
    always @(posedge i_master_clk) begin
        case (w_next_state)

            STATE_START:
                r_uart_tx_data <= ":";

            STATE_END:
                r_uart_tx_data <= ";";

            STATE_VSYNC:
                r_uart_tx_data <= "#";

            STATE_INT:
                r_uart_tx_data <= "^";

            STATE_HI:
                r_uart_tx_data <= w_nibble_hi;

            STATE_LO:
                r_uart_tx_data <= r_nibble_lo;

        endcase
    end

    // sending requests
    always @(posedge i_master_clk) begin
        case (w_next_state)

            STATE_START,
            STATE_END,
            STATE_VSYNC,
            STATE_INT,
            STATE_HI,
            STATE_LO:
                r_uart_tx_data_request <= 1'b1;

            default:
                r_uart_tx_data_request <= 1'b0;

        endcase
    end

    // busy state
    reg     r_busy = 0;

    always @(posedge i_master_clk)
        r_busy = (w_next_state != STATE_IDLE);

    assign o_tx_busy = r_busy;


endmodule
