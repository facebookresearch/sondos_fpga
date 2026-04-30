// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

module htg930_si5341_init
    import htg930_si5341_init_pkg::*;
    #(
        parameter int MAX_DATA_BYTES = 2
    )(
        input                               clk_i,
        input                               reset_i,
        input                               data_ready_i,
        input                               run_i, // Debug signal
        input                               send_next_i, // Debug signal
        input [4:0]                         ack_vector_i,
        input [31:0]                        por_wait_i,
        input [31:0]                        inter_transfer_wait_i,
        input [31:0]                        post_preamble_wait_i,
        input [31:0]                        post_config_wait_i,
        output logic                        start_new_command_o,
        output logic [MAX_DATA_BYTES*8-1:0] data_out_o,
        output logic [6:0]                  dev_address_o,
        output                              rd_wrb_o,
        output logic [3:0]                  num_write_data_bytes_o,
        output [3:0]                        num_read_data_bytes_o,
        output logic                        busy_o,
        output logic [31:0]                 status_code_reg0_o,
        output logic [31:0]                 status_code_reg1_o
    );

    // Register outputs. Inputs to the I2C module need to be held constant
    // during operation.
    logic [6:0]                     dev_address;
    logic [3:0]                     num_write_data_bytes;
    logic [MAX_DATA_BYTES*8-1:0]    data_out;
    logic                           start_new_command;

    always_ff @(posedge clk_i) begin
        if(reset_i) begin
            dev_address_o <= '0;
            num_write_data_bytes_o <= '0;
            data_out_o <= '0;
        end else if(start_new_command) begin
            dev_address_o <= dev_address;
            num_write_data_bytes_o <= num_write_data_bytes;
            data_out_o <= data_out;
        end
    end

    always_ff @(posedge clk_i) begin
        if(reset_i) begin
            start_new_command_o <= 1'b0;
        end else begin
            start_new_command_o <= start_new_command;
        end
    end

    // Only writing for now
    assign rd_wrb_o = 1'b0;
    assign num_read_data_bytes_o = 4'd0;

    // Counter to create gap between I2C transactions
    logic [27:0] wait_counter;
    logic [27:0] wait_counter_next;
    always_ff @(posedge clk_i) begin
        if(reset_i) begin
            wait_counter <= '0;
        end else begin
            wait_counter <= wait_counter_next;
        end
    end

    // ============================== //
    // Configuration Memory Mux
    // ============================== //

    // Multiplex between each configuration array
    typedef enum logic [2:0] {
        PREAMBLE_U24_SEL,
        PREAMBLE_U41_SEL,
        U24_CONFIG_SEL,
        POSTAMBLE_U24_SEL,
        U41_CONFIG_SEL,
        POSTAMBLE_U41_SEL
    } select_counter_t;

    select_counter_t select_counter;
    select_counter_t select_counter_next;
    always_ff @(posedge clk_i) begin
        if(reset_i) begin
            select_counter <= PREAMBLE_U24_SEL;
        end else begin
            select_counter <= select_counter_next;
        end
    end

    logic [27:0] address_counter;
    logic [27:0] address_counter_next;
    logic [23:0] i2c_data;

    always_comb begin
        i2c_data = '0;
        case(select_counter)
            PREAMBLE_U24_SEL:   i2c_data = preamble[address_counter];
            PREAMBLE_U41_SEL:   i2c_data = preamble[address_counter];
            U24_CONFIG_SEL:     i2c_data = u24_configuration[address_counter];
            POSTAMBLE_U24_SEL:  i2c_data = postamble[address_counter];
            U41_CONFIG_SEL:     i2c_data = u41_configuration[address_counter];
            POSTAMBLE_U41_SEL:  i2c_data = postamble[address_counter];
            default: i2c_data = preamble[address_counter];
        endcase
    end

    // Address Counter for iterating over each configuration memory array
    always_ff @(posedge clk_i) begin
        if(reset_i) begin
            address_counter <= '0;
        end else begin
            address_counter <= address_counter_next;
        end
    end

    // Need to keep track of the depth of each array so we know when to reset
    // select_counter
    int mem_depths [0:5] = {
        $size(preamble),
        $size(preamble),
        $size(u24_configuration),
        $size(postamble),
        $size(u41_configuration),
        $size(postamble)
    };

    // Need to know which device address we are sending for each configuration
    // array
    localparam int U24_DEV_ADDR = 'h75;
    localparam int U41_DEV_ADDR = 'h74;
    localparam int U42_DEV_ADDR = 'h70;

    int dev_addr [0:5] = {
        U24_DEV_ADDR,
        U41_DEV_ADDR,
        U24_DEV_ADDR,
        U24_DEV_ADDR,
        U41_DEV_ADDR,
        U41_DEV_ADDR
    };

    // ============================== //
    // State Machine
    // ============================== //

    typedef enum logic [3:0] {
        DONE,
        RESET,
        SEND_I2C_SW_WORD,
        POWER_ON_WAIT,
        WAIT_FOR_NOT_READY,
        CHECK_FOR_ACK,
        POST_TRANSFER_WAIT,
        SEND_FIRST_WORD,
        SEND_SECOND_WORD,
        POST_PREAMBLE_WAIT,
        POST_CONFIG_WAIT,
        ERROR
    } state_t;

    // State register
    (* fsm_safe_state = "default_state" *) state_t state = DONE;
    state_t state_next;

    always @(posedge clk_i) begin
        if(reset_i) begin
            state <= RESET;
        end else begin
            state <= state_next;
        end
    end

    localparam bit [7:0] I2C_SW_CH2_EN = 8'd2;
    localparam bit [7:0] SI5341_PAGE_REG = 8'd1;

    // Lower 3 bits of ack_vector_i are the relavent bits for us.
    // ack_vector_i should return a number of bits asserted equal to num_write_data_bytes_o
    logic ack_error;
    always_comb begin
        ack_error = 1'b0;
        if(num_write_data_bytes_o == 1) begin
            ack_error = |ack_vector_i[1:0];
        end else if(num_write_data_bytes_o == 2) begin
            ack_error = |ack_vector_i[2:0];
        end
    end

    // Keep track of which word we just sent
    typedef enum logic {SENT_FIRST_WORD, SENT_SECOND_WORD} sent_word_t;
    sent_word_t sent_word, sent_word_next;

    always_ff @(posedge clk_i) begin
        if(reset_i) begin
            sent_word <= SENT_FIRST_WORD;
        end else begin
            sent_word <= sent_word_next;
        end
    end


    logic finished_preamble, finished_preamble_next;
    logic finished_config, finished_config_next;
    always_ff @(posedge clk_i) begin
        if(reset_i) begin
            finished_preamble <= 1'b0;
            finished_config <= 1'b0;
        end else begin
            finished_preamble <= finished_preamble_next;
            finished_config <= finished_config_next;
        end
    end

    // Constants for error code
    localparam bit CONFIG_ERROR = 1'b1;
    localparam bit ACK_ERROR    = 1'b1;
    localparam bit NO_ACK_ERROR = 1'b0;

    // State transition and output logic
    always_comb begin
        state_next = state;
        start_new_command = 1'b0;
        num_write_data_bytes = 4'd2;
        address_counter_next = address_counter;
        select_counter_next = select_counter;
        dev_address = dev_addr[select_counter];
        wait_counter_next = wait_counter;
        data_out = '0;
        busy_o = 1'b1;
        sent_word_next = sent_word;
        finished_config_next = finished_config;
        finished_preamble_next = finished_preamble;
        status_code_reg0_o = '0;
        status_code_reg1_o = '0;
        case(state)
            RESET:
                begin
                    busy_o = 1'b0;
                    if(~reset_i) begin
                        state_next = POWER_ON_WAIT;
                    end
                end
            // Wait for the clock chips to wake up after POR
            POWER_ON_WAIT:
                begin
                    if(address_counter == por_wait_i) begin
                        address_counter_next = '0;
                        state_next = SEND_I2C_SW_WORD;
                    end else begin
                        address_counter_next = address_counter + 1;
                    end
                end
            // Send the I2C data that configures the switch so we can talk to
            // the clock generators
            SEND_I2C_SW_WORD:
                begin
                    dev_address = U42_DEV_ADDR;
                    num_write_data_bytes = 4'd1;
                    data_out = {I2C_SW_CH2_EN, 8'd0};
                    if((data_ready_i & send_next_i) | (data_ready_i & run_i)) begin
                        start_new_command = 1'b1;
                        state_next = WAIT_FOR_NOT_READY;
                        sent_word_next = SENT_SECOND_WORD;
                    end
                end
            // Send two words for each I2C write. First word is the upper byte
            // of the address written to register 1. Second word is the lower byte
            // of the address concatinated with the data.
            SEND_FIRST_WORD:
                begin
                    data_out = {SI5341_PAGE_REG, i2c_data[23:16]};
                    if((data_ready_i & send_next_i) | (data_ready_i & run_i)) begin
                        start_new_command = 1'b1;
                        state_next = WAIT_FOR_NOT_READY;
                        sent_word_next = SENT_FIRST_WORD;
                    end
                end
            SEND_SECOND_WORD:
                begin
                    data_out = i2c_data[15:0];
                    if((data_ready_i & send_next_i) | (data_ready_i & run_i)) begin
                        start_new_command = 1'b1;
                        if(address_counter == (mem_depths[select_counter]-1)) begin
                            address_counter_next = '0;
                            select_counter_next = select_counter_t'(select_counter + 1);
                            if(select_counter == select_counter_t'($size(mem_depths)-1)) begin
                                finished_config_next = 1'b1;
                                select_counter_next = PREAMBLE_U24_SEL;
                            end else if(select_counter == PREAMBLE_U41_SEL) begin
                                finished_preamble_next = 1'b1;
                            end else begin
                                sent_word_next = SENT_SECOND_WORD;
                            end
                        end else begin
                            address_counter_next = address_counter + 1;
                            sent_word_next = SENT_SECOND_WORD;
                        end
                        state_next = WAIT_FOR_NOT_READY;
                    end
                end
            // Wait for I2C module to accept the transaction
            WAIT_FOR_NOT_READY:
                if(~data_ready_i) begin
                    state_next = CHECK_FOR_ACK;
                end
            // Check acknowledgement bits after I2C transaction completes
            CHECK_FOR_ACK:
                if(data_ready_i) begin
                    if(ack_error) begin
                        state_next = ERROR;
                    end else begin
                        if(finished_preamble) begin
                            state_next = POST_PREAMBLE_WAIT;
                        end else if(finished_config) begin
                            state_next = POST_CONFIG_WAIT;
                        end else begin
                            state_next = POST_TRANSFER_WAIT;
                        end
                    end
                end
            // Create gap between I2C transactions
            POST_TRANSFER_WAIT:
                if(wait_counter == inter_transfer_wait_i) begin
                    wait_counter_next = '0;
                    if(sent_word == SENT_FIRST_WORD) begin
                        state_next = SEND_SECOND_WORD;
                    end else begin
                        state_next = SEND_FIRST_WORD;
                    end
                end else begin
                    wait_counter_next = wait_counter + 1;
                end
            // Wait for required time after preamble has been written
            POST_PREAMBLE_WAIT:
                if(address_counter == post_preamble_wait_i) begin
                    address_counter_next = '0;
                    state_next = SEND_FIRST_WORD;
                    finished_preamble_next = 1'b0;
                end else if(data_ready_i) begin
                    address_counter_next = address_counter + 1;
                end
            // Wait for required time after full configuration has been
            // written
            POST_CONFIG_WAIT:
                if(address_counter == post_config_wait_i) begin
                    address_counter_next = '0;
                    state_next = DONE;
                end else if(data_ready_i) begin
                    address_counter_next = address_counter + 1;
                end
            DONE:
                begin
                    busy_o = 1'b0;
                    status_code_reg0_o = {28'd0, 1'b1, 2'd0};
                    status_code_reg1_o = '0;
                end
            // Send error code if there was an error
            // status_code_reg0[0] = indicates an ack error
            // status_code_reg0[1] = indicates a configuration error (entered
            // an invalid state in the state machine or an ack error)
            // status_code_reg0[2] = indicates the configuration finished
            // successfully
            // status_code_reg0[31:3] = RESERVED

            // status_code_reg1[15:0] = failed i2c transaction
            // status_code_reg1[22:16] = failed device address
            // status_code_reg1[27:23] = ack vector from I2C module
            // status_code_reg1[31:28] = number of bytes we tried to write
            ERROR:
                begin
                    busy_o = 1'b0;
                    if(ack_error) begin
                        status_code_reg0_o = {29'd0, CONFIG_ERROR, ACK_ERROR};
                        if(num_write_data_bytes_o == 4'd1) begin
                            status_code_reg1_o = {num_write_data_bytes_o, ack_vector_i,
                                dev_address_o, {8'd0, I2C_SW_CH2_EN}};
                        end else begin
                            if(sent_word == SENT_FIRST_WORD) begin
                                status_code_reg1_o = {num_write_data_bytes_o, ack_vector_i,
                                    dev_address_o, {SI5341_PAGE_REG, data_out_o}};
                            end else begin
                                status_code_reg1_o = {num_write_data_bytes_o, ack_vector_i,
                                    dev_address_o, data_out_o};
                            end
                        end
                    end else begin
                        status_code_reg0_o = {29'd0, CONFIG_ERROR, NO_ACK_ERROR};
                    end
                end
            default:
                begin
                    state_next = ERROR;
                    busy_o = 1'b0;
                end
        endcase
    end

endmodule
