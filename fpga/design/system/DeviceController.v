
module DeviceController(
        // clock
        i_master_clk,

        // SPI interface (mixed clock domain)
        i_spi_cs_n, i_spi_clk, i_spi_mosi, o_spi_miso,

        // STATUS CONTROLLER interface (master clock domain)
        o_status_request,
        i_status_data,

        // SYSTEM CONTROLLER interface (master clock domain)
        o_system_mode,
        o_system_mode_valid,

        // STORAGE CONTROLLER interface (master clock domain)
        o_storage_data,
        o_storage_data_valid,
        o_storage_start,

        // QUEUE CONTROLLER interface (master clock domain)
        o_queue_data,
        o_queue_data_valid,
        o_queue_start,
        o_queue_end,

        // PLAYBACK CONTROLLER interface (master clock domain)
        o_playback_address,
        o_playback_address_valid

    );

    input           i_master_clk;

    input           i_spi_cs_n;
    input           i_spi_clk;
    input           i_spi_mosi;
    output          o_spi_miso;

    output          o_status_request;
    input[7:0]      i_status_data;

    output[1:0]     o_system_mode;
    output          o_system_mode_valid;

    output[7:0]     o_storage_data;
    output          o_storage_data_valid;
    output          o_storage_start;

    output[7:0]     o_queue_data;
    output          o_queue_data_valid;
    output          o_queue_start;
    output          o_queue_end;

    output[18:0]    o_playback_address;
    output          o_playback_address_valid;

    // ***********************************************
    // **                                           **
    // **   SPI SLAVE CONTROLLER                    **
    // **                                           **
    // ***********************************************

    // signals
    wire[7:0]       w_data;
    wire            w_data_valid;
    wire            w_start;
    wire            w_end;

    // SPI controller instance
    SPIController spi_controller (
            .i_master_clk(i_master_clk),

            .i_spi_cs_n(i_spi_cs_n),
            .i_spi_clk(i_spi_clk),
            .i_spi_mosi(i_spi_mosi),
            .o_spi_miso(o_spi_miso),

            .o_master_data(w_data),
            .o_master_data_valid(w_data_valid),
            .o_master_start(w_start),
            .o_master_end(w_end),

            .i_response_data(i_status_data),
            .i_response_data_valid(r_status_valid[1])

        );

    // ***********************************************
    // **                                           **
    // **   BYTE COUNTER                            **
    // **                                           **
    // ***********************************************

    // byte counter
    reg[3:0]    r_byte_counter = 0;

    always @(posedge i_master_clk) begin
        if(w_start)
            r_byte_counter <= 0;
        else if(w_data_valid && (r_byte_counter != 4'hf))
            r_byte_counter <= r_byte_counter + 1;
    end


    // ***********************************************
    // **                                           **
    // **   COMMAND REGISTER                        **
    // **                                           **
    // ***********************************************

    localparam CMD_GET_STATUS           = 0;
    localparam CMD_FILL_QUEUE           = 1;
    localparam CMD_STORE_DATA           = 2;
    localparam CMD_VIDEO_FRAME          = 3;
    localparam CMD_SET_MODE             = 4;

    reg[2:0]        r_command = 0;
    reg             r_command_valid = 0;

    wire            w_cmd_start = w_data_valid && (r_byte_counter == 0);

    always @(posedge i_master_clk) begin
        if(w_start)
            r_command_valid <= 0;
        else if(w_cmd_start) begin
            r_command <= w_data[2:0];
            r_command_valid <= w_data[7:3] == 0;
        end
    end


    // ***********************************************
    // **                                           **
    // **   STATUS BYTE                             **
    // **                                           **
    // ***********************************************

    reg[1:0]        r_status_valid = 0;

    wire            w_status_request = w_cmd_start && (w_data == 0);

    always @(posedge i_master_clk) begin
        r_status_valid <= { r_status_valid[0], w_status_request };
    end

    assign o_status_request = r_status_valid[0];

    // ***********************************************
    // **                                           **
    // **   SET SYSTEM MODE                         **
    // **                                           **
    // ***********************************************

    reg[1:0]        r_system_mode = 0;
    reg             r_system_mode_valid = 0;

    always @(posedge i_master_clk) begin
        if((r_command == CMD_SET_MODE) && r_command_valid && (r_byte_counter == 1)) begin
            r_system_mode <= w_data[1:0];
            r_system_mode_valid <= 1'b1;
        end else begin
            r_system_mode_valid <= 1'b0;
        end
    end

    assign o_system_mode = r_system_mode;
    assign o_system_mode_valid = r_system_mode_valid;


    // ***********************************************
    // **                                           **
    // **   FILL COMMAND QUEUE                      **
    // **                                           **
    // ***********************************************

    reg[7:0]        r_queue_data = 0;
    reg             r_queue_data_valid = 0;
    reg             r_queue_start = 0;
    reg             r_queue_end = 0;

    wire            w_queue_start = w_cmd_start && (w_data == CMD_FILL_QUEUE);

    always @(posedge i_master_clk) begin
        r_queue_start <= w_queue_start;
        if(w_data_valid && (r_command == CMD_FILL_QUEUE) && r_command_valid && (r_byte_counter!=0)) begin
            r_queue_data <= w_data;
            r_queue_data_valid <= 1'b1;
        end else begin
            r_queue_data_valid <= 1'b0;
        end
        r_queue_end <= w_end;
    end

    assign o_queue_data = r_queue_data;
    assign o_queue_data_valid = r_queue_data_valid;
    assign o_queue_start = r_queue_start;
    assign o_queue_end = r_queue_end;


    // ***********************************************
    // **                                           **
    // **   LOAD STORAGE                            **
    // **                                           **
    // ***********************************************

    reg[7:0]        r_storage_data = 0;
    reg             r_storage_data_valid = 0;
    reg             r_storage_start = 0;

    wire            w_storage_start = w_cmd_start && (w_data == CMD_STORE_DATA);

    always @(posedge i_master_clk) begin
        r_storage_start <= w_storage_start;
        if(w_data_valid && (r_command == CMD_STORE_DATA) && r_command_valid && (r_byte_counter!=0)) begin
            r_storage_data <= w_data;
            r_storage_data_valid <= 1'b1;
        end else begin
            r_storage_data_valid <= 1'b0;
        end
    end

    assign o_storage_data = r_storage_data;
    assign o_storage_data_valid = r_storage_data_valid;
    assign o_storage_start = r_storage_start;


    // ***********************************************
    // **                                           **
    // **   SET VIDEO FRAME ADDRESS                 **
    // **                                           **
    // ***********************************************

    reg[18:0]       r_playback_address = 0;
    reg             r_playback_address_valid = 0;

    always @(posedge i_master_clk) begin
        if(w_data_valid && (r_command == CMD_VIDEO_FRAME) && r_command_valid && (r_byte_counter == 1)) begin
            r_playback_address[18:16] <= w_data[2:0];
        end
        if(w_data_valid && (r_command == CMD_VIDEO_FRAME) && r_command_valid && (r_byte_counter == 2)) begin
            r_playback_address[15:8] <= w_data;
        end
        if(w_data_valid && (r_command == CMD_VIDEO_FRAME) && r_command_valid && (r_byte_counter == 3)) begin
            r_playback_address[7:0] <= w_data;
            r_playback_address_valid <= 1'b1;
        end else begin
            r_playback_address_valid <= 1'b0;
        end
    end

    assign o_playback_address = r_playback_address;
    assign o_playback_address_valid = r_playback_address_valid;


endmodule
