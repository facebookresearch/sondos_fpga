// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

module sondos_i2c_master_core
#(
    parameter int MAX_DATA_BYTES = 1
)(
    input           clk, // main clock
    input           reset,

    input [15:0]    clocks_per_event, // this controls the ratio between the main clock and the i2c clock
                                      // the i2c clock frequency ~= clock frequency / (3 * (clocks_per_event + 1))
                                      // so if clocks_per_event = 99, then i2c clock frequency ~= main clock frequency / 300
    input   i2c_scl_i,
    output  i2c_scl_o,
    output  i2c_scl_t,
    input   i2c_sda_i,
    output  i2c_sda_o,
    output  i2c_sda_t,

    input [MAX_DATA_BYTES*8-1:0]    data_in,
    output [MAX_DATA_BYTES*16-1:0]  data_out,   // the data out is the concatination of {write bytes, read bytes} for validating write data if needed
    input [3:0]                     num_write_data_bytes, // number of bytes to write
    input [3:0]                     num_read_data_bytes,  // number of bytes to read
    input [6:0]                     dev_address,          // i2c device address
    input                           rd_wrb,               // i2c command bit, 1 for read and 0 for write
    input                           start_new_command,    // start new command requests are ignored when data_ready is 0
    output                          data_ready, // ready is deasserted immediately after a start new command signal and asserted when transaction is complete
    output [MAX_DATA_BYTES*2:0]     ack_vector  // the ack vector contains all the ack bits (1-bit command ack, up to MAX_DATA_BYTES bits write acks
                                                // and up to MAX_DATA_BYTES bits read acks)
);

// i2c clock and data vs state
//===========================================================================================================================================================
// SCL STATE        | LOW_0 | LOW_1 | TRI | HIGH | LOW_0 | LOW_1 | TRI | HIGH | LOW_0 | LOW_1 | TRI | HIGH | LOW_0 | LOW_1 | TRI | HIGH | LOW_0 | LOW_1 | TRI
//===========================================================================================================================================================
//                                         ______                       ______                       ______                       ______
// SCL               _____________________|      |_____________________|      |_____________________|      |_____________________|      |____________________
//===========================================================================================================================================================
// SDA                      |         Data[n]            |         Data[n+1]          |         Data[n+2]          |         Data[n+3]          | Data[n+4]
//===========================================================================================================================================================

// please look up the i2c protocol for details on the protocol format for address, read, write and ack
// This core supports sending write bytes then accepting read bytes within the same i2c transation
// while most I2C devices would only read or write in a given transaction, some support writing a memory address before reading data in the same transaction
// and this core can also be used in that case as well by providing non 0 values in both num_write_data_bytes and num_read_data_bytes inputs

// the read_data_sr contains every bit (read and write) that appreared on sda during the last i2c transaction
// each byte has 1 bit ack and we could have up to 2*MAX_DATA_BYTES for the case of simultaneous write then read in the same i2c transaction
// in addition to that there is 1-bit start + 7-bit address + 1-bit rd_wrb + 1-bit command ack + 1-bit stop
localparam int READ_SR_SIZE = (MAX_DATA_BYTES*2)*9 + 11;

typedef enum logic [1:0] {
    ST_CLK_LOW_0  = 2'b00,
    ST_CLK_LOW_1  = 2'b01,
    ST_CLK_TRI    = 2'b10,
    ST_CLK_HIGH   = 2'b11
} scl_state_t;

typedef enum logic [2:0] {
    ST_I2C_IDLE       = 3'b000,
    ST_I2C_START      = 3'b001,
    ST_I2C_ADDRESS    = 3'b011,
    ST_I2C_WR_DATA    = 3'b100,
    ST_I2C_RD_DATA    = 3'b101,
    ST_I2C_STOP_0     = 3'b110,
    ST_I2C_STOP_1     = 3'b111
} i2c_state_t;

logic [15:0] clocks_per_event_r;
logic [15:0] clk_counter;
logic [3:0] bit_counter;
logic [3:0] byte_counter;

logic       reached_event_count;
logic       address_done;
logic       wr_data_done;
logic       rd_data_done;

logic       pending_command;

scl_state_t scl_state;
scl_state_t scl_next_state;

i2c_state_t i2c_state;
i2c_state_t i2c_next_state;

logic   sda_tri;
logic   scl_tri;

(* async_reg="true" *) logic [1:0] scl_i_reg;
(* async_reg="true" *) logic [1:0] sda_i_reg;

logic [READ_SR_SIZE-1:0]        read_data_sr;
logic [MAX_DATA_BYTES*8-1:0]    write_data_sr;
logic [7:0]                     dev_address_sr;
logic [3:0]                     num_write_data_bytes_hold;
logic [3:0]                     num_read_data_bytes_hold;

