// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

module sondos_shell_u45n_host

import so_axi4_if_pkg::*,so_axi4l_if_pkg::*,so_axi4s_if_pkg::*;
(
   sondos_shell_u45n_host_if.shell sondos_io,

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

    wire aurora_0_clk;
    wire aurora_0_reset;


    logic [26:0] ff0_clk_counter;
    logic [26:0] ff1_clk_counter;

    wire [7:0] user_leds;
    wire [3:0] ff0_lane_up;
    wire ff0_channel_up;
    wire ff0_gt_pll_locked;
    wire ff0_mmcm_not_locked;

    wire  sys_clk;
    wire  sys_rst_n;


    so_axi4_if #(C_SO_AXI4_A64_D512) axi_full_flash (.aclk(axi_aclk), .aresetn(axi_aresetn));
    so_axi4_if #(C_SO_AXI4_A64_D512) axi_full_shell (.aclk(axi_aclk), .aresetn(axi_aresetn));
    so_axi4_if #(C_SO_AXI4_A64_D512) axi_full_remote_0 (.aclk(axi_aclk), .aresetn(axi_aresetn));
    so_axi4_if #(C_SO_AXI4_A64_D512) axi_full_to_host (.aclk(axi_aclk), .aresetn(axi_aresetn));

    so_axi4l_if #(C_SO_AXI4L_A32_D32) axi_lite_mmio_registers (.aclk(axi_aclk), .aresetn(axi_aresetn));
    so_axi4l_if #(C_SO_AXI4L_A32_D32) axi_lite_shell (.aclk(axi_aclk), .aresetn(axi_aresetn));
    so_axi4l_if #(C_SO_AXI4L_A32_D32) axi_lite_flash (.aclk(axi_aclk), .aresetn(axi_aresetn));
    so_axi4l_if #(C_SO_AXI4L_A24_D32) axi_lite_remote_0 (.aclk(axi_aclk), .aresetn(axi_aresetn));
    so_axi4l_if #(C_SO_AXI4L_A24_D32) axi_lite_cms (.aclk(axi_aclk), .aresetn(axi_aresetn));
    so_axi4l_if #(C_SO_AXI4L_A32_D32) axi_lite_leaves [4:0] (.aclk(axi_aclk), .aresetn(axi_aresetn));
    logic [5:0][1:0][63:0] register_address_map;

    // Define an AXI Lite bus for the autoconfig block.
    so_axi4l_if #(C_SO_AXI4L_A32_D32) axi_lite_qsfp_init (.aclk(axi_aclk), .aresetn(axi_aresetn));

    so_axi4s_if #(C_SO_AXI4S_D256) axi_stream_aurora_host_to_remote0 (.aclk(aurora_0_clk), .aresetn(aurora_0_reset));
    so_axi4s_if #(C_SO_AXI4S_D256) axi_stream_aurora_remote0_to_host (.aclk(aurora_0_clk), .aresetn(aurora_0_reset));

    so_axi4s_if #(C_SO_AXI4S_D256) axi_stream_aurora_user_k_host_to_remote0 (.aclk(aurora_0_clk), .aresetn(aurora_0_reset));
    so_axi4s_if #(C_SO_AXI4S_D256) axi_stream_aurora_user_k_remote0_to_host (.aclk(aurora_0_clk), .aresetn(aurora_0_reset));

    so_axi4s_if #(C_SO_AXI4S_D256) remote0_axi_stream_rx_channels [1:0] (.aclk(aurora_0_clk), .aresetn(~aurora_0_reset));
    so_axi4s_if #(C_SO_AXI4S_D256) remote0_axi_stream_tx_channels [1:0] (.aclk(aurora_0_clk), .aresetn(~aurora_0_reset));

    logic [1:0][7:0] signatures;
    assign signatures[0] = 8'h99;
    assign signatures[1] = 8'h77;


BUFG usrclk_bufg (.I(sondos_io.user_clk), .O(init_clk));


logic [28:0] user_clk_heartbeat;

logic [5:0] ff0_status;

logic [1:0] ff0_status_change;
logic [1:0] startup_kick;

logic [31:0] remote0_axi4f_write_master_status;
logic [31:0] remote0_axi4f_read_master_status;

logic config_start;
logic qsfp_config_start;
logic qsfp_config_done;
logic [1:0] qsfp_config_status; // Currently unused

assign shell_clk = axi_aclk;
assign shell_reset = ~axi_aresetn;

assign sys_rst_n = sondos_io.pcie_rst_n;


assign register_address_map[0][0]=64'h0000_0000_0000_0000; //user
assign register_address_map[0][1]=64'h0000_0000_00EF_FFFF;

assign register_address_map[1][0]=64'h0000_0000_00F0_0000; // shell common
assign register_address_map[1][1]=64'h0000_0000_00F7_FFFF;

assign register_address_map[4][0]=64'h0000_0000_00F8_0000; // Alveo card CMS
assign register_address_map[4][1]=64'h0000_0000_00FE_FFFF;

assign register_address_map[2][0]=64'h0000_0000_00FF_0000; // shell Flash
assign register_address_map[2][1]=64'h0000_0000_00FF_FFFF;

assign register_address_map[3][0]=64'h0000_0000_0100_0000; // remote 0
assign register_address_map[3][1]=64'h0000_0000_01FF_FFFF;


`CONNECT_SO_AXI4L_IF(axi_lite_leaves[0],axi_lite_user);
`CONNECT_SO_AXI4L_IF(axi_lite_leaves[1],axi_lite_shell);
`CONNECT_SO_AXI4L_IF(axi_lite_leaves[2],axi_lite_flash);
`CONNECT_SO_AXI4L_IF(axi_lite_leaves[3],axi_lite_remote_0);
`CONNECT_SO_AXI4L_IF(axi_lite_leaves[4],axi_lite_cms);


sondos_axi_crossbar_wrapper axif_crossbar_inst
(
  .axi_full_client_0(axi_full_user),
  .axi_full_client_1(axi_full_remote_0),
  .axi_full_client_2(axi_full_flash),
  .axi_full_to_host
);


sondos_axi4l_crossbar
#(.P_NUM_LEAFS(5)
)axilite_crossbar_inst(
   .aclk(axi_aclk),
   .aresetn(axi_aresetn),
   .map(register_address_map),
   .trunk_bus(axi_lite_mmio_registers),
   .leaf_bus(axi_lite_leaves)
);

sondos_qdma_wrapper qdma_wrapper_inst
(
    .sys_clk_p(sondos_io.pcie_clk_p),
    .sys_clk_n(sondos_io.pcie_clk_n),
    .sys_rst_n(sondos_io.pcie_rst_n),

    .user_clk_250(axi_aclk),
    .user_reset_n(axi_aresetn),
    .user_lnk_up,

    .pci_exp_txp(sondos_io.pci_exp_txp),
    .pci_exp_txn(sondos_io.pci_exp_txn),
    .pci_exp_rxp(sondos_io.pci_exp_rxp),
    .pci_exp_rxn(sondos_io.pci_exp_rxn),

    .axi_full_c2h(axi_full_to_host),
    .axi_lite_mmio_registers(axi_lite_mmio_registers)
    );

sondos_shell_alveo_flash_top #(.DEVICE_ID("ALV_U45N")) u45n_flash_programmer_inst
(
   .clk(axi_aclk),
   .reset(~axi_aresetn),
   .done_beat(user_clk_heartbeat[25]),
   .axi_full_flash(axi_full_flash),
   .axi_lite_flash(axi_lite_flash)
);

sondos_shell_u45n_host_csr shell_csr_inst (
   .clk(axi_aclk),
   .reset(~axi_aresetn),
   .axi_lite_user(axi_lite_shell),

   .remote0_axi4f_write_master_status,
   .remote0_axi4f_read_master_status,

   .ff0_status(ff0_status),

   .ff0_soft_err_counter(ff0_soft_error_counter_cdc),
   .ff0_hard_err_counter(ff0_hard_error_counter_cdc),
   .ff0_crc_pass_fail_n_counter(ff0_crc_pass_fail_n_counter_cdc),

   .qsfp_config_start(qsfp_config_start),
   .qsfp_config_done(qsfp_config_done),
   .qsfp_config_status(qsfp_config_status)
);


always_ff @(posedge aurora_0_clk) begin
    if(~sys_rst_n) begin
        ff0_clk_counter <= '0;
    end else begin
        ff0_clk_counter <= ff0_clk_counter + 1'b1;
    end
end

always @(posedge axi_aclk) begin
   if(~sys_rst_n) begin
      user_clk_heartbeat <= '0;
   end else begin
      user_clk_heartbeat <= user_clk_heartbeat + 1'b1;
   end
end

packetized_axi4l_slave packetized_axi4l_slave_inst_0
(
    .host_clk(axi_aclk),
    .user_clk(aurora_0_clk),
    .reset(~axi_aresetn),
    .axi_lite_from_host(axi_lite_remote_0),
    .axi_stream_to_link(remote0_axi_stream_tx_channels[0]), // User K
    .axi_stream_from_link(remote0_axi_stream_rx_channels[0]) // User K
);

packetized_axi4f_write_master axi4f_master_write_inst_0
(
   .axif_clk(axi_aclk),
   .axis_clk(aurora_0_clk),
   .axif_reset(~axi_aresetn),
   .axi_full_to_host(axi_full_remote_0),
   .status(remote0_axi4f_write_master_status),
   .axi_stream_to_link(remote0_axi_stream_tx_channels[1]), // User K
   .axi_stream_from_link(axi_stream_aurora_remote0_to_host) // Bulk
);

packetized_axi4f_read_master axi4f_master_read_inst_0
(
   .axif_clk(axi_aclk),
   .axis_clk(aurora_0_clk),
   .axif_reset(~axi_aresetn),
   .axi_full_to_host(axi_full_remote_0),
   .status(remote0_axi4f_read_master_status),
   .axi_stream_to_link(axi_stream_aurora_host_to_remote0), // Bulk data
   .axi_stream_from_link(remote0_axi_stream_rx_channels[1]) // User K
);

sondos_shell_link_rx_arbiter #(.P_NUM_CH(2)) rx_streaming_arbiter_unit_0
(
   .clk(aurora_0_clk),
   .reset(aurora_0_reset),
   .signatures,
   .axi_stream_from_link(axi_stream_aurora_user_k_remote0_to_host),
   .axi_stream_to_channels(remote0_axi_stream_rx_channels)
);

sondos_shell_link_tx_arbiter #(.P_NUM_CH(2)) tx_streaming_arbiter_unit_0
(
   .clk(aurora_0_clk),
   .reset(aurora_0_reset),
   .axi_stream_from_channels(remote0_axi_stream_tx_channels),
   .axi_stream_to_link(axi_stream_aurora_user_k_host_to_remote0)
);

logic [31:0] ff0_hard_err_counter;
logic [31:0] ff0_soft_err_counter;
logic [31:0] ff0_crc_pass_fail_n_counter;

  aurora_firefly_0_wrapper aurora_firefly_0_inst
(
  .tx(axi_stream_aurora_host_to_remote0), // Bulk data
  .rx(axi_stream_aurora_remote0_to_host), // Bulk data

  .user_k_tx(axi_stream_aurora_user_k_host_to_remote0), // High priority
  .user_k_rx(axi_stream_aurora_user_k_remote0_to_host), // High priority

  .ff0_rx_p       (sondos_io.ff0_rx_p),
  .ff0_rx_n       (sondos_io.ff0_rx_n),
  .ff0_tx_p       (sondos_io.ff0_tx_p),
  .ff0_tx_n       (sondos_io.ff0_tx_n),
  .ff0_refclk_p   (sondos_io.ff0_refclk_p),
  .ff0_refclk_n   (sondos_io.ff0_refclk_n),

  .lane_up(ff0_lane_up), // reversal is per Xilinx
  .hard_err_counter(ff0_hard_err_counter),
  .soft_err_counter(ff0_soft_err_counter),
  .crc_pass_fail_n_counter(ff0_crc_pass_fail_n_counter),
  .channel_up(ff0_channel_up)         , //USR_CLK
  .sys_reset_out(aurora_0_reset)      , //USR_CLK
  .gt_pll_lock(ff0_gt_pll_locked)        ,
  .user_clk_out(aurora_0_clk)       ,
  .mmcm_not_locked_out(ff0_mmcm_not_locked),
  .sys_reset_n(sys_rst_n),
  .user_reset(1'b0),
  .init_clk
);

xpm_cdc_array_single #(
   .DEST_SYNC_FF(2),
   .INIT_SYNC_FF(0),
   .SIM_ASSERT_CHK(0),
   .SRC_INPUT_REG(0),
   .WIDTH(6)
)
ff0_status_sync_inst (
   .dest_out(ff0_status),
   .dest_clk(axi_aclk),
   .src_clk(aurora_0_clk),
   .src_in({(~ff0_mmcm_not_locked), ff0_channel_up, ff0_lane_up})
);

always @(posedge axi_aclk) begin
   if(~axi_aresetn) begin
      ff0_status_change <= 0;
      startup_kick <= 0;
   end else begin
      ff0_status_change <= {ff0_status_change[0], &ff0_status};
      startup_kick <= {startup_kick[0], (startup_kick[0] | user_clk_heartbeat[28])};
   end
end

cms_wrapper cms_wrapper_inst (
   .clk                (axi_aclk),
   .rst_n              (axi_aresetn),
   .satellite_gpio     (sondos_io.satellite_gpio),
   .satellite_uart_rxd (sondos_io.satellite_uart_rxd),
   .satellite_uart_txd (sondos_io.satellite_uart_txd),
   .axi_lite_user      (axi_lite_cms),
   .axi_lite_autoconfig(axi_lite_qsfp_init),
   .interrupt_host     () // TODO: Connect when interrupts are added
);

// The QSFP config starts one of three ways:
// 1. Automatically at boot
// 2. On a QSFP insertion via FF0 status changing
// 3. Invoked by the user CSR
assign config_start = (ff0_status_change == 2'b01) | (startup_kick == 2'b01) | qsfp_config_start;

alveo_u45n_qsfp_init (
   .clk             (axi_aclk),
   .reset           (~axi_aresetn),
   .config_start    (config_start),
   .axi_lite_to_cms (axi_lite_qsfp_init),
   .config_done     (qsfp_config_done),
   .config_status   (qsfp_config_status)
);

endmodule
