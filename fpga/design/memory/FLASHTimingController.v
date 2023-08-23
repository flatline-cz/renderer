
module FLASHTimingController (
        // clock
        i_master_clk,

        // CHIP interface
        i_chip_data,
        o_chip_data,
        o_chip_data_out,
        o_chip_cs_n,
        o_chip_ale,
        o_chip_cle,
        o_chip_we_n,
        o_chip_re_n,
        i_chip_ready,

        // FLASH CONTROLLER interface
        i_cmd_request,
        i_cmd_data,
        o_cmd_done,

        i_rd_request,
        o_rd_data,
        o_rd_data_valid,

        i_ad_request,
        i_ad_data,
        o_ad_done

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

    input           i_cmd_request;
    input[7:0]      i_cmd_data;
    output          o_cmd_done;

    input           i_rd_request;
    output[15:0]    o_rd_data;
    output          o_rd_data_valid;

    input           i_ad_request;
    input[7:0]      i_ad_data;
    output          o_ad_done;


    // ***********************************************
    // **                                           **
    // **   STATE MACHINE                           **
    // **                                           **
    // ***********************************************  

    // state constants
    localparam STATE_CHIP_IDLE                  = 0;
    localparam STATE_CHIP_CMD_ACTIVATE          = 1;
    localparam STATE_CHIP_CMD_WRITE_STROBE      = 2;
    localparam STATE_CHIP_CMD_WRITE_HOLD        = 3;
    localparam STATE_CHIP_READ_ACTIVATE         = 4;
    localparam STATE_CHIP_READ_STROBE           = 5;
    localparam STATE_CHIP_READ_HOLD             = 6;
    localparam STATE_CHIP_AD1_ACTIVATE          = 7;
    localparam STATE_CHIP_AD1_WRITE_STROBE      = 8;
    localparam STATE_CHIP_AD1_WRITE_HOLD        = 9;

    // state itself
    reg[3:0]        r_signal_state  = STATE_CHIP_IDLE;
    reg[3:0]        w_signal_state_next;

    // state machine
    always @(*) begin
        w_signal_state_next = r_signal_state;

        case (r_signal_state)

            STATE_CHIP_IDLE: begin
                if(i_cmd_request)
                    w_signal_state_next = STATE_CHIP_CMD_ACTIVATE;
                else if(i_rd_request)
                    w_signal_state_next = STATE_CHIP_READ_ACTIVATE;
                else if(i_ad_request)
                    w_signal_state_next = STATE_CHIP_AD1_ACTIVATE;
            end

            STATE_CHIP_CMD_ACTIVATE:
                w_signal_state_next = STATE_CHIP_CMD_WRITE_STROBE;

            STATE_CHIP_CMD_WRITE_STROBE:
                w_signal_state_next = STATE_CHIP_CMD_WRITE_HOLD;

            STATE_CHIP_CMD_WRITE_HOLD:
                w_signal_state_next = STATE_CHIP_IDLE;

            STATE_CHIP_READ_ACTIVATE:
                w_signal_state_next = STATE_CHIP_READ_STROBE;

            STATE_CHIP_READ_STROBE:
                w_signal_state_next = STATE_CHIP_READ_HOLD;

            STATE_CHIP_READ_HOLD:
                w_signal_state_next = STATE_CHIP_IDLE;

            STATE_CHIP_AD1_ACTIVATE:
                w_signal_state_next = STATE_CHIP_AD1_WRITE_STROBE;

            STATE_CHIP_AD1_WRITE_STROBE:
                w_signal_state_next = STATE_CHIP_AD1_WRITE_HOLD;

            STATE_CHIP_AD1_WRITE_HOLD:
                w_signal_state_next = STATE_CHIP_IDLE;

        endcase
    end

    always @(posedge i_master_clk)
        r_signal_state <= w_signal_state_next;


    // COMMAND DONE signaling
    reg             r_cmd_done = 0;

    always @(posedge i_master_clk)
        r_cmd_done <= (w_signal_state_next == STATE_CHIP_CMD_WRITE_HOLD);

    assign o_cmd_done = r_cmd_done;

    // DATA VALID signaling
    reg             r_rd_data_valid = 0;
    reg[15:0]       r_rd_data;

    always @(posedge i_master_clk) begin

        r_rd_data_valid <= (w_signal_state_next == STATE_CHIP_READ_HOLD);

        if(w_signal_state_next == STATE_CHIP_READ_HOLD)
            r_rd_data <= i_chip_data;

    end

    assign o_rd_data = r_rd_data;
    assign o_rd_data_valid = r_rd_data_valid;

    // ADDRESS DONE signaling
    reg             r_ad_done = 0;

    always @(posedge i_master_clk)
        r_ad_done <= (w_signal_state_next == STATE_CHIP_AD1_WRITE_HOLD);

    assign o_ad_done = r_ad_done;


    // ***********************************************
    // **                                           **
    // **   CHIP CONTROL SIGNALS                    **
    // **                                           **
    // ***********************************************

    // chip signals
    reg             r_chip_cs_n = 1;
    reg             r_chip_ale = 0;
    reg             r_chip_cle = 0;
    reg             r_chip_we_n = 1;
    reg             r_chip_re_n = 1;

    always @(posedge i_master_clk) begin
        r_chip_cs_n <= (w_signal_state_next == STATE_CHIP_IDLE);
        r_chip_cle <= (w_signal_state_next == STATE_CHIP_CMD_WRITE_STROBE || w_signal_state_next == STATE_CHIP_CMD_WRITE_HOLD);
        r_chip_ale <= (w_signal_state_next == STATE_CHIP_AD1_WRITE_STROBE || w_signal_state_next == STATE_CHIP_AD1_WRITE_HOLD);
        r_chip_we_n <= (w_signal_state_next != STATE_CHIP_CMD_WRITE_STROBE && w_signal_state_next != STATE_CHIP_AD1_WRITE_STROBE);
        r_chip_re_n <= (w_signal_state_next != STATE_CHIP_READ_STROBE);
    end

    assign o_chip_cs_n = r_chip_cs_n;
    assign o_chip_ale = r_chip_ale;
    assign o_chip_cle = r_chip_cle;
    assign o_chip_we_n = r_chip_we_n;
    assign o_chip_re_n = r_chip_re_n;

    // ***********************************************
    // **                                           **
    // **   CHIP DATA BUS                           **
    // **                                           **
    // ***********************************************

    reg             r_chip_data_out_dir = 0;
    reg[15:0]       r_chip_data_out;
    
    always @(posedge i_master_clk) begin
        case(w_signal_state_next)

            STATE_CHIP_CMD_WRITE_STROBE: begin
                r_chip_data_out <= { 8'h0, i_cmd_data };
            end

            STATE_CHIP_AD1_WRITE_STROBE:
                r_chip_data_out <= { 8'h0, i_ad_data };

        endcase

        r_chip_data_out_dir <= (
            w_signal_state_next == STATE_CHIP_CMD_WRITE_STROBE || 
            w_signal_state_next == STATE_CHIP_CMD_WRITE_HOLD ||
            w_signal_state_next == STATE_CHIP_AD1_WRITE_STROBE || 
            w_signal_state_next == STATE_CHIP_AD1_WRITE_HOLD
            );
    end

    assign o_chip_data = r_chip_data_out;
    assign o_chip_data_out = r_chip_data_out_dir;



endmodule
