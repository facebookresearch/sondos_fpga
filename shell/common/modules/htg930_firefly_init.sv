// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

module htg930_firefly_init
    import htg930_firefly_init_pkg::*;
    #(
        parameter int MAX_DATA_BYTES = 2
    )(
        input                               clk_i,
        input                               reset_i,
        input                               data_ready_i,
        input [4:0]                         ack_vector_i,
        input [31:0]                        por_wait_i,
        input [31:0]                        inter_transfer_wait_i,
        output logic                        start_new_command_o,
        output logic [MAX_DATA_BYTES*8-1:0] data_out_o,
        output [6:0]                        dev_address_o,
        output                              rd_wrb_o,
        output [3:0]                        num_write_data_bytes_o,
        output [3:0]                        num_read_data_bytes_o,
        output logic                        busy_o,
        output logic [31:0]                 status_code_o,
        output logic                        reset_firefly_n_o
    );

    // Register outputs. Inputs to the I2C module need to be held constant
    // during operation.
    logic [MAX_DATA_BYTES*8-1:0] data_out;
    logic start_new_command;

    always_ff @(posedge clk_i) begin
        if(reset_i) begin
            data_out_o <= '0;
        end else if(start_new_command) begin
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

    // Always writing 2 bytes
    assign num_write_data_bytes_o = 4'd2;

    // Always device address of 0x50
    assign dev_address_o = 7'h50;

    logic [31:0] address_counter;
    logic [31:0] address_counter_next;

    always_ff @(posedge clk_i) begin
        if(reset_i) begin
            address_counter <= '0;
        end else begin
            address_counter <= address_counter_next;
        end
    end

    // =================================== //
    // State Machine
    // =================================== //

    typedef enum logic [3:0] {
        DONE,
        RESET,
        RESET_FIREFLY,
        POWER_ON_WAIT,
        SEND,
        WAIT_FOR_NOT_READY,
        CHECK_ACK,
        POST_TRANSFER_WAIT,
        ERROR
    } state_t;

    (* fsm_safe_state = "default_state" *) state_t state = DONE;
    state_t state_next;

    always @(posedge clk_i) begin
        if(reset_i) begin
            state <= RESET;
        end else begin
            state <= state_next;
        end
    end

    logic [27:0] wait_counter, wait_counter_next;
    always_ff @(posedge clk_i) begin
        if(reset_i) begin
            wait_counter <= '0;
        end else begin
            wait_counter <= wait_counter_next;
        end
    end

    // Lower 3 bits of ack_vector_i are the relavent bits for us.
    // ack_vector_i should return a number of bits asserted equal to num_write_data_bytes_o

    logic ack_error;
    assign ack_error = |ack_vector_i[2:0];

    always_comb begin
        state_next = state;
        start_new_command = 1'b0;
        address_counter_next = address_counter;
        wait_counter_next = wait_counter;
        busy_o = 1'b1;
        status_code_o = '0;
        reset_firefly_n_o = 1'b1;
        case(state)
            // Wait for reset deassertion
            RESET:
                begin
                    busy_o = 1'b0;
                    reset_firefly_n_o = 1'b0;
                    if(~reset_i) begin
                        state_next = RESET_FIREFLY;
                    end
                end
            // Reset the firefly module
            RESET_FIREFLY:
                begin
                    reset_firefly_n_o = 1'b0;
                    if(wait_counter == por_wait_i) begin
                        wait_counter_next = '0;
                        state_next = POWER_ON_WAIT;
                    end else begin
                        wait_counter_next = wait_counter + 1;
                    end
                end
            // Wait for a period of time after reset deassertion for the chip
            // to wake up
            POWER_ON_WAIT:
                begin
                    if(wait_counter == por_wait_i) begin
                        wait_counter_next = '0;
                        state_next = SEND;
                    end else begin
                        wait_counter_next = wait_counter + 1;
                    end
                end
            // Send I2C transaction
            SEND:
                begin
                    if(data_ready_i) begin
                        start_new_command = 1'b1;
                        state_next = WAIT_FOR_NOT_READY;
                    end
                end
            // Wait for I2C module to accept the transaction
            WAIT_FOR_NOT_READY:
                if(~data_ready_i) begin
                    state_next = CHECK_ACK;
                end
            // Check acknowledgement bits after I2C transaction completes
            CHECK_ACK:
                begin
                    if(data_ready_i) begin
                        if(ack_error) begin
                            state_next = ERROR;
                        end else begin
                            state_next = POST_TRANSFER_WAIT;
                        end
                    end
                end
            // Create gap between I2C transactions
            POST_TRANSFER_WAIT:
                if(wait_counter == inter_transfer_wait_i-1) begin
                    wait_counter_next = '0;
                    if(address_counter == $size(firefly_init)-1) begin
                        state_next = DONE;
                        address_counter_next = '0;
                    end else begin
                        state_next = SEND;
                        address_counter_next = address_counter + 1;
                    end
                end else begin
                    wait_counter_next = wait_counter + 1;
                end
            // Send error code if there was an error
            // status_code[15:0] = failed i2c transaction
            // status_code[22:16] = failed device address
            // status_code[27:23] = ack vector from I2C module
            // status_code[28] = RESERVED
            // status_code[29] = indicates the configuration finished
            // successfully
            // status_code[30] = indicates an ack error
            // status_code[31] = indicates a configuration error (entered
            // an invalid state in the state machine or an ack error)
            ERROR:
                begin
                    busy_o = 1'b0;
                    status_code_o = ack_error ? {1'b1, ack_error, 2'd0, ack_vector_i,
                        dev_address_o, data_out_o} : {1'b1, 31'b0};
                end
            // We're finished with the configuration. Communicate to software.
            DONE:
                begin
                    status_code_o = {2'd0, 1'b1, 29'd0};
                    busy_o = 1'b0;
                end
            default: state_next = ERROR;
        endcase
    end

    assign data_out = firefly_init[address_counter];

endmodule
