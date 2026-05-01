// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.


module sondos_shell_vcu118_qspi_controller(
   input clk,
   input reset,
   input done_beat,
   output [7:0] spi_state,
   output logic [31:0] current_address,
   input fsm_start,
   input [7:0] fsm_command,
   input [31:0] starting_address,
   input [31:0] ending_address,
   input [3:0] clk_shift,

   output logic spi_cs_1_n,
   inout [3:0] spi_io_1_io,

   output data_to_host_valid,
   output [255:0] data_to_host,

   output data_from_host_taken,
   input [255:0] data_from_host
);

// spi clock Vs spi clock counter
//                   __    __    __    __    __    __    __    __    __    __    __    __    __    __    __    __    __    __    __    __    __    __    __
// clk           |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |_
//===========================================================================================================================================================
// clk_counter[3:0] | 0x0 | 0x1 | 0x2 | 0x3 | 0x4 | 0x5 | 0x6 | 0x7 | 0x8 | 0x9 | 0xA | 0xB | 0xC | 0xD | 0xE | 0xF | 0x0 | 0x1 | 0x2 | 0x3 | 0x4 | 0x5 | 0x6
//===========================================================================================================================================================
// (clk_shift = 0)                                 ________________________________________________                                                __________
// SPI clock out     _____________________________|                                                |______________________________________________|
//===========================================================================================================================================================
// SPI data in      | XXXXXXX |                         Correct Data                              | XXXXXXXXXXXXXXXXXXXXXXXXX |    Correct Data
//===========================================================================================================================================================
// SPI data in (r1) | XXXXXXXXX |                         Correct Data                            | XXXXXXXXXXXXXXXXXXXXXXXXX |        Correct Data
//===========================================================================================================================================================
// SPI data in (r2) | XXXXXXXXXXXXXXX |                         Correct Data                            | XXXXXXXXXXXXXXXXXXXXXXXXXXX |    Correct Data
//===========================================================================================================================================================
// SPI data out     |                              Data[n]                                        |                            Data[n+1]
//===========================================================================================================================================================
//
// capturing input data from r2 at the read_tic = (clk_counter[3:0]==4'hA)
// changing output data happens at (clk_counter[3:0]==4'hC)
// Flash changes data on the falling edge of the clock

// The current_address tracks the byte address of the cobined buffer which is split over the 2 SPI flash modules
// so when this address is given in the command to each flash module it is divided by 2 current_address[31:1]
// also all read/write transactions with SW would be on 4KB (page) boundaries, so starting_address and ending_address are expected to have bits [11:0] = 0
//

parameter logic [7:0] READ_COMMAND = 8'h6C;
parameter logic [7:0] WRITE_COMMAND = 8'h34;
parameter logic [7:0] ERASE_COMMAND = 8'hDC;
parameter logic [7:0] WRITE_ENABLE_COMMAND = 8'h06;
parameter logic [7:0] RESET_ENABLE_COMMAND = 8'h66;
parameter logic [7:0] RESET_COMMAND        = 8'h99;
parameter logic [7:0] READ_STATUS_COMMAND = 8'h05;

localparam logic [7:0] CMD_READ_MEM         = 8'h1;
localparam logic [7:0] CMD_WRITE_MEM        = 8'h2;
localparam logic [7:0] CMD_ERASE_MEM        = 8'h3;
localparam logic [7:0] CMD_FPGA_RECONFIG    = 8'h7;

localparam logic [13:0] TIC_FSM_START    = 14'h000C;
localparam logic [13:0] TIC_8_CYCLES     = 14'h008C;
localparam logic [13:0] TIC_16_CYCLES    = 14'h010C;
localparam logic [13:0] TIC_24_CYCLES    = 14'h018C;
localparam logic [13:0] TIC_32_CYCLES    = 14'h020C;
localparam logic [13:0] TIC_48_CYCLES    = 14'h030C;
localparam logic [13:0] TIC_56_CYCLES    = 14'h038C;
localparam logic [13:0] TIC_64_CYCLES    = 14'h040C;
localparam logic [13:0] TIC_128_CYCLES   = 14'h080C;
localparam logic [13:0] TIC_192_CYCLES   = 14'h0C0C;
localparam logic [13:0] TIC_256_CYCLES   = 14'h100C;
localparam logic [13:0] TIC_320_CYCLES   = 14'h140C;
localparam logic [13:0] TIC_384_CYCLES   = 14'h180C;
localparam logic [13:0] TIC_448_CYCLES   = 14'h1C0C;
localparam logic [13:0] TIC_512_CYCLES   = 14'h200C;
localparam logic [13:0] TIC_576_CYCLES   = 14'h240C;

