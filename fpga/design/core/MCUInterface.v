

module MCUInterface (
        clk,

        M1CS,

        SPI_CS_n, SPI_CLK, 
        SPI_MISO, 
        SPI_MOSI,

        LED
    );

    input           clk;

    output          M1CS;

    input           SPI_CS_n;
    input           SPI_CLK;
    output           SPI_MISO;
    input          SPI_MOSI;
    
    output[7:0]     LED;

    assign M1CS = 1'b1;

    // Master clock
    wire w_master_clk;
    PLL_50_35 master_clock_pll (
            .RESET(1'b1),
            .REFERENCECLK(clk),
            .PLLOUTGLOBAL(w_master_clk),
        );
    localparam MASTER_FREQ = 50350000;


    wire[7:0] master_data;
    wire master_data_valid;
    wire master_start;
    wire master_end;

    reg[7:0] status = 0;
    reg status_valid = 0;

    SPIController spi (
            .i_master_clk(w_master_clk),

            .i_spi_cs_n(SPI_CS_n),
            .i_spi_clk(SPI_CLK),
            .i_spi_mosi(SPI_MOSI),
            .o_spi_miso(SPI_MISO),

            .o_master_data(master_data),
            .o_master_data_valid(master_data_valid),
            .o_master_start(master_start),
            .o_master_end(master_end),

            .i_response_data(status),
            .i_response_data_valid(status_valid)

        );

    assign LED =master_cmd;
    // assign LED[0] = master_start;
    // assign LED[1] = SPI_CLK;
    // assign LED[4] = master_end;
    // assign LED[7] = master_data_valid;

    reg cmd = 0;
    reg[7:0] master_cmd = 0;
    always @(posedge w_master_clk) begin
        if(master_start)
            cmd <= 1;

        if(master_data_valid) begin
            if(cmd) begin
                master_cmd <= master_data;
                status <= 8'hfa;
                status_valid <= 1;
            end
            cmd <= 0;
        end else
            status_valid <= 0;
    end




    
    
endmodule
