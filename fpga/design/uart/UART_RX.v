

module UART_RX (
        // clock
        i_master_clk,

        // UART interface
        i_uart_rx,
    
        // UART CONTROLLER interface
        o_rx_data,
        o_rx_data_valid,
    );

    input       i_master_clk;

    input       i_uart_rx;
    
    output[7:0] o_rx_data;
    output      o_rx_data_valid;

    parameter CLOCK_FREQ = 12000000;
    parameter BOUD_RATE = 115200;

    localparam CLKS_PER_BIT = CLOCK_FREQ / BOUD_RATE;
    localparam COUNTER_MSB = $clog2(CLKS_PER_BIT) - 1;


    // ***********************************************
    // **                                           **
    // **   RAW RX                                  **
    // **                                           **
    // ***********************************************

    // clock domain transfer
    reg[1:0]    xd_uart_rx = 2'b11;

    always @(posedge i_master_clk)
        xd_uart_rx <= { xd_uart_rx[0], i_uart_rx };

    wire w_uart_rx = xd_uart_rx[1];

    // RX timebase
    reg[COUNTER_MSB:0]  r_rx_timebase = 0;

    wire    w_rx_timebase_full = (r_rx_timebase == CLKS_PER_BIT - 1);
    reg     r_rx_timebase_full = 0;


    always @(posedge i_master_clk) begin
        case (r_rx_state)

            RX_STATE_IDLE: begin
                if(w_uart_rx==0) begin
                    r_rx_timebase <= CLKS_PER_BIT / 2;
                    r_rx_timebase_full <= 0;
                end
            end

            RX_STATE_DATA,
            RX_STATE_START: begin
                if(r_rx_timebase_full) begin
                    r_rx_timebase <= 0;
                    r_rx_timebase_full <= 0;
                end else begin
                    r_rx_timebase <= r_rx_timebase + 1;
                    r_rx_timebase_full <= (r_rx_timebase == CLKS_PER_BIT - 1);
                end
            end

        endcase
    end

    // RX state machine
    localparam RX_STATE_IDLE        = 0;
    localparam RX_STATE_START       = 1;
    localparam RX_STATE_DATA        = 2;
    localparam RX_STATE_DONE        = 3;

    reg[1:0]    r_rx_state = RX_STATE_IDLE;

    reg[3:0]    r_rx_bit;

    always @(posedge i_master_clk) begin
        case (r_rx_state)

            RX_STATE_IDLE: begin
                if (w_uart_rx == 0) begin
                    r_rx_state <= RX_STATE_START;
                end
            end

            RX_STATE_START: begin
                if(r_rx_timebase_full) begin
                    if(w_uart_rx == 0) begin
                        r_rx_state <= RX_STATE_DATA;
                        r_rx_bit <= 0;
                    end else
                        r_rx_state <= RX_STATE_IDLE;
                end
            end

            RX_STATE_DATA: begin
                if(r_rx_timebase_full) begin
                    if(r_rx_bit[3])
                        r_rx_state <= RX_STATE_DONE;
                    else
                        r_rx_bit <= r_rx_bit + 1;
                end
            end

            RX_STATE_DONE:
                r_rx_state <= RX_STATE_IDLE;

        endcase
    end

    // RX data register
    reg[8:0] r_rx_data;

    always @(posedge i_master_clk) begin
        if(r_rx_state == RX_STATE_DATA && r_rx_timebase_full) begin
            r_rx_data <= { w_uart_rx, r_rx_data[8:1] };
        end
    end

    assign o_rx_data = r_rx_data[7:0];

    // RX stop bit checker
    reg r_rx_data_valid = 0;
    always @(posedge i_master_clk)
        r_rx_data_valid <= (r_rx_state == RX_STATE_DONE && r_rx_data[8] == 1);

    assign o_rx_data_valid = r_rx_data_valid;



endmodule