localparam logic [13:0] TIC_FLASH_STATUS = 14'h010A;



typedef enum logic [5:0] {
   ST_IDLE                      = 6'b000000,

   ST_PREPARE_FOR_READ_DATA     = 6'b000_001, // wait until clk_counter == TIC_16_CYCLES
   ST_SEND_READ_COMMAND         = 6'b000_010, // continue until clk_counter == TIC_56_CYCLES
   ST_DUMMY_READS               = 6'b000_011, // continue until clk_counter == TIC_64_CYCLES
   ST_READ_DATA                 = 6'b000_100, // continue until (current_address == ending_address) & clk_counter[4:0]==5'h1C
   ST_LAST_READ_DATA            = 6'b000_111, // latch last data in fifo and return to idle

   ST_PREPARE_FOR_WRITE         = 6'b001_001, // wait until clk_counter == TIC_FSM_START
   ST_SEND_WRITE_ENABLE_COMMAND = 6'b001_010, // continue until clk_counter == TIC_8_CYCLES
   ST_WRITE_DESELECT_TIME       = 6'b001_011, // continue until clk_counter == TIC_24_CYCLES
   ST_SEND_WRITE_COMMAND        = 6'b001_110, // continue until clk_counter == TIC_64_CYCLES
   ST_SEND_WRITE_DATA           = 6'b001_101, // continue until clk_counter == TIC_576_CYCLES, writing 256 bytes
   ST_CHECK_FOR_WRITE_DONE      = 6'b001_111, // if not last write and no other SPI interface, go to status check

   ST_PREPARE_FOR_ERASE         = 6'b010_001, // wait until clk_counter == TIC_FSM_START
   ST_SEND_ERASE_ENABLE_COMMAND = 6'b010_010, // continue until clk_counter == TIC_8_CYCLES
   ST_ERASE_DESELECT_TIME       = 6'b010_011, // continue until clk_counter == TIC_24_CYCLES
   ST_SEND_ERASE_COMMAND        = 6'b010_110, // continue until clk_counter == TIC_64_CYCLES
   ST_CHECK_FOR_ERASE_DONE      = 6'b010_111, // continue until clk_counter == TIC_64_CYCLES

   ST_PREPARE_FOR_READ_STATUS   = 6'b011_001, // wait until clk_counter == TIC_FSM_START
   ST_READ_STATUS_COMMAND       = 6'b011_010, // continue until clk_counter == TIC_8_CYCLES
   ST_READ_STATUS_DATA          = 6'b011_111, // check if busy and continue pulling the status, otherwise return to writing or erasing

   ST_PREPARE_FOR_RESET         = 6'b100_001, // wait until clk_counter == TIC_FSM_START
   ST_SEND_RESET_ENABLE_COMMAND = 6'b100_010, // continue until clk_counter == TIC_8_CYCLES
   ST_RESET_DESELECT_TIME       = 6'b100_100, // continue until clk_counter == TIC_24_CYCLES
   ST_SEND_RESET_COMMAND        = 6'b100_110, // continue until clk_counter == TIC_64_CYCLES

   ST_FPGA_RECONFIG             = 6'b111_000, // wait for reset
   ST_ERROR_STATE               = 6'b111_111  // wait for reset
} state_t;

state_t state;
state_t next_state;
logic [3:0] spi_io_0_i;
logic [3:0] spi_io_0_o;
logic [3:0] spi_io_0_t;
logic [3:0] spi_io_1_i;
logic [3:0] spi_io_1_o;
logic [3:0] spi_io_1_t;

logic [3:0] spi_io_0_i_r1;
logic [3:0] spi_io_0_i_r2;
logic [3:0] spi_io_1_i_r1;
logic [3:0] spi_io_1_i_r2;

logic flash_status_ready;

logic spi_cs_0_n;
logic spi_clock_0;

logic reconfig_sig;
logic reconfig_sig_sync;

logic sys_clk;

logic read_clk_tic;
logic write_clk_tic;

logic [255:0] read_data_buffer;
logic [255:0] write_data_buffer;
logic [39:0] command_buffer;
logic [7:0] current_command;


logic [13:0] clk_counter_base;
logic [13:0] clk_counter;
logic [3:0] shifted_clk_reg;

logic active_link_state;
logic wrote_all_pages;
logic erased_all_pages;


