// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

module sondos_shell_htg930_remote

import so_axi4_if_pkg::*,so_axi4l_if_pkg::*,so_axi4s_if_pkg::*;
(
   sondos_shell_htg930_remote_if.shell sondos_io,

   output shell_clk,
   output shell_reset,

   so_axi4l_if.master axi_lite_user,
   so_axi4_if.slave axi_full_user,

   so_axi4s_if.slave axi_stream_tx_c2c, // not implemented yet
   so_axi4s_if.master axi_stream_rx_c2c // not implemented yet
 );

logic init_clk_int;
logic init_clk;
logic init_reset = 1'b1;
logic [15:0] init_reset_counter = 0;


logic [26:0] ff0_clk_counter;

wire [31:0] fan_speed;
wire [7:0] fan_speed_sync;
logic [7:0] fan_pwm_counter;
logic fan_active;

logic [5:0] ff0_status;

logic [7:0] user_leds;
logic [3:0] ff0_lane_up;
logic ff0_channel_up;
logic ff0_gt_pll_locked;
logic ff0_mmcm_not_locked;
logic aurora_reset_n;

logic  ff0_iic_scl_i;
logic  ff0_iic_scl_o;
logic  ff0_iic_scl_t;
logic  ff0_iic_sda_i;
logic  ff0_iic_sda_o;
logic  ff0_iic_sda_t;

logic  main_iic_scl_i;
logic  main_iic_scl_o;
logic  main_iic_scl_t;
logic  main_iic_sda_i;
logic  main_iic_sda_o;
logic  main_iic_sda_t;

wire [9:0] temperature_data;
wire [9:0] vccint_data;
wire [9:0] vccaux_data;
wire [9:0] vccbram_data;

so_axi4_if #(C_SO_AXI4_A64_D512) axi_full_flash (.aclk(shell_clk), .aresetn(~shell_reset));
so_axi4_if #(C_SO_AXI4_A64_D512) axi_full_dummy (.aclk(shell_clk), .aresetn(~shell_reset));
so_axi4_if #(C_SO_AXI4_A64_D512) axi_full_to_host (.aclk(shell_clk), .aresetn(~shell_reset));

so_axi4l_if #(C_SO_AXI4L_A32_D32) axi_lite_mmio_registers (.aclk(shell_clk), .aresetn(~shell_reset));
so_axi4l_if #(C_SO_AXI4L_A32_D32) axi_lite_shell (.aclk(shell_clk), .aresetn(~shell_reset));
so_axi4l_if #(C_SO_AXI4L_A32_D32) axi_lite_flash (.aclk(shell_clk), .aresetn(~shell_reset));
so_axi4l_if #(C_SO_AXI4L_A32_D32) axi_lite_leaves [2:0] (.aclk(shell_clk), .aresetn(~shell_reset));
logic [2:0][1:0][63:0] register_address_map;

so_axi4s_if #(C_SO_AXI4S_D256) axi_stream_aurora_tx (.aclk(shell_clk), .aresetn(~shell_reset));
so_axi4s_if #(C_SO_AXI4S_D256) axi_stream_aurora_rx (.aclk(shell_clk), .aresetn(~shell_reset));

so_axi4s_if #(C_SO_AXI4S_D256) axi_stream_aurora_user_k_tx (.aclk(shell_clk), .aresetn(~shell_reset));
so_axi4s_if #(C_SO_AXI4S_D256) axi_stream_aurora_user_k_rx (.aclk(shell_clk), .aresetn(~shell_reset));

so_axi4s_if #(C_SO_AXI4S_D256) axi_stream_rx_channels [1:0] (.aclk(shell_clk), .aresetn(~shell_reset));
so_axi4s_if #(C_SO_AXI4S_D256) axi_stream_tx_channels [1:0] (.aclk(shell_clk), .aresetn(~shell_reset));

logic [1:0][7:0] signatures;
assign signatures[0] = 8'h99;
assign signatures[1] = 8'h88;



IBUFDS usrclk_ibuf (.O(init_clk_int), .I(sondos_io.user_clk_p), .IB(sondos_io.user_clk_n));
BUFG usrclk_bufg (.I(init_clk_int), .O(init_clk));

always_ff @(posedge init_clk) begin
   init_reset_counter <= (&init_reset_counter)? init_reset_counter : init_reset_counter + 1'b1;
   init_reset <= ~(&init_reset_counter);
end

assign register_address_map[0][0]=64'h0000_0000_0000_0000; //user
assign register_address_map[0][1]=64'h0000_0000_00EF_FFFF;

assign register_address_map[1][0]=64'h0000_0000_00F0_0000; // shell common
assign register_address_map[1][1]=64'h0000_0000_00FE_FFFF;

