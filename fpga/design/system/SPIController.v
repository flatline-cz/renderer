
module SPIController (
        // clock
        i_master_clk,

        // SPI interface (mixed clock domain)
        i_spi_cs_n, i_spi_clk, i_spi_mosi, o_spi_miso,

        // MASTER DATA interface (master clock domain)
        o_master_data,
        o_master_data_valid,
        o_master_start,
        o_master_end,

        // SLAVE RESPONSE interface (master clock domain)
        i_response_data,
        i_response_data_valid

    );

    input           i_master_clk;

    input           i_spi_cs_n;
    input           i_spi_clk;
    input           i_spi_mosi;
    output          o_spi_miso;

    output[7:0] o_master_data;
    output      o_master_data_valid;
    output      o_master_start;
    output      o_master_end;

    input           i_response_data_valid;
    input[7:0]      i_response_data;

    // ***********************************************
    // **                                           **
    // **   SPI SLAVE CONTROLLER                    **
    // **                                           **
    // ***********************************************

    // cross clock domain
    reg[2:0]    xd_clk = 0;
    reg[2:0]    xd_cs = 0;
    reg[2:0]    xd_mosi = 0;

    always @(posedge i_master_clk) begin
        xd_clk <= { xd_clk[1:0], i_spi_clk };
        xd_cs <= { xd_cs[1:0], !i_spi_cs_n };
        xd_mosi <= { xd_mosi[1:0], i_spi_mosi };
    end

    // SIGNAL: falling edge of SCLK
    wire        w_clk_data_in = !xd_clk[2] && xd_clk[1];

    // SIGNAL: rising edge of SCLK
    wire        w_clk_data_out = xd_clk[2] && !xd_clk[1];

    // SIGNAL: SPI RESET
    wire        w_reset = !xd_cs[2];

    reg[2:0]    r_bit_counter = 0;
    reg[7:0]    r_shift_register = 0;


    // SPI machine: bit counter
    always @(posedge i_master_clk) begin
        if(w_reset) begin
            r_bit_counter <= 0;
        end else begin
            if(w_clk_data_in) begin
                r_bit_counter <= r_bit_counter + 1;
            end
        end
    end

    // SPI machine: input shift register
    always @(posedge i_master_clk) begin
        if(!w_reset && w_clk_data_in)
            r_shift_register <= { r_shift_register[6:0], xd_mosi[1] };
    end

    // SPI machine: data output
    reg[7:0]    r_master_data = 0;
    reg         r_master_data_valid = 0;
    always @(posedge i_master_clk) begin
        if(!w_reset && w_clk_data_in && (r_bit_counter == 7)) begin
            r_master_data <= { r_shift_register[6:0], xd_mosi[1] };
            r_master_data_valid <= 1'b1;
        end else begin
            r_master_data_valid <= 1'b0;
        end
    end
    assign o_master_data = r_master_data;
    assign o_master_data_valid = r_master_data_valid;

    // SPI machine: START & END flags
    reg         r_master_start = 0;
    reg         r_master_end = 0;
    always @(posedge i_master_clk) begin
        r_master_start <= !xd_cs[2] && xd_cs[1];
        r_master_end <= xd_cs[2] && !xd_cs[1];
    end
    assign o_master_start = r_master_start;
    assign o_master_end = r_master_end;
        
    
    // SPI machine: response data
    reg[7:0]    r_response_data;
    reg         r_response_data_valid = 0;
    reg[7:0]    r_response_shift_register;

    reg         r_spi_miso = 0;

    always @(posedge i_master_clk) begin

        if(i_response_data_valid) begin
            r_response_data <= i_response_data;
            r_response_data_valid <= 1'b1;
        end

        if((!xd_cs[2] && xd_cs[1]) || ((r_bit_counter == 7) && w_clk_data_in)) begin
            if(r_response_data_valid) begin
                r_response_shift_register <= r_response_data;
                r_response_data_valid <= 1'b0;
            end else begin
                r_response_shift_register <= 8'h5A;
            end
        end

        if(!w_reset && w_clk_data_out) begin
            r_spi_miso <= r_response_shift_register[7];
            r_response_shift_register <= { r_response_shift_register[6:0], 1'b0 };
        end
        
    end

    assign o_spi_miso = r_spi_miso;

endmodule
