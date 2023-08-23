

module QueueController (
        // clock
        i_master_clk,

        // MCU CONTROLLER interface
        i_queue_data,
        i_queue_data_valid,
        i_queue_start,
        i_queue_end,

        // BUFFER CONTROLLER interface
        o_buffer_queue_ready,
        i_buffer_queue_finished,

        // RENDERER CONTROLLER interface
        i_render_start,
        i_render_request,
        o_render_data,
        o_render_data_valid,
        o_render_data_eof,

        // VRAM CONTROLLER READ interface
        o_vram_read_address,
        o_vram_read_request,
        i_vram_read_data,
        i_vram_read_data_valid,

        // VRAM CONTROLLER WRITE interface
        o_vram_write_address,
        o_vram_write_request,
        o_vram_write_data,
        i_vram_write_done,

        // DEBUG interface
        dbg_queue_uploading,
        dbg_queue_rendering

    );

    parameter SIZE_KB = 4;
    localparam  QUEUE_SIZE_BITS = $clog2(SIZE_KB*1024);


    input       i_master_clk;

    input[7:0]  i_queue_data;
    input       i_queue_data_valid;
    input       i_queue_start;
    input       i_queue_end;

    output      o_buffer_queue_ready;
    input       i_buffer_queue_finished;

    input       i_render_start;
    input       i_render_request;
    output[7:0] o_render_data;
    output      o_render_data_valid;
    output      o_render_data_eof;

    output[QUEUE_SIZE_BITS-1:0] o_vram_read_address;
    output      o_vram_read_request;
    input[7:0]  i_vram_read_data;
    input       i_vram_read_data_valid;

    output[QUEUE_SIZE_BITS-1:0] o_vram_write_address;
    output      o_vram_write_request;
    output[7:0] o_vram_write_data;
    input       i_vram_write_done;

    output      dbg_queue_uploading;
    output      dbg_queue_rendering;

    // ***********************************************
    // **                                           **
    // **   QUEUE STATE                             **
    // **                                           **
    // ***********************************************

    localparam STATE_FILL_WAIT4START            = 0;
    localparam STATE_ACCEPTING_DATA             = 1;
    localparam STATE_FILL_WRITEBACK             = 2;
    localparam STATE_FILL_DONE                  = 3;
    localparam STATE_PROCESSING_WAIT            = 4;
    

    reg[2:0]    r_state = STATE_FILL_WAIT4START;
    reg[2:0]    w_next_state;

    always @(*) begin
        w_next_state = r_state;

        case (r_state)

            STATE_FILL_WAIT4START: begin
                if(i_queue_start)
                    w_next_state = STATE_ACCEPTING_DATA;
            end

            STATE_ACCEPTING_DATA: begin
                if(i_queue_end)
                    w_next_state = STATE_FILL_WRITEBACK;
            end

            STATE_FILL_WRITEBACK: begin
                if(r_vram_write_state == VRAM_WRITE_IDLE && !w_fifo_read_available)
                    w_next_state = STATE_FILL_DONE;
            end

            STATE_FILL_DONE:
                w_next_state = STATE_PROCESSING_WAIT;


            STATE_PROCESSING_WAIT: begin
                if(i_buffer_queue_finished)
                    w_next_state = STATE_FILL_WAIT4START;
            end


        endcase
    end

    always @(posedge i_master_clk)
        r_state <= w_next_state;

    // queue upload finished
    reg     r_upload_finished = 0;

    always @(posedge i_master_clk)
        r_upload_finished <= (r_state == STATE_FILL_DONE);

    assign o_buffer_queue_ready = r_upload_finished;
    
    // debug
    assign dbg_queue_uploading = (r_state == STATE_ACCEPTING_DATA) || (r_state == STATE_FILL_WRITEBACK);
    assign dbg_queue_rendering = (r_state == STATE_PROCESSING_WAIT);


    // ***********************************************
    // **                                           **
    // **   WRITE COUNTER                           **
    // **                                           **
    // ***********************************************

    // counter
    reg[QUEUE_SIZE_BITS-1:0]    r_write_counter;

    always @(posedge i_master_clk) begin

        case(r_state)

            STATE_FILL_WAIT4START: begin
                if(i_queue_start)
                    r_write_counter <= 0;
            end

            STATE_ACCEPTING_DATA,
            STATE_FILL_WRITEBACK: begin
                if(r_vram_write_consumed)
                    r_write_counter <= r_write_counter + 1;
            end
        endcase
    end

    // write enabled
    reg         r_fifo_enabled = 0;

    always @(posedge i_master_clk)
        r_fifo_enabled <= (w_next_state == STATE_ACCEPTING_DATA);


    // VRAM write address
    assign      o_vram_write_address = r_write_counter;

    
    // ***********************************************
    // **                                           **
    // **   FIFO INSTANCE                           **
    // **                                           **
    // ***********************************************

    // signals
    wire    w_fifo_read_available;

    // FIFO
    FIFO #( 
            .SIZE(512),
            .WIDTH(8)
        ) fifo (
            .i_master_clk(i_master_clk),

            .i_write_enabled(r_fifo_enabled),
            .i_write_data(i_queue_data),
            .i_write_data_valid(i_queue_data_valid),

            .o_read_data(o_vram_write_data),
            .o_read_available(w_fifo_read_available),
            .i_read_data_consumed(r_vram_write_consumed)

        );


    // ***********************************************
    // **                                           **
    // **   VRAM WRITE process                      **
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
    reg         r_vram_write_request = 0;

    always @(posedge i_master_clk)
        r_vram_write_request <= (r_vram_write_state == VRAM_WRITE_REQUEST);

    assign o_vram_write_request = r_vram_write_request;

    // ***********************************************
    // **                                           **
    // **   READ COUNTER                            **
    // **                                           **
    // ***********************************************

    reg[QUEUE_SIZE_BITS-1:0]    r_read_counter;

    wire[QUEUE_SIZE_BITS-1:0]   w_next_read_counter = r_read_counter + 1;
    wire        w_read_eof = (r_read_counter == r_write_counter);

    always @(posedge i_master_clk) begin

        if(r_state == STATE_PROCESSING_WAIT) begin
            if(i_render_start)
                r_read_counter <= 0;
            else if((r_read_state == STATE_READ_WAIT) && i_vram_read_data_valid && !w_read_eof)
                r_read_counter <= w_next_read_counter;

        end
    end

    assign o_vram_read_address = r_read_counter;


    // ***********************************************
    // **                                           **
    // **   READ process                            **
    // **                                           **
    // ***********************************************

    // states
    localparam STATE_READ_IDLE          = 0;
    localparam STATE_READ_REQUEST       = 1;
    localparam STATE_READ_WAIT          = 2;
    localparam STATE_READ_EOF           = 3;

    // state machine
    reg[1:0]        r_read_state = STATE_READ_IDLE;
    reg[1:0]        w_next_read_state;

    always @(*) begin
        w_next_read_state = r_read_state;

        case (r_read_state)

            STATE_READ_IDLE: begin
                if(i_render_request) begin
                    if(w_read_eof)
                        w_next_read_state = STATE_READ_EOF;
                    else
                        w_next_read_state = STATE_READ_REQUEST;
                end
                
            end

            STATE_READ_REQUEST:
                w_next_read_state = STATE_READ_WAIT;

            STATE_READ_WAIT: begin
                if(i_vram_read_data_valid)
                    w_next_read_state = STATE_READ_IDLE;
            end

            STATE_READ_EOF:
                w_next_read_state = STATE_READ_IDLE;
        endcase

    end

    always @(posedge i_master_clk)
        r_read_state <= w_next_read_state;

    // VRAM read request
    reg         r_read_request = 0;

    always @(posedge i_master_clk)
        r_read_request <= (w_next_read_state == STATE_READ_REQUEST);

    assign o_vram_read_request = r_read_request;



    // output data
    reg[7:0]    r_read_data;
    reg         r_read_data_valid = 0;
    reg         r_read_data_eof = 0;

    always @(posedge i_master_clk) begin

        r_read_data_eof <= (r_read_state == STATE_READ_EOF);
        r_read_data_valid <= (r_read_state == STATE_READ_EOF) || ((r_read_state == STATE_READ_WAIT) && i_vram_read_data_valid);

        if((r_read_state == STATE_READ_WAIT) && i_vram_read_data_valid)
            r_read_data <= i_vram_read_data;

    end

    assign o_render_data_eof = r_read_data_eof;
    assign o_render_data_valid = r_read_data_valid;
    assign o_render_data = r_read_data;


endmodule
