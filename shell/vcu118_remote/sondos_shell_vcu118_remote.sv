// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

module sondos_shell_vcu118_remote

   import so_axi4_if_pkg::*,so_axi4l_if_pkg::*,so_axi4s_if_pkg::*;
(
   sondos_shell_vcu118_remote_if.shell sondos_io,

   output shell_clk,
   output shell_reset,

   so_axi4l_if.master axi_lite_user,
   so_axi4_if.slave axi_full_user,

   so_axi4s_if.slave axi_stream_tx_c2c, // not implemented yet
   so_axi4s_if.master axi_stream_rx_c2c // not implemented yet
);
wire user_lnk_up;
wire init_clk_int;
wire init_clk;

logic [26:0] ff0_clk_counter;

wire [7:0] user_leds;
wire [3:0] ff0_lane_up;
wire channel_up;
wire gt_pll_locked;
wire ff0_mmcm_not_locked;

wire  iic_scl_i;
wire  iic_scl_o;
wire  iic_scl_t;
wire  iic_sda_i;
wire  iic_sda_o;
wire  iic_sda_t;

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

sondos_shell_vcu118_flash_top vcu118_flash_programmer_inst(
   .clk(shell_clk),
   .reset(shell_reset),
   .done_beat(ff0_clk_counter[25]),
   .axi_full_flash(axi_full_flash),
   .axi_lite_flash(axi_lite_flash),

   .spi_cs_1_n(sondos_io.spi_cs_1_n),
   .spi_io_1_io(sondos_io.spi_io_1_io)
);

logic [31:0] hard_err_counter;
logic [31:0] soft_err_counter;
logic [31:0] crc_pass_fail_n_counter;

sondos_shell_vcu118_remote_csr shell_csr_inst (
    .clk(shell_clk),
    .reset(shell_reset),
    .axi_lite_user(axi_lite_shell),

    .iic_scl_i,
    .iic_scl_o,
    .iic_scl_t,
    .iic_sda_i,
    .iic_sda_o,
    .iic_sda_t,

    .hard_err_counter,
    .soft_err_counter,
    .crc_pass_fail_n_counter,

    .aurora_reset(),

    .spi_reset(spi_reset),
    .read_reg_command(read_reg_command),
    .spi_fsm_start(spi_fsm_start),
    .spi_fsm_command(spi_fsm_command),
    .spi_starting_address(spi_starting_address),
    .spi_ending_address(spi_ending_address),
    .spi_current_address(spi_current_address),
    .spi_state(spi_state),

    .temperature_data,
    .vccint_data,
    .vccaux_data,
    .vccbram_data
);


assign sondos_io.shell_leds[0] = ff0_clk_counter[25];
assign sondos_io.shell_leds[1] = (&ff0_lane_up) & channel_up & gt_pll_locked & ~ff0_mmcm_not_locked;
assign sondos_io.shell_leds[2] = ~ff0_mmcm_not_locked;
assign sondos_io.shell_leds[3] = gt_pll_locked;
assign sondos_io.qsfp_modsell = '0;
assign sondos_io.qsfp_resetl  = '1;
assign sondos_io.qsfp_lpmode  = '0;
assign sondos_io.qsfp_modprsl = '0;

assign sondos_io.ff0_modsel_b = 1'b0;
assign sondos_io.ff0_reset_b = 1'b1;

always_ff @(posedge shell_clk) begin
    if(shell_reset) begin
        ff0_clk_counter <= '0;
    end else begin
        ff0_clk_counter <= ff0_clk_counter + 1'b1;
    end
end

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

  .channel_up(channel_up)         , //USR_CLK
  .sys_reset_out(shell_reset)      , //USR_CLK
  .gt_pll_lock(gt_pll_locked)        ,
  .user_clk_out(shell_clk)       ,
  .mmcm_not_locked_out(ff0_mmcm_not_locked),
  .sys_reset_n(~sondos_io.aurora_external_reset),
  .user_reset(1'b0),
  .init_clk
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
