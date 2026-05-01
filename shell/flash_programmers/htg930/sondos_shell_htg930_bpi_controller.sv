// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.


module sondos_shell_htg930_bpi_controller(
   input clk,
   input reset,
   output [7:0] controller_state,
   output [31:0] current_address,
   input fsm_start,
   input [7:0] fsm_command,
   input [31:0] starting_address,
   input [31:0] ending_address,

   // BPI interface
   output logic [15:0] bpi_dq_o,
   input  logic [15:0] bpi_dq_i,
   output logic [15:0] bpi_dq_t,
   output logic [25:0] bpi_addr,
   output logic        bpi_adv_b,
   output logic        bpi_fcs_b,
   input  logic        bpi_cso_b,
   output logic        bpi_foe_b,
   output logic        bpi_fwe_b,

   output logic data_to_host_valid,
   output [255:0] data_to_host,

   output data_from_host_taken,
   input [255:0] data_from_host
);

// bpi async write data or command Vs clock counter
// with a clock freq <= 250MHz, we let write enable stay low for 12 cycles to satisfy the minimum 40ns low pulse width
//===============================================================================================================================
// write_op_counter |  0 |  1 |  2 |  3 |  4 |  5 |  6 |  7 |  8 |  9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 |  0
//===============================================================================================================================
// addr [25:0]      |                                    Desired  Address / Command Data                                | XXXXX
//===============================================================================================================================
// data [15:0]      |                                    Desired Data / Command Type                                    | XXXXX
//===============================================================================================================================
//                ___________________________                                                   _________________________________
// adv_b                                     |_________________________________________________|
//===============================================================================================================================
//                ______________________                                                             ____________________________
// fwe_b                                |___________________________________________________________|
//===============================================================================================================================
//                __________________                                                                      _______________________
// fcs_b                            |____________________________________________________________________|
//===============================================================================================================================
// foe_b = 1
//===============================================================================================================================
//                                                                                                                  ____
// end_of_write_cycle  ____________________________________________________________________________________________|    |________
// ##############################################################################################################################

// bpi status check Vs clock counter
//==========================================================================================================================================================
// write_op_counter | 0| 1| 2| 3| 4| 5| 6| 7| 8| 9|10|11|12|13|14|15|16|17|18|19| 0| 1| 2| 3| 4| 5| 6| 7| 8| 9|10|11|12|13|14|15|16|17|18|19| 0| 1| 2| 3| 4|
//==========================================================================================================================================================
// state                                ST_CHECK_FOR_WRITE_DONE or ST_CHECK_FOR_ERASE_DONE
//==========================================================================================================================================================
//                                                                                                                            __
// check the status bit _____________________________________________________________________________________________________|  |___________________________
//==========================================================================================================================================================
//       ____________________                                           _____________________________________________________________________
// adv_b                     |_________________________________________|
//==========================================================================================================================================================
//       _____________________________________________________________________________                                              _________
// foe_b                                                                              |____________________________________________|
//==========================================================================================================================================================
//                ________                                                                                                                         _______
// fcs_b                  |_______________________________________________________________________________________________________________________|
//==========================================================================================================================================================
//  fwe_b = 1
// #########################################################################################################################################################


// bpi Async read send address Vs clock counter
//=======================================================================================================================================================
// read_op_counter   |15| 0| 1| 2| 3| 4| 5| 6| 7| 8| 9|10|11|12|13|14|15| 0| 1| 2| 3| 4| 5| 6| 7| 8| 9|10|11|12|13|14|15| 0| 1| 2| 3| 4| 5| 6| 7| 8| 9|10|
//=======================================================================================================================================================
// state                |      ST_LATCH_READ_ADDRESS                    |              ST_READ_DELAY                    | ST_READ_DATA
//=======================================================================================================================================================
// Addr [25:4]      XXX |                                    Desired Word Address
//=======================================================================================================================================================
// Addr [3:0]       XXX |                                   0                                                                                   |   1
//=======================================================================================================================================================
//       _____________________                                     ______________________________________________________________________________________
// adv_b                      |___________________________________|
//=======================================================================================================================================================
//       __________________________________________________________________
// foe_b                                                                   |_____________________________________________________________________________
//=======================================================================================================================================================
//       __________________
// fcs_b                   |_____________________________________________________________________________________________________________________________
//=======================================================================================================================================================
// fwe_b = 1
// ######################################################################################################################################################


