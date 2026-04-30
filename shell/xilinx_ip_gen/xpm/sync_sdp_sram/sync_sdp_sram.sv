// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

module sync_sdp_sram #(
    parameter int ADDRESS_WIDTH = 9,
    parameter int DATA_WIDTH = 32,
    parameter int BYTE_WRITE_WIDTH = DATA_WIDTH,
    parameter int WRITE_ENABLE_WIDTH = DATA_WIDTH/BYTE_WRITE_WIDTH,
    parameter int READ_LATENCY = 2,
    parameter string MEMORY_PRIMITIVE = "auto",
    parameter string MEMORY_INIT_FILE = "none",
    parameter string COLLISION_MODE = "no_change" // keep last value read in the previous read operation "provide better timing"
)
  (
    input                       clk,
    input [WRITE_ENABLE_WIDTH-1:0] wr_enable,
    input [ADDRESS_WIDTH-1:0]   wr_address,
    input [DATA_WIDTH-1:0]      wr_data,
    input [ADDRESS_WIDTH-1:0]   rd_address,
    output [DATA_WIDTH-1:0]     rd_data
 );

xpm_memory_sdpram #(
   .ADDR_WIDTH_A(ADDRESS_WIDTH),
   .ADDR_WIDTH_B(ADDRESS_WIDTH),
   .AUTO_SLEEP_TIME(0),
   .BYTE_WRITE_WIDTH_A(BYTE_WRITE_WIDTH),
   .CASCADE_HEIGHT(0),
   .CLOCKING_MODE("common_clock"),
   .ECC_MODE("no_ecc"),
   .MEMORY_INIT_FILE((MEMORY_INIT_FILE == "none")? "none" : MEMORY_INIT_FILE),
   .MEMORY_INIT_PARAM("0"),
   .MEMORY_OPTIMIZATION("true"),
   .MEMORY_PRIMITIVE((MEMORY_PRIMITIVE == "auto")? "auto" : MEMORY_PRIMITIVE),
   .MEMORY_SIZE((2**ADDRESS_WIDTH) * DATA_WIDTH),
   .MESSAGE_CONTROL(0),
   .READ_DATA_WIDTH_B(DATA_WIDTH),
   .READ_LATENCY_B(READ_LATENCY),
   .READ_RESET_VALUE_B("0"),
   .RST_MODE_A("SYNC"),
   .RST_MODE_B("SYNC"),
   .SIM_ASSERT_CHK(0),
   .USE_EMBEDDED_CONSTRAINT(0),
   .WAKEUP_TIME("disable_sleep"),
   .WRITE_DATA_WIDTH_A(DATA_WIDTH),
   .WRITE_MODE_B((COLLISION_MODE == "no_change")? "no_change" : (COLLISION_MODE == "read_first")? "read_first" : COLLISION_MODE)
)
xpm_memory_sdpram_inst (
   .dbiterrb(),
   .doutb(rd_data),
   .sbiterrb(),
   .addra(wr_address),
   .addrb(rd_address),
   .clka(clk),
   .clkb(clk),
   .dina(wr_data),
   .ena(1'b1),
   .enb(1'b1),
   .injectdbiterra(1'b0),
   .injectsbiterra(1'b0),
   .regceb(1'b1),
   .rstb(1'b0),
   .sleep(1'b0),
   .wea(wr_enable)
);

endmodule