logic [MAX_DATA_BYTES*16-1:0]   prepared_data_out;
logic [MAX_DATA_BYTES*2:0]      prepared_ack_vector;

assign i2c_scl_o = 1'b0;
assign i2c_scl_t = scl_tri;
assign i2c_sda_o = 1'b0;
assign i2c_sda_t = sda_tri;

assign data_ready = (i2c_state == ST_I2C_IDLE) & ~pending_command;
assign data_out = prepared_data_out;
assign ack_vector =prepared_ack_vector;

// Make the input signals safe by double-registering them
always_ff @(posedge clk) begin
    scl_i_reg <= {scl_i_reg[0], i2c_scl_i};
    sda_i_reg <= {sda_i_reg[0], i2c_sda_i};
end


always_comb begin
    for (int ii=0; ii<MAX_DATA_BYTES*2; ii=ii+1) begin
        prepared_ack_vector[ii] = read_data_sr[(9*ii)+1];
        prepared_data_out[8*ii+:8] = read_data_sr[(9*ii)+2+:8];
    end
    prepared_ack_vector[MAX_DATA_BYTES*2] = read_data_sr[(MAX_DATA_BYTES*18)+1];
end

assign reached_event_count = (clk_counter == clocks_per_event_r);
assign address_done = (i2c_state == ST_I2C_ADDRESS) & reached_event_count & (scl_state == ST_CLK_HIGH) & bit_counter[3];
assign wr_data_done = (i2c_state == ST_I2C_WR_DATA) & reached_event_count & (scl_state == ST_CLK_HIGH) & bit_counter[3] &
                      (byte_counter == num_write_data_bytes_hold);
assign rd_data_done = (i2c_state == ST_I2C_RD_DATA) & reached_event_count & (scl_state == ST_CLK_HIGH) & bit_counter[3] &
                      (byte_counter == num_read_data_bytes_hold);

always_ff @(posedge clk) begin
    case(i2c_state)
        ST_I2C_IDLE     :   sda_tri <= 1'b1;
        ST_I2C_START    :   sda_tri <= 1'b0;
        ST_I2C_ADDRESS  :   if(reached_event_count & (scl_state == ST_CLK_LOW_0) & bit_counter[3]) // get ack for address
                                sda_tri <= 1'b1;
                            else if(reached_event_count & (scl_state == ST_CLK_LOW_0))
                                sda_tri <= dev_address_sr[7];
                            else
                                sda_tri <= sda_tri;

        ST_I2C_WR_DATA  :   if(reached_event_count & (scl_state == ST_CLK_LOW_0) & bit_counter[3]) // get ack for write data
                                sda_tri <= 1'b1;
                            else if(reached_event_count & (scl_state == ST_CLK_LOW_0))
                                sda_tri <= write_data_sr[MAX_DATA_BYTES*8-1];
                            else
                                sda_tri <= sda_tri;

        ST_I2C_RD_DATA  :   if(reached_event_count & (scl_state == ST_CLK_LOW_0) & bit_counter[3]) // give NACK if last read byte or ACK otherwise
                                sda_tri <= (byte_counter == num_read_data_bytes_hold);
                            else if(reached_event_count & (scl_state == ST_CLK_LOW_0))
                                sda_tri <= 1'b1;
                            else
                                sda_tri <= sda_tri;

        ST_I2C_STOP_0   :   if(scl_state == ST_CLK_LOW_1)
                                sda_tri <= 1'b0;
                            else
                                sda_tri <= sda_tri;

        ST_I2C_STOP_1   :   sda_tri <= 1'b0;

        default         :   sda_tri <= 1'b1;
    endcase
end

always_ff @(posedge clk) begin
    if((i2c_state == ST_I2C_IDLE) | (i2c_state == ST_I2C_STOP_1)) scl_tri <= 1'b1;
    else scl_tri <= ~((scl_state == ST_CLK_LOW_0) | (scl_state == ST_CLK_LOW_1));
end

