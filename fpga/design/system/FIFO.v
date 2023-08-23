

module FIFO (
        // clock
        i_master_clk,

        // write access
        i_write_enabled,
        i_write_data,
        i_write_data_valid,

        // read access
        o_read_available,
        o_read_data,
        i_read_data_consumed
    );

    // parameters
    parameter       SIZE    = 512;
    localparam      MSB     = $clog2(SIZE);
    parameter       WIDTH   = 8;

    input                   i_master_clk;

    input                   i_write_enabled;
    input[WIDTH-1:0]        i_write_data;
    input                   i_write_data_valid;

    output reg              o_read_available;
    output reg[WIDTH-1:0]   o_read_data;
    input                   i_read_data_consumed;


    // memory
    reg[WIDTH-1:0]  fifo[SIZE-1:0];

    // pointers
    reg[MSB-1:0]    r_read_pointer = 0;
    reg[MSB-1:0]    r_write_pointer = 0;

    // DATA AVAILABLE process
    wire[MSB-1:0]   w_next_read_pointer = r_read_pointer + 1;
    wire            w_write_request = i_write_enabled && i_write_data_valid;
    wire            w_empty = (r_read_pointer == r_write_pointer);
    wire            w_next_empty = w_empty || ((w_next_read_pointer == r_write_pointer) && i_read_data_consumed);

    always @(posedge i_master_clk) begin
        o_read_available <= !w_next_empty;
    end

    // READ DATA process
    always @(posedge i_master_clk) begin
        if(!w_empty)
            o_read_data <= fifo[r_read_pointer];
    end

    // READ POINTER UPDATE process
    always @(posedge i_master_clk) begin
        if(!w_empty && i_read_data_consumed)
            r_read_pointer <= r_read_pointer + 1;
    end

    // WRITE DATA process
    always @(posedge i_master_clk) begin
        if(i_write_enabled && i_write_data_valid) begin
            fifo[r_write_pointer] <= i_write_data;
            r_write_pointer <= r_write_pointer + 1;
        end
    end

endmodule
