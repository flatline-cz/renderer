
module FLASHController (
        // clock
        i_master_clk,

        // FLASH CHIP interface
        i_chip_data,
        o_chip_data,
        o_chip_data_out,
        o_chip_cs_n,
        o_chip_ale,
        o_chip_cle,
        o_chip_we_n,
        o_chip_re_n,
        i_chip_ready,

        // DEBUG interface
        dbg_status

    );

    input           i_master_clk;

    input[15:0]     i_chip_data;
    output[15:0]    o_chip_data;
    output          o_chip_data_out;
    output          o_chip_cs_n;
    output          o_chip_ale;
    output          o_chip_cle;
    output          o_chip_we_n;
    output          o_chip_re_n;
    input           i_chip_ready;

    output[7:0]     dbg_status;


    // ***********************************************
    // **                                           **
    // **   STATE MACHINE                           **
    // **                                           **
    // ***********************************************

    // state constants
    localparam STATE_START                      = 0;
    localparam STATE_RESET_CMD                  = 1;
    localparam STATE_RESET_CMD_DONE             = 2;
    localparam STATE_RESET_WAIT                 = 3;
    localparam STATE_READ_ID_CMD                = 4;
    localparam STATE_READ_ID_CMD_DONE           = 5;
    localparam STATE_READ_ID_AD1                = 6;
    localparam STATE_READ_ID_AD1_DONE           = 7;
    localparam STATE_READ_ID_AD1_WAIT           = 8;
    localparam STATE_READ_ID_READ               = 9;
    localparam STATE_READ_ID_READ_DONE          = 10;
    localparam STATE_IDLE                       = 11;

    reg[4:0]        r_state = STATE_START;
    reg[4:0]        w_state_next;

    always @(*) begin
        w_state_next = r_state;

        case(r_state)

            STATE_START:
                w_state_next = STATE_RESET_CMD;

            STATE_RESET_CMD:
                w_state_next = STATE_RESET_CMD_DONE;

            STATE_RESET_CMD_DONE: begin
                if(w_flash_cmd_done)
                    w_state_next = STATE_RESET_WAIT;
            end

            STATE_RESET_WAIT: begin
                if(r_ws_done)
                    w_state_next = STATE_READ_ID_CMD;
            end

            STATE_READ_ID_CMD:
                w_state_next = STATE_READ_ID_CMD_DONE;

            STATE_READ_ID_CMD_DONE: begin
                if(w_flash_cmd_done)
                    w_state_next = STATE_READ_ID_AD1;
            end

            STATE_READ_ID_AD1:
                w_state_next = STATE_READ_ID_AD1_DONE;

            STATE_READ_ID_AD1_DONE: begin
                if(w_flash_ad1_done)
                    w_state_next = STATE_READ_ID_AD1_WAIT;
            end

            STATE_READ_ID_AD1_WAIT: begin
                if(r_ws_done)
                    w_state_next = STATE_READ_ID_READ;
            end

            STATE_READ_ID_READ:
                w_state_next = STATE_READ_ID_READ_DONE;

            STATE_READ_ID_READ_DONE: begin
                if(w_flash_read_data_valid)
                    w_state_next = STATE_IDLE;
            end


        endcase
    end

    always @(posedge i_master_clk)
        r_state <= w_state_next;

    // ***********************************************
    // **                                           **
    // **   WAIT STATE                              **
    // **                                           **
    // ***********************************************

    localparam WS_COUNT_RESET               = 60000;
    localparam WS_COUNT_GET_STATUS          = 20;

    reg[15:0]   r_ws_counter=0;
    wire[15:0]  w_ws_counter_next = r_ws_counter - 1;

    always @(posedge i_master_clk) begin
        if(r_ws_counter==0) begin
            case (r_state)

                STATE_RESET_CMD_DONE: begin
                    if(w_flash_cmd_done)
                        r_ws_counter <= WS_COUNT_RESET;
                end

                STATE_READ_ID_AD1_DONE: begin
                    if(w_flash_ad1_done)
                        r_ws_counter <= WS_COUNT_GET_STATUS;
                end

            endcase
        end else begin
            r_ws_counter <= w_ws_counter_next;
        end
    end

    reg         r_ws_done = 0;

    always @(posedge i_master_clk)
        r_ws_done <= (w_ws_counter_next == 0);


    // ***********************************************
    // **                                           **
    // **   WRITE COMMAND                           **
    // **                                           **
    // ***********************************************

    // WRITE COMMAND signals
    reg             r_flash_cmd_request;
    reg[7:0]        r_flash_cmd_data;
    wire            w_flash_cmd_done;

    always @(posedge i_master_clk) begin
        case (w_state_next)

            STATE_RESET_CMD: begin
                r_flash_cmd_request <= 1'b1;
                r_flash_cmd_data <= 8'hff;
            end

            STATE_RESET_CMD_DONE:
                r_flash_cmd_request <= 1'b0;

            STATE_READ_ID_CMD: begin
                r_flash_cmd_request <= 1'b1;
                r_flash_cmd_data <= 8'h90;
            end

            STATE_READ_ID_CMD_DONE:
                r_flash_cmd_request <= 1'b0;

        endcase
    end

    // ***********************************************
    // **                                           **
    // **   WRITE ADDRESS (1)                       **
    // **                                           **
    // ***********************************************

    reg         r_flash_ad1_request = 0;
    reg[7:0]   r_flash_ad1_data;
    wire        w_flash_ad1_done;

    always @(posedge i_master_clk)
        r_flash_ad1_request <= (w_state_next == STATE_READ_ID_AD1);

    always @(posedge i_master_clk) begin
        if(w_state_next == STATE_READ_ID_AD1)
            r_flash_ad1_data <= 8'h20;
    end
    
    
    // ***********************************************
    // **                                           **
    // **   READ DATA                               **
    // **                                           **
    // ***********************************************

    reg         r_flash_read_request = 0;
    wire[15:0]  w_flash_read_data;
    wire        w_flash_read_data_valid;

    always @(posedge i_master_clk)
        r_flash_read_request <= (w_state_next == STATE_READ_ID_READ);
    
    assign dbg_status = w_flash_read_data;


    // ***********************************************
    // **                                           **
    // **   FLASH CHIP TIMING                       **
    // **                                           **
    // ***********************************************

    

    // READ DATA signals

    FLASHTimingController chip (
            .i_master_clk(i_master_clk),

            .i_cmd_request(r_flash_cmd_request),
            .i_cmd_data(r_flash_cmd_data),
            .o_cmd_done(w_flash_cmd_done),

            .i_ad_request(r_flash_ad1_request),
            .i_ad_data(r_flash_ad1_data),
            .o_ad_done(w_flash_ad1_done),

            .i_rd_request(r_flash_read_request),
            .o_rd_data(w_flash_read_data),
            .o_rd_data_valid(w_flash_read_data_valid),

            .i_chip_data(i_chip_data),
            .o_chip_data(o_chip_data),
            .o_chip_data_out(o_chip_data_out),
            .o_chip_cs_n(o_chip_cs_n),
            .o_chip_ale(o_chip_ale),
            .o_chip_cle(o_chip_cle),
            .o_chip_we_n(o_chip_we_n),
            .o_chip_re_n(o_chip_re_n)
        );

endmodule
