
module QueueMemory (
        i_master_clk,

        i_write_address,
        i_write_data,
        i_write_request,
        o_write_done,

        i_read_address,
        i_read_request,
        o_read_data,
        o_read_data_valid

    );

    parameter SIZE_KB = 1;

    localparam SIZE = (SIZE_KB*1024);
    localparam MSB = $clog2(SIZE) - 1;

    input           i_master_clk;

    input[MSB:0]    i_write_address;
    input[7:0]      i_write_data;
    input           i_write_request;
    output          o_write_done;

    input[MSB:0]    i_read_address;
    input           i_read_request;
    output reg[7:0] o_read_data;
    output reg      o_read_data_valid;

    initial begin
        o_read_data = 0;
        o_read_data_valid = 0;
    end


    // memory
    reg[7:0] memory[SIZE-1:0];


    // write process
    reg             r_write_done = 0;

    always @(posedge i_master_clk) begin
        if(i_write_request)
            memory[i_write_address] <= i_write_data;

        r_write_done <= i_write_request;
    end

    assign o_write_done = r_write_done;

    // read process
    always @(posedge i_master_clk) begin
        if(i_read_request)
            o_read_data <= memory[i_read_address];

        o_read_data_valid <= i_read_request;
    end


endmodule
