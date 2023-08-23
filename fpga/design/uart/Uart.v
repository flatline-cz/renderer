

module UART (
        clk,

        // receiving 
        rxd, data_in, data_in_valid, data_in_start, data_in_end,

        // sending
        o_txd, i_tx_byte

    );

    parameter CLOCK_FREQ = 12000000;
    parameter BOUD_RATE = 115200;

    localparam CLKS_PER_BIT = CLOCK_FREQ / BOUD_RATE;

    input clk;
    input rxd;
    output o_txd;
    input[7:0] i_tx_byte;
    output[7:0] data_in;
    output data_in_start;
    output data_in_end;
    output data_in_valid;
    
    // RX component
    wire[7:0] uart_rx_data;
    wire uart_rx_valid;
    UART_RX #( 
            .CLOCK_FREQ(CLOCK_FREQ),
            .BOUD_RATE(BOUD_RATE)
        )
        uart_rx (
            .i_master_clk(clk),
            .i_uart_rx(rxd),
            .o_rx_data(uart_rx_data),
            .o_rx_data_valid(uart_rx_valid)
        );


    // synchronization
    reg synced = 0;
    reg start = 0;
    reg finished = 0;
    reg low_nibble = 0;
    reg high_nibble = 0;
    reg[7:0] r_data_in = 0;
    reg r_data_in_valid = 0;

    // data parsing
    wire p_sync = (uart_rx_data == ":");
    wire p_end = (uart_rx_data == ";");
    wire[3:0] p_nibble = (uart_rx_data>="0" && uart_rx_data<="9") 
        ? (uart_rx_data - "0")
        : ( (uart_rx_data>="a" && uart_rx_data <="f") 
            ? (uart_rx_data + 10 - "a")
            : (uart_rx_data + 10 - "A")
        );
    wire p_nibble_valid = (uart_rx_data>="0" && uart_rx_data<="9") || (uart_rx_data>="a" && uart_rx_data<="f") || (uart_rx_data>="A" && uart_rx_data<="F"); 

    // data processing
    always @(posedge clk) begin
        if(uart_rx_valid) begin
            if(p_sync) begin
                synced <= 1;
                start <= 1;
                high_nibble <= 1;
                low_nibble <= 0;
            end else if(p_end && high_nibble && synced) begin
                synced <= 0;
            end else if(p_nibble_valid && high_nibble && synced) begin
                r_data_in[7:4] <= p_nibble;
                high_nibble <= 0;
                low_nibble <= 1;
            end else if(p_nibble_valid && low_nibble && synced) begin
                r_data_in[3:0] <= p_nibble;
                high_nibble <= 1;
                low_nibble <= 0;
                start <= 0;
            end else begin
                synced <= 0;
                start <= 0;
                low_nibble <= 0;
                high_nibble <= 0;
            end
        end
    end

    always @(posedge clk)
        if(uart_rx_valid && !p_sync && p_end && high_nibble && synced)
            finished <= 1;
        else
            finished <= 0;

    wire w_data_in_valid = uart_rx_valid && !p_sync && p_nibble_valid && low_nibble && synced;
    always @(posedge clk)
        if(w_data_in_valid)            
            r_data_in_valid <= 1'b1;
        else
            r_data_in_valid <= 1'b0;

    reg r_data_in_start = 1'b0;

    always @(posedge clk)
        r_data_in_start <= start && w_data_in_valid;

        
    assign data_in = r_data_in;
    assign data_in_start = r_data_in_start;
    assign data_in_end = finished;
    assign data_in_valid = r_data_in_valid;

    // TX (status reporting)
    reg[13:0] r_tx_idle_counter = 0;
    always @(posedge clk)
        r_tx_idle_counter <= r_tx_idle_counter + 1;


    uart_tx #( 
            .CLKS_PER_BIT(CLKS_PER_BIT)
        )
        uart_tx (
            .i_Clock(clk),
            .o_Tx_Serial(o_txd),
            .i_Tx_DV(tx_strobe),
            .i_Tx_Byte(i_tx_byte)
        );

    wire tx_strobe = r_tx_idle_counter == 0;


endmodule