// bpi Async read data Vs clock counter
//===========================================================================================================================================================
// read_op_counter   |11|12|13|14|15| 0| 1| 2| 3| 4| 5| 6| 7| 8| 9|10|11|12|13|14|15| 0| 1| 2| 3| 4| 5| 6| 7| 8| 9|10|11|12|13|14|15| 0| 1| 2| 3| 4| 5| 6| 7|
//===========================================================================================================================================================
// state            ST_READ_DELAY   |              ST_READ_DATA
//===========================================================================================================================================================
// Addr [25:4]                                   Desired Word Address
//===========================================================================================================================================================
// Addr [3:0]                                  0            |        1              |           2           |           3           |            4
//===========================================================================================================================================================
// fcs_b = 0,      foe_b = 0,     adv_b = 1
// ##########################################################################################################################################################


function automatic logic [15:0] flip_16_bits ( input logic [15:0] data_in );
   for (int ii = 0; ii < 16; ii = ii + 1) flip_16_bits[ii] = data_in[15 - ii];
endfunction

localparam logic [7:0] CMD_READ_MEM         = 8'h1;
localparam logic [7:0] CMD_WRITE_MEM        = 8'h2;
localparam logic [7:0] CMD_ERASE_MEM        = 8'h3;
localparam logic [7:0] CMD_FPGA_RECONFIG    = 8'h7;

localparam logic [15:0] P_WRITE_OP_SIZE = 16'd511;

localparam logic [15:0] P_FLASH_CMD_READ_CFG_SETUP   = 16'h0060;
localparam logic [15:0] P_FLASH_CMD_READ_CFG_CONFIRM = 16'h0003;
localparam logic [15:0] P_FLASH_CMD_BUFFERED_WRITE_SETUP = 16'h00E9;
localparam logic [15:0] P_FLASH_CMD_BUFFERED_WRITE_CONFIRM = 16'h00D0;
localparam logic [15:0] P_FLASH_CMD_BLOCK_ERASE_SETUP = 16'h0020;
localparam logic [15:0] P_FLASH_CMD_BLOCK_ERASE_CONFIRM = 16'h00D0;
localparam logic [15:0] P_FLASH_CMD_BLOCK_UNLOCK_SETUP = 16'h0060;
localparam logic [15:0] P_FLASH_CMD_BLOCK_UNLOCK_CONFIRM = 16'h00D0;
localparam logic [15:0] P_FLASH_CMD_CLEAR_STATUS_REG  = 16'h0050;

// The below flash commands are not needed/used for now
// localparam logic [15:0] P_FLASH_CMD_READ_ARRAY        = 16'h00FF;
// localparam logic [15:0] P_FLASH_CMD_READ_STATUS_REG   = 16'h0070;
// localparam logic [15:0] P_FLASH_CMD_READ_ID_REG       = 16'h0090;
// localparam logic [15:0] P_FLASH_CMD_PROG_EXT_READ_CFG_SETUP   = 16'h0060;
// localparam logic [15:0] P_FLASH_CMD_PROG_EXT_READ_CFG_CONFIRM = 16'h0004;

typedef enum logic [4:0] {
   ST_IDLE                      = 5'b00_000,
   ST_FPGA_RECONFIG             = 5'b00_001,
   ST_ERROR_STATE               = 5'b00_010,

   ST_SEND_UNLOCK_SETUP         = 5'b00_100,
   ST_SEND_UNLOCK_CONFIRM       = 5'b00_101,
   ST_SEND_READ_CONFIG_SETUP    = 5'b00_110,
   ST_SEND_READ_CONFIG_CONFIRM  = 5'b00_111,

   ST_PREPARE_FOR_READ_DATA     = 5'b01_000,
   ST_LATCH_READ_ADDRESS        = 5'b01_001,
   ST_READ_DELAY                = 5'b01_010,
   ST_READ_DATA                 = 5'b01_011,

   ST_PREPARE_FOR_WRITE         = 5'b10_000,
   ST_WRITE_CLEAR_STATUS_REG    = 5'b10_001,
   ST_SEND_BUF_WRITE_SETUP      = 5'b10_010,
   ST_SEND_WORD_COUNT           = 5'b10_011,
   ST_SEND_WRITE_DATA           = 5'b10_100,
   ST_SEND_BUF_WRITE_CONFIRM    = 5'b10_101,
   ST_CHECK_FOR_WRITE_DONE      = 5'b10_110,

   ST_PREPARE_FOR_ERASE         = 5'b11_000,
   ST_ERASE_CLEAR_STATUS_REG    = 5'b11_001,
   ST_SEND_ERASE_SETUP          = 5'b11_010,
   ST_SEND_ERASE_CONFIRM        = 5'b11_011,
   ST_CHECK_FOR_ERASE_DONE      = 5'b11_100
} state_t;