assign active_link_state = (state == ST_SEND_READ_COMMAND) | (state == ST_READ_DATA) | (state == ST_DUMMY_READS) |
                           (state == ST_SEND_WRITE_ENABLE_COMMAND) | (state == ST_SEND_WRITE_COMMAND) | (state == ST_SEND_WRITE_DATA) |
                           (state == ST_SEND_ERASE_ENABLE_COMMAND) | (state == ST_SEND_ERASE_COMMAND) |
                           (state == ST_SEND_RESET_ENABLE_COMMAND) | (state == ST_SEND_RESET_COMMAND) |
                           (state == ST_READ_STATUS_COMMAND) | (state == ST_READ_STATUS_DATA);

assign spi_state = state;

assign data_to_host = read_data_buffer;
assign data_to_host_valid = ((state == ST_READ_DATA) & (clk_counter[8:0] == 9'h00B)) | (state == ST_LAST_READ_DATA);

assign read_clk_tic = (clk_counter[3:0] == 4'hA);
assign write_clk_tic = (clk_counter[3:0] == 4'hC);

assign data_from_host_taken = ((state==ST_WRITE_DESELECT_TIME) & (clk_counter == TIC_24_CYCLES)) |
                              ((state==ST_SEND_WRITE_DATA) & (clk_counter[8:0] == 9'h00C) & ~(clk_counter == TIC_576_CYCLES));


assign flash_status_ready = (clk_counter==TIC_FLASH_STATUS) & (~spi_io_0_i_r2[1]) & (~spi_io_1_i_r2[1]) & (state==ST_READ_STATUS_DATA);

////////////////////////////////////////////////////////////////////
/////////////// Registers always blocks ////////////////////////////
////////////////////////////////////////////////////////////////////

always_ff @(posedge clk) begin
   if(reset) begin
      clk_counter_base <= '0;
      state <= ST_PREPARE_FOR_RESET;
   end else begin
      clk_counter_base <= clk_counter_base + 1'b1;

      state <= next_state;
   end

   clk_counter <= clk_counter_base;
   shifted_clk_reg <= clk_counter_base + clk_shift + 4'd3;

   spi_clock_0 <= shifted_clk_reg[3];
   spi_cs_0_n <= ~active_link_state;
   spi_cs_1_n <= ~active_link_state;

   spi_io_0_i_r1 <= spi_io_0_i;
   spi_io_1_i_r1 <= spi_io_1_i;
   spi_io_0_i_r2 <= spi_io_0_i_r1;
   spi_io_1_i_r2 <= spi_io_1_i_r1;

   spi_io_0_t[0] <= (state==ST_READ_DATA) | (state==ST_DUMMY_READS) | ~active_link_state;

   spi_io_0_t[3:1] <= (state==ST_SEND_WRITE_DATA)? 3'b000 : 3'b111;

   spi_io_1_t[0] <= (state==ST_READ_DATA) | (state==ST_DUMMY_READS) | ~active_link_state;

   spi_io_1_t[3:1] <= (state==ST_SEND_WRITE_DATA)? 3'b000 : 3'b111;

   current_address <= (fsm_start)? starting_address :
                     (((state==ST_READ_DATA) | (state==ST_SEND_WRITE_DATA)) & read_clk_tic)? current_address + 1'b1:
                     (state==ST_CHECK_FOR_ERASE_DONE)? current_address + {1'b1,17'd0}: current_address;

   current_command <= ((state==ST_IDLE) & fsm_start)? fsm_command : current_command;

   wrote_all_pages <= (state==ST_IDLE)? 1'b0 : wrote_all_pages | (current_address == ending_address);

   erased_all_pages <= (state==ST_IDLE)? 1'b0 : erased_all_pages | (current_address[31:17] == ending_address[31:17]);

   spi_io_0_o[0] <= (state==ST_SEND_WRITE_DATA)? write_data_buffer[0] : command_buffer[39];
   spi_io_0_o[3:1] <= write_data_buffer[3:1];
   spi_io_1_o[0] <= (state==ST_SEND_WRITE_DATA)? write_data_buffer[4] : command_buffer[39];
   spi_io_1_o[3:1] <= write_data_buffer[7:5];

   read_data_buffer <= ((state==ST_READ_DATA) & read_clk_tic)? {spi_io_1_i_r2,spi_io_0_i_r2,read_data_buffer[255:8]} : read_data_buffer;

   write_data_buffer <= (data_from_host_taken)? data_from_host :
                        ((state==ST_SEND_WRITE_DATA) & write_clk_tic)? {8'd0,write_data_buffer[255:8]} : write_data_buffer;

   command_buffer <= (state==ST_PREPARE_FOR_READ_STATUS)? {READ_STATUS_COMMAND,1'b0,current_address[31:1]}:
                     (state==ST_PREPARE_FOR_READ_DATA)? {READ_COMMAND,1'b0,current_address[31:1]}:
                     (state==ST_PREPARE_FOR_WRITE)? {WRITE_ENABLE_COMMAND,1'b0,current_address[31:1]}:
                     (state==ST_PREPARE_FOR_RESET)? {RESET_ENABLE_COMMAND,1'b0,current_address[31:1]}:
                     (state==ST_PREPARE_FOR_ERASE)? {WRITE_ENABLE_COMMAND,1'b0,current_address[31:1]}: // enabling erase uses same command as enabling write
                     (state==ST_WRITE_DESELECT_TIME)? {WRITE_COMMAND,1'b0,current_address[31:1]}:
                     (state==ST_ERASE_DESELECT_TIME)? {ERASE_COMMAND,1'b0,current_address[31:1]}:
                     (state==ST_RESET_DESELECT_TIME)? {RESET_COMMAND,1'b0,current_address[31:1]}:
                     (write_clk_tic)? {command_buffer[38:0],1'b0} : command_buffer;
end


////////////////////////////////////////////////////////////////////
/////////////// FSM case statement /////////////////////////////////
////////////////////////////////////////////////////////////////////

   always_comb begin
      case(state)
         ST_IDLE                :   if(~fsm_start) next_state = ST_IDLE;
                                    else if(fsm_command==CMD_FPGA_RECONFIG) next_state = ST_FPGA_RECONFIG;
                                    else if(fsm_command==CMD_READ_MEM) next_state = ST_PREPARE_FOR_READ_DATA;
                                    else if(fsm_command==CMD_WRITE_MEM) next_state = ST_PREPARE_FOR_READ_STATUS;
                                    else if(fsm_command==CMD_ERASE_MEM) next_state = ST_PREPARE_FOR_READ_STATUS;
                                    else next_state = ST_ERROR_STATE;

         ST_PREPARE_FOR_READ_DATA : if(clk_counter == TIC_16_CYCLES) next_state = ST_SEND_READ_COMMAND;
                                    else next_state = ST_PREPARE_FOR_READ_DATA;

         ST_SEND_READ_COMMAND   :   if(clk_counter == TIC_56_CYCLES) next_state = ST_DUMMY_READS;
                                    else next_state = ST_SEND_READ_COMMAND;

         ST_DUMMY_READS         :   if(clk_counter == TIC_64_CYCLES) next_state = ST_READ_DATA;
                                    else next_state = ST_DUMMY_READS;

         ST_READ_DATA           :   if((current_address == ending_address) & read_clk_tic) next_state = ST_LAST_READ_DATA;
                                    else next_state = ST_READ_DATA;

         ST_LAST_READ_DATA      :   next_state = ST_IDLE;

         ///////////////////////////////////////

         ST_PREPARE_FOR_WRITE   :   if(clk_counter == TIC_FSM_START) next_state = ST_SEND_WRITE_ENABLE_COMMAND;
                                    else next_state = ST_PREPARE_FOR_WRITE;

         ST_SEND_WRITE_ENABLE_COMMAND : if(clk_counter == TIC_8_CYCLES) next_state = ST_WRITE_DESELECT_TIME;
                                        else next_state = ST_SEND_WRITE_ENABLE_COMMAND;

         ST_WRITE_DESELECT_TIME :   if(clk_counter == TIC_24_CYCLES) next_state = ST_SEND_WRITE_COMMAND;
                                    else next_state = ST_WRITE_DESELECT_TIME;

         ST_SEND_WRITE_COMMAND  :   if(clk_counter == TIC_64_CYCLES) next_state = ST_SEND_WRITE_DATA;
                                    else next_state = ST_SEND_WRITE_COMMAND;

         ST_SEND_WRITE_DATA     :   if(clk_counter == TIC_576_CYCLES) next_state = ST_CHECK_FOR_WRITE_DONE;
                                    else next_state = ST_SEND_WRITE_DATA;

         ST_CHECK_FOR_WRITE_DONE :  if(wrote_all_pages) next_state = ST_IDLE;
                                    else next_state = ST_PREPARE_FOR_READ_STATUS;

       ///////////////////////////////////////////////

         ST_PREPARE_FOR_ERASE   :   if(clk_counter == TIC_FSM_START) next_state = ST_SEND_ERASE_ENABLE_COMMAND;
                                    else next_state = ST_PREPARE_FOR_ERASE;

         ST_SEND_ERASE_ENABLE_COMMAND : if(clk_counter == TIC_8_CYCLES) next_state = ST_ERASE_DESELECT_TIME;
                                        else next_state = ST_SEND_ERASE_ENABLE_COMMAND;

         ST_ERASE_DESELECT_TIME :   if(clk_counter == TIC_24_CYCLES) next_state = ST_SEND_ERASE_COMMAND;
                                    else next_state = ST_ERASE_DESELECT_TIME;

         ST_SEND_ERASE_COMMAND  :   if(clk_counter == TIC_64_CYCLES) next_state = ST_CHECK_FOR_ERASE_DONE;
                                    else next_state = ST_SEND_ERASE_COMMAND;

         ST_CHECK_FOR_ERASE_DONE :  if(erased_all_pages) next_state = ST_IDLE;
                                    else next_state = ST_PREPARE_FOR_READ_STATUS;

       ///////////////////////////////////////////////

         ST_PREPARE_FOR_READ_STATUS   : if(clk_counter == TIC_FSM_START) next_state = ST_READ_STATUS_COMMAND;
                                        else next_state = ST_PREPARE_FOR_READ_STATUS;

         ST_READ_STATUS_COMMAND :   if(clk_counter == TIC_8_CYCLES) next_state = ST_READ_STATUS_DATA;
                                    else next_state = ST_READ_STATUS_COMMAND;

         ST_READ_STATUS_DATA    :   if(flash_status_ready & (current_command == CMD_ERASE_MEM)) next_state = ST_PREPARE_FOR_ERASE;
                                    else if(flash_status_ready) next_state = ST_PREPARE_FOR_WRITE;
                                    else if(clk_counter == TIC_16_CYCLES) next_state = ST_PREPARE_FOR_READ_STATUS;
                                    else next_state = ST_READ_STATUS_DATA;

       ///////////////////////////////////////////////

         ST_PREPARE_FOR_RESET   :   if(clk_counter == TIC_FSM_START) next_state = ST_SEND_RESET_ENABLE_COMMAND;
                                    else next_state = ST_PREPARE_FOR_RESET;

         ST_SEND_RESET_ENABLE_COMMAND : if(clk_counter == TIC_8_CYCLES) next_state = ST_RESET_DESELECT_TIME;
                                        else next_state = ST_SEND_RESET_ENABLE_COMMAND;

         ST_RESET_DESELECT_TIME :   if(clk_counter == TIC_16_CYCLES) next_state = ST_SEND_RESET_COMMAND;
                                    else next_state = ST_RESET_DESELECT_TIME;

         ST_SEND_RESET_COMMAND  :   if(clk_counter == TIC_32_CYCLES) next_state = ST_IDLE;
                                    else next_state = ST_SEND_RESET_COMMAND;

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

STARTUPE3#(
   .PROG_USR     ("FALSE"), //Don't activate the program event security feature
   .SIM_CCLK_FREQ(0.0    )  //Set the configuration clock frequency (ns) for simulation
)
STARTUPE3_inst(
   .EOS      (                  ), // End of startup (unused)
   .CFGCLK   (                  ), // Configuration main clock output (unused)
   .CFGMCLK  (                  ), // Configuration internal oscillator output (unused)
   .DI       (spi_io_0_i),
   .DO       (spi_io_0_o),
   .DTS      (spi_io_0_t),
   .FCSBO    (spi_cs_0_n   ), // FPGA RDWR_FCS_B / Flash CE#
   .FCSBTS   (1'b0              ),
   .GSR      (1'b0              ), // No trigger of global set/reset
   .GTS      (1'b0              ), // No trigger of global tri state
   .KEYCLEARB(1'b1              ), // No key clear capability - only useful for encrypted designs
   .PREQ     (                  ), // PROGRAM request (unused)
   .PACK     (1'b1              ), // PROGRAM request acknowledgement
   .USRCCLKO (spi_clock_0       ), // Flash CLK
   .USRCCLKTS(1'b0              ), // Set tri-state on FPGA CCLK / Flash CLK
   .USRDONEO (done_beat         ), // FPGA DONE signal is a heartbeat based on PCIe clock
   .USRDONETS(1'b0              )  // FPGA DONE signal is not tristated
);

generate
    for(genvar ii = 0; ii < 4; ii++ ) begin: gen_spi_1_io_buf
        IOBUF qspi_io(
           .O (spi_io_1_i[ii] ),
           .I (spi_io_1_o[ii]),
           .T (spi_io_1_t[ii]),
           .IO(spi_io_1_io[ii])
        );
    end
endgenerate

endmodule
