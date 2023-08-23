
module FLASHController (
        // clock
        i_master_clk,

        // READ interface
        i_flash_read_address,
        i_flash_read_request,
        o_flash_read_data,
        o_flash_read_data_valid

    );

    input           i_master_clk;

    input[31:0]     i_flash_read_address;
    input           i_flash_read_request;
    output[15:0]    o_flash_read_data;
    output          o_flash_read_data_valid;


    reg[15:0]       memory[4095:0];

    reg[15:0]       r_read_data;
    reg             r_read_data_valid;

    wire[4:0] w_row = i_flash_read_address[12:8];
    wire[6:0] w_col = i_flash_read_address[6:0];

    always @(posedge i_master_clk) begin
        if(i_flash_read_request) begin
            r_read_data <= memory[{w_row, w_col}];
            r_read_data_valid <= 1'b1;
        end else
            r_read_data_valid <= 1'b0;

    end

    assign o_flash_read_data = r_read_data;
    assign o_flash_read_data_valid = r_read_data_valid;

    initial begin
        $readmemh("texture-0.hex", memory);
    end


endmodule