state_t state;
state_t next_state;

logic flash_status_ready;
logic [25:0] flash_word_address;
logic [4:0] write_op_counter;
logic [3:0] read_op_counter;
logic end_of_write_cycle;
logic end_of_read_cycle;
logic last_segment_in_word;

logic last_word_in_block;
logic write_chip_select_b;
logic write_data_enable_b;
logic capture_read_data;
logic write_address_valid_b;

logic [15:0] bpi_read_data;

logic reconfig_sig;
logic reconfig_sig_sync;

logic sys_clk;

logic [255:0] read_data_buffer;
logic [255:0] write_data_buffer;

logic [3:0] status_check_limiting_counter;
logic perform_status_check;
logic perform_status_request;
logic error_deteced;

logic write_operation;
logic read_operation;
logic read_all_data;
logic wrote_all_data;
logic erased_all_blocks;

assign current_address = {flash_word_address,1'b0};

assign write_operation = (state == ST_SEND_READ_CONFIG_SETUP) | (state == ST_SEND_READ_CONFIG_CONFIRM) | (state == ST_SEND_BUF_WRITE_SETUP) |
                         (state == ST_SEND_WORD_COUNT) | (state == ST_SEND_WRITE_DATA) | (state == ST_SEND_BUF_WRITE_CONFIRM) |
                         (state == ST_SEND_ERASE_SETUP) | (state == ST_SEND_UNLOCK_SETUP) | (state == ST_SEND_ERASE_CONFIRM) |
                         (state == ST_SEND_UNLOCK_CONFIRM) | (state == ST_ERASE_CLEAR_STATUS_REG) | (state == ST_WRITE_CLEAR_STATUS_REG);

assign read_operation = (state == ST_READ_DELAY) | (state == ST_READ_DATA) | (state == ST_CHECK_FOR_WRITE_DONE) | (state == ST_CHECK_FOR_ERASE_DONE);

assign controller_state = state;

assign data_to_host = read_data_buffer;

assign data_from_host_taken = end_of_write_cycle & ((state == ST_SEND_WORD_COUNT) |
                                                    ((state == ST_SEND_WRITE_DATA) & last_segment_in_word & ~last_word_in_block));

assign flash_status_ready = ((state == ST_CHECK_FOR_WRITE_DONE) | (state == ST_CHECK_FOR_ERASE_DONE)) &
                            perform_status_check & (&write_op_counter[3:0]) & bpi_read_data[7];


assign error_deteced = flash_status_ready & ((|bpi_read_data[9:8]) | (|bpi_read_data[6:0]));
////////////////////////////////////////////////////////////////////
/////////////// Registers always blocks ////////////////////////////
////////////////////////////////////////////////////////////////////

always_ff @(posedge clk) begin
   if(reset) begin
      state <= ST_SEND_UNLOCK_SETUP;
      status_check_limiting_counter <= 0;
      perform_status_check <= 1'b0;
      perform_status_request <= 1'b0;
      write_op_counter <= 5'd0;
      end_of_write_cycle <= 1'b0;
      read_op_counter <= 4'd0;
      end_of_read_cycle <= 1'b0;
      write_chip_select_b <= 1'b1;
      write_data_enable_b <= 1'b1;
      write_address_valid_b <= 1'b1;
      bpi_adv_b <= 1'b1;
      bpi_fcs_b <= 1'b1;
      bpi_foe_b <= 1'b1;
      bpi_fwe_b <= 1'b1;
      flash_word_address <= 26'd0;
   end else begin
      state <= next_state;
      status_check_limiting_counter <= (end_of_write_cycle)? status_check_limiting_counter + 1'b1 : status_check_limiting_counter;
      perform_status_request <= (status_check_limiting_counter == 4'd14) & ((state == ST_CHECK_FOR_WRITE_DONE) | (state == ST_CHECK_FOR_ERASE_DONE));
      perform_status_check <= (&status_check_limiting_counter) & ((state == ST_CHECK_FOR_WRITE_DONE) | (state == ST_CHECK_FOR_ERASE_DONE));
      write_op_counter <= (end_of_write_cycle)? 5'd0 : write_op_counter + 1'b1;
      end_of_write_cycle <= (write_op_counter == 5'd18);
      read_op_counter <= read_op_counter + 1'b1;
      end_of_read_cycle <= (read_op_counter == 4'd14);

      write_chip_select_b <= (write_op_counter == 5'd1)? 1'b0 :
                             (write_op_counter == 5'd15)? 1'b1 : write_chip_select_b;

      write_data_enable_b <= (write_op_counter == 5'd2)? 1'b0 :
                             (write_op_counter == 5'd14)? 1'b1 : write_data_enable_b;

      write_address_valid_b <= (write_op_counter == 5'd3)? 1'b0 :
                               (write_op_counter == 5'd13)? 1'b1 : write_address_valid_b;

      bpi_adv_b <= (state == ST_IDLE)? 1'b1:
                   (write_operation)? write_address_valid_b :
                   (perform_status_request)? write_chip_select_b :
                   ((state == ST_LATCH_READ_ADDRESS) & (read_op_counter == 4'd1))? 1'b0 :
                   ((state == ST_LATCH_READ_ADDRESS) & (read_op_counter == 4'd13))? 1'b1 : bpi_adv_b;

      bpi_fcs_b <= ((state == ST_LATCH_READ_ADDRESS) | (state == ST_READ_DELAY) | (state == ST_READ_DATA))? 1'b0 :
                   (write_operation)? write_chip_select_b :
                   (perform_status_check | perform_status_request)? 1'b0 : 1'b1;

      bpi_foe_b <= ((state == ST_READ_DELAY) | (state == ST_READ_DATA))? 1'b0 :
                   (perform_status_check)? write_data_enable_b : 1'b1;

      bpi_fwe_b <= (write_operation)? write_data_enable_b : 1'b1;


      flash_word_address <= (fsm_start)? starting_address[26:1] :
                            ((state == ST_SEND_READ_CONFIG_CONFIRM) & end_of_write_cycle)? flash_word_address + {1'b1,23'd0}:
                            ((state == ST_SEND_UNLOCK_CONFIRM) & end_of_write_cycle)? flash_word_address + {1'b1,17'd0}:
                            ((state == ST_READ_DATA) & capture_read_data)? flash_word_address + 1'b1:
                            ((state == ST_SEND_WRITE_DATA) & end_of_write_cycle & ~last_word_in_block)? flash_word_address + 1'b1:
                            ((state == ST_CHECK_FOR_WRITE_DONE) & flash_status_ready)? flash_word_address + 1'b1:
                            ((state == ST_CHECK_FOR_ERASE_DONE) & flash_status_ready)? flash_word_address + {1'b1,17'd0}: flash_word_address;

   end


   bpi_dq_t <= {16{read_operation}};

   bpi_read_data <= bpi_dq_i;

   bpi_dq_o <= (state == ST_SEND_WRITE_DATA)? flip_16_bits(write_data_buffer[15:0]):
               (state == ST_SEND_READ_CONFIG_SETUP)? P_FLASH_CMD_READ_CFG_SETUP:
               (state == ST_SEND_READ_CONFIG_CONFIRM)? P_FLASH_CMD_READ_CFG_CONFIRM:
               (state == ST_WRITE_CLEAR_STATUS_REG)? P_FLASH_CMD_CLEAR_STATUS_REG:
               (state == ST_ERASE_CLEAR_STATUS_REG)? P_FLASH_CMD_CLEAR_STATUS_REG:
               (state == ST_SEND_UNLOCK_SETUP)? P_FLASH_CMD_BLOCK_UNLOCK_SETUP:
               (state == ST_SEND_UNLOCK_CONFIRM)? P_FLASH_CMD_BLOCK_UNLOCK_CONFIRM:
               (state == ST_SEND_BUF_WRITE_SETUP)? P_FLASH_CMD_BUFFERED_WRITE_SETUP:
               ((state == ST_SEND_BUF_WRITE_CONFIRM) & write_chip_select_b)? 16'd0:
               (state == ST_SEND_BUF_WRITE_CONFIRM)? P_FLASH_CMD_BUFFERED_WRITE_CONFIRM:
               (state == ST_SEND_WORD_COUNT)? P_WRITE_OP_SIZE:
               (state == ST_SEND_ERASE_SETUP)? P_FLASH_CMD_BLOCK_ERASE_SETUP:
               ((state == ST_SEND_ERASE_CONFIRM) & write_chip_select_b)? 16'd0:
               (state == ST_SEND_ERASE_CONFIRM)? P_FLASH_CMD_BLOCK_ERASE_CONFIRM: bpi_dq_o;

   bpi_addr <= ((state==ST_SEND_READ_CONFIG_SETUP) | (state==ST_SEND_READ_CONFIG_CONFIRM))? {flash_word_address[25:16],16'h8000} : flash_word_address;


   last_segment_in_word <= &flash_word_address[3:0];

   capture_read_data <= (read_op_counter[2:0] == 3'd6);
   last_word_in_block <= &flash_word_address[8:0];
   // 512 words (1KB) per block in a block write
   // 128K words (256KB) per Erase operation

   read_all_data <= (state==ST_IDLE)? 1'b0 : read_all_data | (flash_word_address == ending_address[26:1]);

   wrote_all_data <= (state==ST_IDLE)? 1'b0 : wrote_all_data | (flash_word_address == ending_address[26:1]);

   erased_all_blocks <= (state==ST_IDLE)? 1'b0 : erased_all_blocks | (flash_word_address[25:17] == ending_address[26:18]);


   data_to_host_valid <= (state==ST_READ_DATA) & last_segment_in_word & end_of_read_cycle;

   read_data_buffer <= ((state==ST_READ_DATA) & capture_read_data)? {flip_16_bits(bpi_read_data),read_data_buffer[255:16]} : read_data_buffer;

   write_data_buffer <= (data_from_host_taken)? data_from_host :
                        ((state==ST_SEND_WRITE_DATA) & end_of_write_cycle)? {16'd0,write_data_buffer[255:16]} : write_data_buffer;

end


////////////////////////////////////////////////////////////////////
/////////////// FSM case statement /////////////////////////////////
////////////////////////////////////////////////////////////////////

   always_comb begin
      case(state)
         ST_IDLE                :   if(~fsm_start) next_state = ST_IDLE;
                                    else if(fsm_command==CMD_FPGA_RECONFIG) next_state = ST_FPGA_RECONFIG;
                                    else if(fsm_command==CMD_READ_MEM) next_state = ST_PREPARE_FOR_READ_DATA;
                                    else if(fsm_command==CMD_WRITE_MEM) next_state = ST_PREPARE_FOR_WRITE;
                                    else if(fsm_command==CMD_ERASE_MEM) next_state = ST_PREPARE_FOR_ERASE;
                                    else next_state = ST_ERROR_STATE;

         ///////////////////////////////////////

         ST_SEND_UNLOCK_SETUP       :  if(end_of_write_cycle) next_state = ST_SEND_UNLOCK_CONFIRM;
                                       else next_state = ST_SEND_UNLOCK_SETUP;

         ST_SEND_UNLOCK_CONFIRM     :  if(end_of_write_cycle & (&flash_word_address[25:17])) next_state = ST_SEND_READ_CONFIG_SETUP;
                                       else if(end_of_write_cycle) next_state = ST_SEND_UNLOCK_SETUP;
                                       else next_state = ST_SEND_UNLOCK_CONFIRM;

         ST_SEND_READ_CONFIG_SETUP  :  if(end_of_write_cycle) next_state = ST_SEND_READ_CONFIG_CONFIRM;
                                       else next_state = ST_SEND_READ_CONFIG_SETUP;

         ST_SEND_READ_CONFIG_CONFIRM:  if(end_of_write_cycle & (&flash_word_address[25:23])) next_state = ST_IDLE;
                                       else if(end_of_write_cycle) next_state = ST_SEND_READ_CONFIG_SETUP;
                                       else next_state = ST_SEND_READ_CONFIG_CONFIRM;

         ///////////////////////////////////////

         ST_PREPARE_FOR_READ_DATA   :  if(end_of_read_cycle) next_state = ST_LATCH_READ_ADDRESS;
                                       else next_state = ST_PREPARE_FOR_READ_DATA;

         ST_LATCH_READ_ADDRESS      :  if(end_of_read_cycle) next_state = ST_READ_DELAY;
                                       else next_state = ST_LATCH_READ_ADDRESS;

         ST_READ_DELAY              :  if(end_of_read_cycle) next_state = ST_READ_DATA;
                                       else next_state = ST_READ_DELAY;

         ST_READ_DATA               :  if(read_all_data & end_of_read_cycle & last_segment_in_word) next_state = ST_IDLE;
                                       else if(end_of_read_cycle & last_segment_in_word) next_state = ST_LATCH_READ_ADDRESS;
                                       else next_state = ST_READ_DATA;

         ///////////////////////////////////////

         ST_PREPARE_FOR_WRITE       :  if(end_of_write_cycle) next_state = ST_WRITE_CLEAR_STATUS_REG;
                                       else next_state = ST_PREPARE_FOR_WRITE;

         ST_WRITE_CLEAR_STATUS_REG  :  if(end_of_write_cycle) next_state = ST_SEND_BUF_WRITE_SETUP;
                                       else next_state = ST_WRITE_CLEAR_STATUS_REG;

         ST_SEND_BUF_WRITE_SETUP    :  if(end_of_write_cycle) next_state = ST_SEND_WORD_COUNT;
                                       else next_state = ST_SEND_BUF_WRITE_SETUP;

         ST_SEND_WORD_COUNT         :  if(end_of_write_cycle) next_state = ST_SEND_WRITE_DATA;
                                       else next_state = ST_SEND_WORD_COUNT;

         ST_SEND_WRITE_DATA         :  if(end_of_write_cycle & last_word_in_block) next_state = ST_SEND_BUF_WRITE_CONFIRM;
                                       else next_state = ST_SEND_WRITE_DATA;

         ST_SEND_BUF_WRITE_CONFIRM  :  if(end_of_write_cycle) next_state = ST_CHECK_FOR_WRITE_DONE;
                                       else next_state = ST_SEND_BUF_WRITE_CONFIRM;

         ST_CHECK_FOR_WRITE_DONE    :  if(error_deteced) next_state = ST_ERROR_STATE;
                                       else if(flash_status_ready & wrote_all_data) next_state = ST_IDLE;
                                       else if(flash_status_ready) next_state = ST_PREPARE_FOR_WRITE;
                                       else next_state = ST_CHECK_FOR_WRITE_DONE;

       ///////////////////////////////////////////////

         ST_PREPARE_FOR_ERASE       :  if(end_of_write_cycle) next_state = ST_ERASE_CLEAR_STATUS_REG;
                                       else next_state = ST_PREPARE_FOR_ERASE;

         ST_ERASE_CLEAR_STATUS_REG  :  if(end_of_write_cycle) next_state = ST_SEND_ERASE_SETUP;
                                       else next_state = ST_ERASE_CLEAR_STATUS_REG;

         ST_SEND_ERASE_SETUP        :  if(end_of_write_cycle) next_state = ST_SEND_ERASE_CONFIRM;
                                       else next_state = ST_SEND_ERASE_SETUP;

         ST_SEND_ERASE_CONFIRM      :  if(end_of_write_cycle) next_state = ST_CHECK_FOR_ERASE_DONE;
                                       else next_state = ST_SEND_ERASE_CONFIRM;

         ST_CHECK_FOR_ERASE_DONE    :  if(error_deteced) next_state = ST_ERROR_STATE;
                                       else if(flash_status_ready & erased_all_blocks) next_state = ST_IDLE;
                                       else if(flash_status_ready) next_state = ST_PREPARE_FOR_ERASE;
                                       else next_state = ST_CHECK_FOR_ERASE_DONE;

       ///////////////////////////////////////////////

         ST_FPGA_RECONFIG       :   next_state = ST_FPGA_RECONFIG;

         default                :   next_state = ST_ERROR_STATE;
      endcase
   end

////////////////////////////////////////////////////////////////////
/////////////// Component Instantiation ////////////////////////////
////////////////////////////////////////////////////////////////////

assign reconfig_sig = (state==ST_FPGA_RECONFIG);

BUFGCE_DIV #(
   .BUFGCE_DIVIDE(4)
)
BUFGCE_DIV_inst (
   .O(sys_clk),     // 1-bit output: Buffer
   .CE(1'b1),   // 1-bit input: Buffer enable
   .CLR(1'b0), // 1-bit input: Asynchronous clear
   .I(clk)      // 1-bit input: Buffer
);

xpm_cdc_single reconfig_sync_inst (
   .dest_out(reconfig_sig_sync),
   .dest_clk(sys_clk),
   .src_clk(clk),
   .src_in(reconfig_sig)
);

iprog_icap icap_inst(
  .clk(sys_clk),
  .reconfig(reconfig_sig_sync)
);

endmodule
