
module UART_TX(
        // clock
        i_master_clk,

        // UART interface
        o_uart_tx,

        // UART CONTROLLER interface
        i_tx_data,
        i_tx_data_request,
        o_tx_busy
    );

    input       i_master_clk;

    output      o_uart_tx;

    input[7:0]  i_tx_data;
    input       i_tx_data_request;
    output      o_tx_busy;


    parameter CLOCK_FREQ = 12000000;
    parameter BOUD_RATE = 115200;

    localparam CLKS_PER_BIT = CLOCK_FREQ / BOUD_RATE;
    localparam COUNTER_MSB = $clog2(CLKS_PER_BIT) - 1;

    // ***********************************************
    // **                                           **
    // **   RAW TX                                  **
    // **                                           **
    // ***********************************************

    // state machine 
    reg                 r_tx_busy = 0;
    reg[8:0]            r_tx_shift;
    reg[3:0]            r_tx_bit;
    reg[COUNTER_MSB:0]  r_tx_timebase = 0;
    reg                 r_tx_timebase_full = 0;
    reg                 r_uart_tx = 1;

    always @(posedge i_master_clk) begin
        if(!r_tx_busy) begin
            r_tx_timebase <= 0;
            r_tx_timebase_full <= 0;
        end else begin
            if(r_tx_timebase == CLKS_PER_BIT) begin
                r_tx_timebase_full <= 1;
                r_tx_timebase <= 0;
            end else begin
                r_tx_timebase_full <= 0;
                r_tx_timebase <= r_tx_timebase + 1;
            end
        end
    end


    always @(posedge i_master_clk) begin
        if(!r_tx_busy) begin
            if(i_tx_data_request) begin
                r_tx_busy           <= 1;
                r_tx_bit            <= 0;
                r_tx_shift          <= { i_tx_data, 1'b0 };
            end
        end else begin
            if (r_tx_timebase_full) begin
                if (r_tx_bit == 10) begin
                    r_tx_busy           <= 0;
                    r_uart_tx           <= 1;
                end else begin
                    r_uart_tx           <= r_tx_shift[0];
                    r_tx_bit            <= r_tx_bit + 1;
                    r_tx_shift          <= { 1'b1, r_tx_shift[8:1] };
                end
            end
        end
    end

    assign o_tx_busy = r_tx_busy;
    assign o_uart_tx = r_uart_tx;


endmodule