always_ff @(posedge clk) begin
    if(reset) begin
        pending_command <= 1'b0;
        scl_state <= ST_CLK_HIGH;
        i2c_state <= ST_I2C_IDLE;
        clk_counter <= '0;
    end else begin
        pending_command <= (i2c_state == ST_I2C_IDLE)? pending_command | start_new_command : 1'b0;
        scl_state <= scl_next_state;
        i2c_state <= i2c_next_state;
        clk_counter <= (reached_event_count || (scl_state == ST_CLK_TRI))? '0 : clk_counter + 1'b1;
    end
    clocks_per_event_r <= (i2c_state == ST_I2C_IDLE)? clocks_per_event : clocks_per_event_r;
    bit_counter <= ((i2c_state == ST_I2C_IDLE) | (i2c_state == ST_I2C_START))? 4'd0:
                   (reached_event_count & (scl_state == ST_CLK_HIGH) & bit_counter[3])? 4'd0:
                   (reached_event_count & (scl_state == ST_CLK_HIGH))? bit_counter + 1'b1 : bit_counter;

    byte_counter <= ((i2c_state == ST_I2C_IDLE) | address_done | wr_data_done)? 4'd1:
                    (reached_event_count & (scl_state == ST_CLK_HIGH) & bit_counter[3])? byte_counter + 1'b1 : byte_counter;

    write_data_sr <= (i2c_state == ST_I2C_IDLE)? data_in:
                     ((i2c_state == ST_I2C_WR_DATA) & (scl_state == ST_CLK_HIGH) &
                      reached_event_count & ~bit_counter[3])? {write_data_sr[MAX_DATA_BYTES*8-2:0],1'b0} : write_data_sr;

    read_data_sr <= ((i2c_state == ST_I2C_IDLE) | (i2c_state == ST_I2C_START))? read_data_sr :
                    (reached_event_count & (scl_state == ST_CLK_HIGH))? {read_data_sr[READ_SR_SIZE-2:0],sda_i_reg[1]} : read_data_sr;

    dev_address_sr <= (i2c_state == ST_I2C_IDLE)? {dev_address,rd_wrb}:
                      ((i2c_state == ST_I2C_ADDRESS) & (scl_state == ST_CLK_HIGH) & reached_event_count)? {dev_address_sr[6:0],1'b0} : dev_address_sr;

    num_write_data_bytes_hold <= (i2c_state == ST_I2C_IDLE)? num_write_data_bytes : num_write_data_bytes_hold;
    num_read_data_bytes_hold <= (i2c_state == ST_I2C_IDLE)? num_read_data_bytes : num_read_data_bytes_hold;
end

always_comb begin
    case(scl_state)
        ST_CLK_LOW_0    :   if(reached_event_count) scl_next_state = ST_CLK_LOW_1;
                            else scl_next_state = ST_CLK_LOW_0;

        ST_CLK_LOW_1    :   if(reached_event_count) scl_next_state = ST_CLK_TRI;
                            else scl_next_state = ST_CLK_LOW_1;

        ST_CLK_TRI      :   if(scl_i_reg[1]) scl_next_state = ST_CLK_HIGH;
                            else scl_next_state = ST_CLK_TRI;

        ST_CLK_HIGH     :   if(i2c_state == ST_I2C_IDLE) scl_next_state = ST_CLK_HIGH;
                            else if(reached_event_count) scl_next_state = ST_CLK_LOW_0;
                            else scl_next_state = ST_CLK_HIGH;

        default         :   scl_next_state = ST_CLK_HIGH;

    endcase
end

always_comb begin
    case(i2c_state)
        ST_I2C_IDLE     :   if(pending_command & reached_event_count) i2c_next_state = ST_I2C_START;
                            else i2c_next_state = ST_I2C_IDLE;

        ST_I2C_START    :   if(reached_event_count) i2c_next_state = ST_I2C_ADDRESS;
                            else i2c_next_state = ST_I2C_START;

        ST_I2C_ADDRESS  :   if(address_done & (num_write_data_bytes_hold == 4'd0)) i2c_next_state = ST_I2C_RD_DATA;
                            else if(address_done) i2c_next_state = ST_I2C_WR_DATA;
                            else i2c_next_state = ST_I2C_ADDRESS;

        ST_I2C_WR_DATA  :   if(wr_data_done & (num_read_data_bytes_hold == 4'd0)) i2c_next_state = ST_I2C_STOP_0;
                            else if(wr_data_done) i2c_next_state = ST_I2C_RD_DATA;
                            else i2c_next_state = ST_I2C_WR_DATA;

        ST_I2C_RD_DATA  :   if(rd_data_done) i2c_next_state = ST_I2C_STOP_0;
                            else i2c_next_state = ST_I2C_RD_DATA;

        ST_I2C_STOP_0   :   if(reached_event_count & (scl_state ==ST_CLK_LOW_1)) i2c_next_state = ST_I2C_STOP_1;
                            else i2c_next_state = ST_I2C_STOP_0;

        ST_I2C_STOP_1   :   if(reached_event_count) i2c_next_state = ST_I2C_IDLE;
                            else i2c_next_state = ST_I2C_STOP_1;

        default         :   i2c_next_state = ST_I2C_IDLE;
    endcase
end

endmodule
