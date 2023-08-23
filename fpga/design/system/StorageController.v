

module StorageController (
        // clock
        i_master_clk,

        // MCU CONTROLLER interface
        i_mcu_start,
        i_mcu_data,
        i_mcu_data_valid,

        // VRAM CONTROLLER interface
        o_vram_write_address,
        o_vram_write_data,
        o_vram_write_request,
        i_vram_write_done

    );

    parameter           FIFO_SIZE = 1024;

    input               i_master_clk;

    input               i_mcu_start;
    input[7:0]          i_mcu_data;
    input               i_mcu_data_valid;

    output [18:0]       o_vram_write_address;
    output [7:0]        o_vram_write_data;
    output reg          o_vram_write_request;
    input               i_vram_write_done;

    // ***********************************************
    // **                                           **
    // **   DATA DECODING & WRITE PROCESS           **
    // **                                           **
    // ***********************************************

    // write data & strobe
    reg[26:0]       r_fifo_write_data;
    reg             r_fifo_write_data_valid = 0;

    // decoder
    reg[3:0]        r_write_state = 0;

    always @(posedge i_master_clk) begin
        if(i_mcu_start) begin
            r_write_state <= 0;
        end else if(i_mcu_data_valid) begin
            if(r_write_state != 4)
                r_write_state <= r_write_state + 1;
        end
    end

    wire[18:0]      w_fifo_next_address = r_fifo_write_data[26:8] + 1;

    always @(posedge i_master_clk) begin
        if(i_mcu_data_valid) begin
            case (r_write_state)

                0: r_fifo_write_data[26:24] <= i_mcu_data[2:0];
                1: r_fifo_write_data[23:16] <= i_mcu_data;
                2: r_fifo_write_data[15:8] <= i_mcu_data;
                3: r_fifo_write_data[7:0] <= i_mcu_data;
                4: r_fifo_write_data <= { w_fifo_next_address, i_mcu_data };

            endcase
        end
    end

    always @(posedge i_master_clk)
        r_fifo_write_data_valid <= ((r_write_state == 3) || (r_write_state == 4)) && i_mcu_data_valid;


    // ***********************************************
    // **                                           **
    // **   FIFO INSTANCE                           **
    // **                                           **
    // ***********************************************

    // signals
    wire        w_fifo_read_available;

    wire[26:0]  w_fifo_combined_data;

    // FIFO
    FIFO #( 
            .SIZE(FIFO_SIZE),
            .WIDTH(27)
        ) fifo (
            .i_master_clk(i_master_clk),

            .i_write_enabled(1'b1),
            .i_write_data(r_fifo_write_data),
            .i_write_data_valid(r_fifo_write_data_valid),

            .o_read_data(w_fifo_combined_data),
            .o_read_available(w_fifo_read_available),
            .i_read_data_consumed(r_vram_write_consumed)

        );

    assign o_vram_write_address = w_fifo_combined_data[26:8];
    assign o_vram_write_data = w_fifo_combined_data[7:0];

    // ***********************************************
    // **                                           **
    // **   READ PROCESS                            **
    // **                                           **
    // ***********************************************

    // state machine
    localparam VRAM_WRITE_IDLE      = 0;
    localparam VRAM_WRITE_REQUEST   = 1;
    localparam VRAM_WRITE_WAIT      = 2;
    localparam VRAM_WRITE_CONSUMED  = 3;

    reg[1:0]    r_vram_write_state = VRAM_WRITE_IDLE;
    reg[1:0]    w_vram_write_next_state;
    
    always @(*) begin
        w_vram_write_next_state = r_vram_write_state;

        case (r_vram_write_state)

            VRAM_WRITE_IDLE: begin
                if(w_fifo_read_available)
                    w_vram_write_next_state = VRAM_WRITE_REQUEST;
            end

            VRAM_WRITE_REQUEST:
                w_vram_write_next_state = VRAM_WRITE_WAIT;

            VRAM_WRITE_WAIT: begin
                if(i_vram_write_done)
                    w_vram_write_next_state = VRAM_WRITE_CONSUMED;
            end

            VRAM_WRITE_CONSUMED:
                w_vram_write_next_state = VRAM_WRITE_IDLE;

        endcase
    end

    always @(posedge i_master_clk)
        r_vram_write_state <= w_vram_write_next_state;

    // FIFO read data confirmation
    reg         r_vram_write_consumed = 0;

    always @(posedge i_master_clk)
        r_vram_write_consumed <= (r_vram_write_state == VRAM_WRITE_WAIT) && i_vram_write_done;

    // VRAM write request
    always @(posedge i_master_clk)
        o_vram_write_request <= (r_vram_write_state == VRAM_WRITE_REQUEST);


    



endmodule
