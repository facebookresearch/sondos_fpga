// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.
// Copyright (c) Meta Platforms, Inc. and affiliates.
//-----------------------------------------------------------------------------
// Title: Wrapper and logic for the Ultrascale+ SYSMONE4 Primitive
//-----------------------------------------------------------------------------
// Description: Monitor the die temp, VCCint, VCCaux, and VCCbram.
//   Outputs are updated on end_of_conversion assertion. Channel indicates
//   which output was updated.
//-----------------------------------------------------------------------------
module sysmon_wrapper
(
   input logic clk,
   input logic reset,
   output logic end_of_conversion,
   output logic [4:0] channel,
   output logic [9:0] temp_data,
   output logic [9:0] vccint_data,
   output logic [9:0] vccaux_data,
   output logic [9:0] vccbram_data
);
   // Bit offsets
   localparam int C_TEMP    = 0;
   localparam int C_VCCINT  = 1;
   localparam int C_VCCAUX  = 2;
   localparam int C_VCCBRAM = 6;

   wire [15:0] adc_data_int;
   wire [5:0] channel_int;
   wire busy_int;
   wire end_of_conversion_int;

   (*async_reg="true"*) logic [9:0] adc_data_sync [1:0];
   (*async_reg="true"*) logic [5:0] channel_sync [1:0];
   (*async_reg="true"*) logic busy_sync [3:0];
   (*async_reg="true"*) logic end_of_conversion_sync [4:0];


   // Synchronize the ADC signals to the host clock domain
   // Bus sync is OK here because I only sample
   always_ff @(posedge clk) begin
      adc_data_sync <= {adc_data_sync[0], adc_data_int[15:6]};
      channel_sync <= {channel_sync[0], channel_int};
      busy_sync <= {busy_sync[2:0], busy_int};
      end_of_conversion_sync <= {end_of_conversion_sync[3:0], end_of_conversion_int};
   end

   // Check for updated register data and return it
   always_ff @(posedge clk) begin
      channel <= channel_sync[1];
      end_of_conversion <= end_of_conversion_sync[4];
      if (reset) begin
         temp_data <= 10'd0;
         vccint_data <= 10'd0;
         vccaux_data <= 10'd0;
         vccbram_data <= 10'd0;
      end else begin
         // At rising-edge of end of conversion, register the data
         if (~end_of_conversion_sync[4] && end_of_conversion_sync[3]) begin
            if (channel_sync[1] == C_TEMP) begin
               temp_data <= adc_data_sync[1];
            end else if (channel_sync[1] == C_VCCINT) begin
               vccint_data <= adc_data_sync[1];
            end else if (channel_sync[1] == C_VCCAUX) begin
               vccaux_data <= adc_data_sync[1];
            end else if (channel_sync[1] == C_VCCBRAM) begin
               vccbram_data <= adc_data_sync[1];
            end
         end
      end
   end


   // SYSMONE4: AMD Analog-to-Digital Converter and System Monitor
   //           UltraScale
   SYSMONE4 #(
   // INIT_40 - INIT_44: SYSMON configuration registers
   .INIT_40(16'h2000), // Averaging filter enabled for 64 samples, Channel = 0 (temp sensor)
   .INIT_41(16'h2000), // SEQ = 0x2 (enable continuous sequence mode)
   .INIT_42(16'h0000),
   .INIT_43(16'h0000),
   .INIT_44(16'h0000),
   .INIT_45(16'h0000),              // Analog Bus Register.
   // INIT_46 - INIT_4F: Sequence Registers
   .INIT_46(16'h0000),
   .INIT_47(16'h0000),
   .INIT_48(16'h4700), // Enable Temp, int_avg, aux_avg, bram_avg
   .INIT_49(16'h0000),
   .INIT_4A(16'h0100), // Temp sensor averaging enabled
   .INIT_4B(16'h0000),
   .INIT_4C(16'h0000),
   .INIT_4D(16'h0000),
   .INIT_4E(16'h0000),
   .INIT_4F(16'h0000),
   // INIT_50 - INIT_5F: Alarm Limit Registers
   .INIT_50(16'h0000),
   .INIT_51(16'h0000),
   .INIT_52(16'h0000),
   .INIT_53(16'h0000),
   .INIT_54(16'h0000),
   .INIT_55(16'h0000),
   .INIT_56(16'h0000),
   .INIT_57(16'h0000),
   .INIT_58(16'h0000),
   .INIT_59(16'h0000),
   .INIT_5A(16'h0000),
   .INIT_5B(16'h0000),
   .INIT_5C(16'h0000),
   .INIT_5D(16'h0000),
   .INIT_5E(16'h0000),
   .INIT_5F(16'h0000),
   // INIT_60 - INIT_6F: User Supply Alarms
   .INIT_60(16'h0000),
   .INIT_61(16'h0000),
   .INIT_62(16'h0000),
   .INIT_63(16'h0000),
   .INIT_64(16'h0000),
   .INIT_65(16'h0000),
   .INIT_66(16'h0000),
   .INIT_67(16'h0000),
   .INIT_68(16'h0000),
   .INIT_69(16'h0000),
   .INIT_6A(16'h0000),
   .INIT_6B(16'h0000),
   .INIT_6C(16'h0000),
   .INIT_6D(16'h0000),
   .INIT_6E(16'h0000),
   .INIT_6F(16'h0000),
   // Primitive attributes: Primitive Attributes
   .COMMON_N_SOURCE(16'hffff),      // Sets the auxiliary analog input that is used for the Common-N input.
   // Programmable Inversion Attributes: Specifies the use of the built-in programmable inversion on
   // specific pins
   .IS_CONVSTCLK_INVERTED(1'b0),    // Optional inversion for CONVSTCLK, 0-1
   .IS_DCLK_INVERTED(1'b0),         // Optional inversion for DCLK, 0-1
   // Simulation attributes: Set for proper simulation behavior
   .SIM_DEVICE("ULTRASCALE_PLUS"),  // Sets the correct target device for simulation functionality.
   .SIM_MONITOR_FILE("design.txt"), // Analog simulation data file name
   // User Voltage Monitor: SYSMON User voltage monitor
   .SYSMON_VUSER0_BANK(0),          // Specify IO Bank for User0
   .SYSMON_VUSER0_MONITOR("NONE"),  // Specify Voltage for User0
   .SYSMON_VUSER1_BANK(0),          // Specify IO Bank for User1
   .SYSMON_VUSER1_MONITOR("NONE"),  // Specify Voltage for User1
   .SYSMON_VUSER2_BANK(0),          // Specify IO Bank for User2
   .SYSMON_VUSER2_MONITOR("NONE"),  // Specify Voltage for User2
   .SYSMON_VUSER3_MONITOR("NONE")   // Specify Voltage for User3
   )
   SYSMONE4_inst (
   // ALARMS outputs: ALM, OT
   .ALM(),                      // 16-bit output: Output alarm for temp, Vccint, Vccaux and Vccbram
   .OT(),                       // 1-bit output: Over-Temperature alarm
   // Direct Data Out outputs: ADC_DATA
   .ADC_DATA(adc_data_int),     // 16-bit output: Direct Data Out
   // Dynamic Reconfiguration Port (DRP) outputs: Dynamic Reconfiguration Ports
   .DO(),                       // 16-bit output: DRP output data bus
   .DRDY(),                     // 1-bit output: DRP data ready
   // I2C Interface outputs: Ports used with the I2C DRP interface
   .I2C_SCLK_TS(),              // 1-bit output: I2C_SCLK output port
   .I2C_SDA_TS(),               // 1-bit output: I2C_SDA_TS output port
   .SMBALERT_TS(),              // 1-bit output: Output control signal for SMBALERT.
   // STATUS outputs: SYSMON status ports
   .BUSY(busy_int),             // 1-bit output: System Monitor busy output
   .CHANNEL(channel_int),       // 6-bit output: Channel selection outputs
   .EOC(end_of_conversion_int), // 1-bit output: End of Conversion
   .EOS(),                      // 1-bit output: End of Sequence
   .JTAGBUSY(),                 // 1-bit output: JTAG DRP transaction in progress output
   .JTAGLOCKED(),               // 1-bit output: JTAG requested DRP port lock
   .JTAGMODIFIED(),             // 1-bit output: JTAG Write to the DRP has occurred
   .MUXADDR(),                  // 5-bit output: External MUX channel decode
   // Auxiliary Analog-Input Pairs inputs: VAUXP[15:0], VAUXN[15:0]
   .VAUXN(1'b0),                    // 16-bit input: N-side auxiliary analog input
   .VAUXP(1'b1),                    // 16-bit input: P-side auxiliary analog input
   // CONTROL and CLOCK inputs: Reset, conversion start and clock inputs
   .CONVST(1'b1),               // 1-bit input: Convert start input
   .CONVSTCLK(1'b0),            // 1-bit input: Convert clock input
   .RESET(reset),               // 1-bit input: Active-High reset
   // Dedicated Analog Input Pair inputs: VP/VN
   .VN(1'b0),                   // 1-bit input: N-side analog input
   .VP(1'b0),                   // 1-bit input: P-side analog input
   // Dynamic Reconfiguration Port (DRP) inputs: Dynamic Reconfiguration Ports
   .DADDR(8'b0),                // 8-bit input: DRP address bus
   .DCLK(1'b0),                 // 1-bit input: DRP clock
   .DEN(1'b0),                  // 1-bit input: DRP enable signal
   .DI(16'b0),                  // 16-bit input: DRP input data bus
   .DWE(1'b0),                  // 1-bit input: DRP write enable
   // I2C Interface inputs: Ports used with the I2C DRP interface
   .I2C_SCLK(1'b0),             // 1-bit input: I2C_SCLK input port
   .I2C_SDA(1'b0)               // 1-bit input: I2C_SDA input port
   );

   // End of SYSMONE4_inst instantiation
endmodule