assign register_address_map[2][0]=64'h0000_0000_00FF_0000; // shell flash
assign register_address_map[2][1]=64'h0000_0000_00FF_FFFF;

`CONNECT_SO_AXI4L_IF(axi_lite_leaves[0],axi_lite_user);
`CONNECT_SO_AXI4L_IF(axi_lite_leaves[1],axi_lite_shell);
`CONNECT_SO_AXI4L_IF(axi_lite_leaves[2],axi_lite_flash);

assign axi_full_dummy.awvalid = 1'b0;
assign axi_full_dummy.wvalid = 1'b0;
assign axi_full_dummy.arvalid = 1'b0;
assign axi_full_dummy.rready = 1'b0;
assign axi_full_dummy.bready = 1'b0;

sondos_axi_crossbar_wrapper axif_crossbar_inst
(
   .axi_full_client_0(axi_full_user),
   .axi_full_client_1(axi_full_dummy),
   .axi_full_client_2(axi_full_flash),
   .axi_full_to_host
);

sondos_axi4l_crossbar #(.P_NUM_LEAFS(3)) axilite_crossbar_inst
(
  .aclk(shell_clk),
  .aresetn(~shell_reset),
  .map(register_address_map),
  .trunk_bus(axi_lite_mmio_registers),
  .leaf_bus(axi_lite_leaves)
);


sondos_shell_htg930_flash_top htg930_flash_programmer_inst
(
   .clk(shell_clk),
   .reset(shell_reset),
   .done_beat(ff0_clk_counter[26]),
   .axi_full_flash(axi_full_flash),
   .axi_lite_flash(axi_lite_flash),

   .bpi_data_hi_io(sondos_io.bpi_data_hi_io),
   .bpi_addr(sondos_io.bpi_addr),
   .bpi_adv_b(sondos_io.bpi_adv_b),
   .bpi_foe_b(sondos_io.bpi_foe_b),
   .bpi_fwe_b(sondos_io.bpi_fwe_b)
);

logic [31:0] hard_err_counter;
logic [31:0] soft_err_counter;
logic [31:0] crc_pass_fail_n_counter;

sondos_shell_htg930_remote_csr shell_csr_inst (
    .clk(shell_clk),
    .reset(shell_reset),
    .hard_err_counter,
    .soft_err_counter,
    .crc_pass_fail_n_counter,
    .temperature_data,
    .vccint_data,
    .vccaux_data,
    .vccbram_data,
    .fan_speed,
    .axi_lite_user(axi_lite_shell)
);

// fan speed shouldn’t be changing much if it changes at all here
// and breaking bit to bit coherence wouldn’t cause any trouble
xpm_cdc_array_single #(
   .WIDTH(8)
)
fan_speed_sync_inst (
   .dest_out(fan_speed_sync),
   .dest_clk(init_clk),
   .src_clk(shell_clk),
   .src_in(fan_speed[7:0])
);

assign sondos_io.shell_leds[0] = ff0_clk_counter[26];
assign sondos_io.shell_leds[1] = &ff0_lane_up;
assign sondos_io.shell_leds[2] = ff0_channel_up;
assign sondos_io.shell_leds[3] = (~ff0_mmcm_not_locked);

// allow for bypass of fan PWM (100% duty cycle when bypassed):
// JUMPER installed between PCB USER_IO[8] and neighboring GND pin enables bypass
assign sondos_io.fan_en = (~sondos_io.fan_pwm_bypass || ~fan_speed[31]) ? 1'b1 : fan_active;

always_ff @(posedge init_clk) begin
   if(init_reset) begin
      fan_pwm_counter <= 0;
      fan_active <= 1'b1;
   end else begin
      fan_pwm_counter <= fan_pwm_counter + 1'b1;
      fan_active <= (&fan_pwm_counter)? 1'b1 :
                    (fan_pwm_counter == fan_speed_sync)? 1'b0 : fan_active;
   end
end

always_ff @(posedge shell_clk) begin
    if(shell_reset) begin
        ff0_clk_counter <= '0;
    end else begin
        ff0_clk_counter <= ff0_clk_counter + 1'b1;
    end
end

IOBUF ff0_iic_scl_inst (
   .O (ff0_iic_scl_i),
   .I (ff0_iic_scl_o),
   .IO(sondos_io.ff0_iic_scl),
   .T (ff0_iic_scl_t)
);

IOBUF ff0_iic_sda_inst (
   .O (ff0_iic_sda_i),
   .I (ff0_iic_sda_o),
   .IO(sondos_io.ff0_iic_sda),
   .T (ff0_iic_sda_t)
);

IOBUF main_iic_scl_inst (
   .O (main_iic_scl_i),
   .I (main_iic_scl_o),
   .IO(sondos_io.main_iic_scl),
   .T (main_iic_scl_t)
);

IOBUF main_iic_sda_inst (
   .O (main_iic_sda_i),
   .I (main_iic_sda_o),
   .IO(sondos_io.main_iic_sda),
   .T (main_iic_sda_t)
);


packetized_axi4l_master packetized_axi4l_master_inst
(
  .clk(shell_clk),
  .reset(shell_reset),
  .axi_lite_to_user(axi_lite_mmio_registers),
  .axi_stream_to_link(axi_stream_tx_channels[0]),
  .axi_stream_from_link(axi_stream_rx_channels[0])
);

packetized_axi4f_write_slave axi4f_slave_write_inst
(
  .clk(shell_clk),
  .reset(shell_reset),
  .axi_full_from_user(axi_full_to_host),
  .axi_stream_to_link(axi_stream_aurora_tx),
  .axi_stream_from_link(axi_stream_rx_channels[1])
);

packetized_axi4f_read_slave axi4f_slave_read_inst
(
  .clk(shell_clk),
  .reset(shell_reset),
  .axi_full_from_user(axi_full_to_host),
  .axi_stream_to_link(axi_stream_tx_channels[1]),
  .axi_stream_from_link(axi_stream_aurora_rx)
);


sondos_shell_link_rx_arbiter #(.P_NUM_CH(2)) remote_rx_streaming_arbiter
(
  .clk(shell_clk),
  .reset(shell_reset),
  .signatures,
  .axi_stream_from_link(axi_stream_aurora_user_k_rx),
  .axi_stream_to_channels(axi_stream_rx_channels)
);

sondos_shell_link_tx_arbiter #(.P_NUM_CH(2)) remote_tx_streaming_arbiter
(
  .clk(shell_clk),
  .reset(shell_reset),
  .axi_stream_from_channels(axi_stream_tx_channels),
  .axi_stream_to_link(axi_stream_aurora_user_k_tx)
);

aurora_firefly_0_wrapper aurora_firefly_0_inst
(
  .tx(axi_stream_aurora_tx), // Bulk data
  .rx(axi_stream_aurora_rx), // Bulk data

  .user_k_tx(axi_stream_aurora_user_k_tx), // High priority
  .user_k_rx(axi_stream_aurora_user_k_rx), // High priority

  .ff0_rx_p       (sondos_io.ff0_rx_p),
  .ff0_rx_n       (sondos_io.ff0_rx_n),
  .ff0_tx_p       (sondos_io.ff0_tx_p),
  .ff0_tx_n       (sondos_io.ff0_tx_n),
  .ff0_refclk_p   (sondos_io.ff0_refclk_p),
  .ff0_refclk_n   (sondos_io.ff0_refclk_n),

  .lane_up(ff0_lane_up), // reversal is per Xilinx

  .hard_err_counter(hard_err_counter)           , //USR_CLK
  .soft_err_counter(soft_err_counter)           , //USR_CLK
  .crc_pass_fail_n_counter(crc_pass_fail_n_counter)    , //USR_CLK

  .channel_up(ff0_channel_up)         , //USR_CLK
  .sys_reset_out(shell_reset)      , //USR_CLK
  .gt_pll_lock(ff0_gt_pll_locked)        ,
  .user_clk_out(shell_clk)       ,
  .mmcm_not_locked_out(ff0_mmcm_not_locked),
  .sys_reset_n(aurora_reset_n),
  .user_reset(1'b0),
  .init_clk
);

sondos_shell_htg930_remote_init htg930_init_inst(
   .clk(init_clk),
   .reset(init_reset),

   .ff0_iic_scl_i,
   .ff0_iic_scl_o,
   .ff0_iic_scl_t,
   .ff0_iic_sda_i,
   .ff0_iic_sda_o,
   .ff0_iic_sda_t,

   .main_iic_scl_i,
   .main_iic_scl_o,
   .main_iic_scl_t,
   .main_iic_sda_i,
   .main_iic_sda_o,
   .main_iic_sda_t,

   .main_iic_resetn(sondos_io.main_iic_resetn),
   .main_iic_si_clk1_resetn(sondos_io.main_iic_si_clk1_resetn),
   .main_iic_si_clk2_resetn(sondos_io.main_iic_si_clk2_resetn),
   .ff0_reset_b(sondos_io.ff0_reset_b),
   .ff0_modsel_b(sondos_io.ff0_modsel_b),
   .aurora_reset_n(aurora_reset_n)
);

sysmon_wrapper sysmon_wrapper_inst
(
   .clk               (shell_clk),
   .reset             (shell_reset),
   .end_of_conversion (), // Signals that a data value below updated
   .channel           (), // Most recent channel converted
   .temp_data         (temperature_data),
   .vccint_data       (vccint_data), // Not read currently
   .vccaux_data       (vccaux_data), // Not read currently
   .vccbram_data      (vccbram_data)  // Not read currently
);

endmodule
