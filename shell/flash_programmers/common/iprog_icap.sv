// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

// Full reconfiguration in HDL using ICAPE3 (equivalent to PROG_B).
// Asserting "reconfig" signal will issue an IPROG command that triggers the device to reload
// itself from the address specified in the WBSTAR (Warm Boot Starting Address) register.
// This implementation sets WBSTAR register to 32'h00000000.
module iprog_icap (
  input       clk,
  input logic reconfig
);

parameter int CCOUNT = 9;  // Counts 0..8

logic [$clog2(CCOUNT)-1:0] cnt_bitst = 0;
logic reboot   = 0;
logic reprog   = 0;

logic        icap_cs     = 1;
logic        icap_rw     = 1;
logic [31:0] d           = 32'hfbffffac;
logic [31:0] bit_swapped;

ICAPE3 #(
  .DEVICE_ID(32'h03628093),     // Specifies the pre-programmed Device ID value to be used for simulation purposes.
  .ICAP_AUTO_SWITCH("DISABLE"), // Enable switch ICAP using sync word
  .SIM_CFG_FILE_NAME("NONE")    // Specifies the Raw Bitstream (RBT) file to be parsed by the simulation model
) ICAPE3_inst (
  .AVAIL  (           ), // 1-bit output: Availability status of ICAP
  .O      (           ), // 32-bit output: Configuration data output bus
  .PRDONE (           ), // 1-bit output: Indicates completion of Partial Reconfiguration
  .PRERROR(           ), // 1-bit output: Indicates Error during Partial Reconfiguration
  .CLK    (clk        ), // 1-bit input: Clock input
  .CSIB   (icap_cs    ), // 1-bit input: Active-Low ICAP enable
  .I      (bit_swapped), // 32-bit input: Configuration data input bus
  .RDWRB  (icap_rw    )  // 1-bit input: Read/Write Select input
);

always_ff @ (posedge clk) begin
  if(reconfig) begin
    reboot <= '1;
  end

  if(!reboot) begin
    icap_cs   <= '1;
    icap_rw   <= '1;
    cnt_bitst <= '0;
  end else begin
    if(cnt_bitst < CCOUNT-1) begin
      cnt_bitst <= cnt_bitst + 1;
    end
  end

  case (cnt_bitst)
    0 : begin
  icap_cs <= '0;
  icap_rw <= '0;
   end
   // using registers for now
        1 : d <= 32'hffffffff; // Dummy Word
   2 : d <= 32'haa995566; // Sync Word
   3 : d <= 32'h20000000; // Type 1 NO OP
        4 : d <= 32'h30020001; // Type 1 Write 1 Word to WBSTAR
        5 : d <= 32'h00000000; // Warm Boot Start Address
        6 : d <= 32'h20000000; // Type 1 NO OP
        7 : d <= 32'h30008001; // Type 1 Write 1 Words to CMD
        8 : d <= 32'h0000000f; // IPROG Command
   default: begin         // Avoid not full case statement warnings
      icap_cs <= '1;
      icap_rw <= '1;
   end
      endcase // case (cnt_bitst)

   end // always_ff @ (posedge clk)

   // Bit swap the ICAP bytes
   assign bit_swapped[31:24] = {d[24],d[25],d[26],d[27],d[28],d[29],d[30],d[31]};
   assign bit_swapped[23:16] = {d[16],d[17],d[18],d[19],d[20],d[21],d[22],d[23]};
   assign bit_swapped[15:8]  = {d[8],d[9],d[10],d[11],d[12],d[13],d[14],d[15]};
   assign bit_swapped[7:0]   = {d[0],d[1],d[2],d[3],d[4],d[5],d[6],d[7]};

endmodule
