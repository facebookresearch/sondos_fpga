// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

module sondos_shell_htg930_host

import so_axi4_if_pkg::*,so_axi4l_if_pkg::*,so_axi4s_if_pkg::*;
(
   sondos_shell_htg930_host_if.shell sondos_io,

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
    wire aurora_1_clk;
    wire aurora_1_reset;


    logic [26:0] ff0_clk_counter;
    logic [26:0] ff1_clk_counter;

    wire [7:0] user_leds;
    wire [3:0] ff0_lane_up;
    wire ff0_channel_up;
    wire ff0_gt_pll_locked;
    wire ff0_mmcm_not_locked;
    wire [3:0] ff1_lane_up;
    wire ff1_channel_up;
    wire ff1_gt_pll_locked;
    wire ff1_mmcm_not_locked;
    wire aurora_reset_sync;
    wire aurora_reset;

    wire  sys_clk;
    wire  sys_rst_n;

    wire  ff0_iic_scl_i;
    wire  ff0_iic_scl_o;
    wire  ff0_iic_scl_t;
    wire  ff0_iic_sda_i;
    wire  ff0_iic_sda_o;
    wire  ff0_iic_sda_t;

    wire  ff1_iic_scl_i;
    wire  ff1_iic_scl_o;
    wire  ff1_iic_scl_t;
    wire  ff1_iic_sda_i;
    wire  ff1_iic_sda_o;
    wire  ff1_iic_sda_t;

    wire  main_iic_scl_i;
    wire  main_iic_scl_o;
    wire  main_iic_scl_t;
    wire  main_iic_sda_i;
    wire  main_iic_sda_o;
    wire  main_iic_sda_t;


    so_axi4_if #(C_SO_AXI4_A64_D512) axi_full_flash (.aclk(axi_aclk), .aresetn(axi_aresetn));
    so_axi4_if #(C_SO_AXI4_A64_D512) axi_full_shell (.aclk(axi_aclk), .aresetn(axi_aresetn));
    so_axi4_if #(C_SO_AXI4_A64_D512) axi_full_remote_0 (.aclk(axi_aclk), .aresetn(axi_aresetn));
    so_axi4_if #(C_SO_AXI4_A64_D512) axi_full_remote_1 (.aclk(axi_aclk), .aresetn(axi_aresetn));
    so_axi4_if #(C_SO_AXI4_A64_D512) axi_full_to_host (.aclk(axi_aclk), .aresetn(axi_aresetn));

    so_axi4l_if #(C_SO_AXI4L_A32_D32) axi_lite_mmio_registers (.aclk(axi_aclk), .aresetn(axi_aresetn));
    so_axi4l_if #(C_SO_AXI4L_A32_D32) axi_lite_shell (.aclk(axi_aclk), .aresetn(axi_aresetn));
    so_axi4l_if #(C_SO_AXI4L_A32_D32) axi_lite_flash (.aclk(axi_aclk), .aresetn(axi_aresetn));
    so_axi4l_if #(C_SO_AXI4L_A24_D32) axi_lite_remote_0 (.aclk(axi_aclk), .aresetn(axi_aresetn));
    so_axi4l_if #(C_SO_AXI4L_A24_D32) axi_lite_remote_1 (.aclk(axi_aclk), .aresetn(axi_aresetn));
    so_axi4l_if #(C_SO_AXI4L_A32_D32) axi_lite_leaves [4:0] (.aclk(axi_aclk), .aresetn(axi_aresetn));
    logic [4:0][1:0][63:0] register_address_map;

    so_axi4s_if #(C_SO_AXI4S_D256) axi_stream_aurora_host_to_remote0 (.aclk(aurora_0_clk), .aresetn(aurora_0_reset));
    so_axi4s_if #(C_SO_AXI4S_D256) axi_stream_aurora_remote0_to_host (.aclk(aurora_0_clk), .aresetn(aurora_0_reset));

    so_axi4s_if #(C_SO_AXI4S_D256) axi_stream_aurora_user_k_host_to_remote0 (.aclk(aurora_0_clk), .aresetn(aurora_0_reset));
    so_axi4s_if #(C_SO_AXI4S_D256) axi_stream_aurora_user_k_remote0_to_host (.aclk(aurora_0_clk), .aresetn(aurora_0_reset));

    so_axi4s_if #(C_SO_AXI4S_D256) axi_stream_aurora_host_to_remote1 (.aclk(aurora_1_clk), .aresetn(aurora_1_reset));
    so_axi4s_if #(C_SO_AXI4S_D256) axi_stream_aurora_remote1_to_host (.aclk(aurora_1_clk), .aresetn(aurora_1_reset));

    so_axi4s_if #(C_SO_AXI4S_D256) axi_stream_aurora_user_k_host_to_remote1 (.aclk(aurora_1_clk), .aresetn(aurora_1_reset));
    so_axi4s_if #(C_SO_AXI4S_D256) axi_stream_aurora_user_k_remote1_to_host (.aclk(aurora_1_clk), .aresetn(aurora_1_reset));

    so_axi4s_if #(C_SO_AXI4S_D256) remote0_axi_stream_rx_channels [1:0] (.aclk(aurora_0_clk), .aresetn(~aurora_0_reset));
    so_axi4s_if #(C_SO_AXI4S_D256) remote0_axi_stream_tx_channels [1:0] (.aclk(aurora_0_clk), .aresetn(~aurora_0_reset));

    so_axi4s_if #(C_SO_AXI4S_D256) remote1_axi_stream_rx_channels [1:0] (.aclk(aurora_1_clk), .aresetn(~aurora_1_reset));
    so_axi4s_if #(C_SO_AXI4S_D256) remote1_axi_stream_tx_channels [1:0] (.aclk(aurora_1_clk), .aresetn(~aurora_1_reset));

    logic [1:0][7:0] signatures;
    assign signatures[0] = 8'h99;
    assign signatures[1] = 8'h77;


IBUFDS usrclk_ibuf (.O(init_clk_int), .I(sondos_io.user_clk_p), .IB(sondos_io.user_clk_n));
BUFG usrclk_bufg (.I(init_clk_int), .O(init_clk));


logic [28:0] user_clk_heartbeat;

logic [11:0] fan_pwm_counter;
logic fan_prev_msb;
logic [7:0] pulse_extender;
logic [7:0] fan_speed;
logic [7:0] fan_speed_sync;
logic fan_handshake_sig;

logic [5:0] ff0_status;
logic [5:0] ff1_status;

logic spi_reset;
logic [7:0] read_reg_command;
logic spi_start_reading;
logic [7:0] spi_fsm_command;
logic [31:0] spi_starting_address;
logic [31:0] spi_ending_address;
logic [31:0] spi_current_address;
logic [7:0] spi_state;
logic [31:0] remote0_axi4f_write_master_status;
logic [31:0] remote1_axi4f_write_master_status;
logic [31:0] remote0_axi4f_read_master_status;
logic [31:0] remote1_axi4f_read_master_status;


assign shell_clk = axi_aclk;
assign shell_reset = ~axi_aresetn;

assign axi_full_shell.awvalid = 1'b0;
assign axi_full_shell.wvalid = 1'b0;
assign axi_full_shell.arvalid = 1'b0;
assign axi_full_shell.rready = 1'b0;
assign axi_full_shell.bready = 1'b0;

assign sys_rst_n = sondos_io.pcie_rst_n;


assign register_address_map[0][0]=64'h0000_0000_0000_0000; //user
assign register_address_map[0][1]=64'h0000_0000_00EF_FFFF;

assign register_address_map[1][0]=64'h0000_0000_00F0_0000; // shell common
assign register_address_map[1][1]=64'h0000_0000_00FE_FFFF;

assign register_address_map[2][0]=64'h0000_0000_00FF_0000; // shell Flash
assign register_address_map[2][1]=64'h0000_0000_00FF_FFFF;

assign register_address_map[3][0]=64'h0000_0000_0100_0000; // remote 1
assign register_address_map[3][1]=64'h0000_0000_01FF_FFFF;

assign register_address_map[4][0]=64'h0000_0000_0200_0000; // remote 2
assign register_address_map[4][1]=64'h0000_0000_02FF_FFFF;

`CONNECT_SO_AXI4L_IF(axi_lite_leaves[0],axi_lite_user);
`CONNECT_SO_AXI4L_IF(axi_lite_leaves[1],axi_lite_shell);
`CONNECT_SO_AXI4L_IF(axi_lite_leaves[2],axi_lite_flash);
`CONNECT_SO_AXI4L_IF(axi_lite_leaves[3],axi_lite_remote_0);
`CONNECT_SO_AXI4L_IF(axi_lite_leaves[4],axi_lite_remote_1);


sondos_axi_crossbar_s4_wrapper axif_crossbar_inst
(
  .axi_full_client_0(axi_full_user),
  .axi_full_client_1(axi_full_remote_0),
  .axi_full_client_2(axi_full_remote_1),
  .axi_full_client_3(axi_full_flash),
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

sondos_shell_htg930_flash_top htg930_flash_programmer_inst
(
   .clk(axi_aclk),
   .reset(~axi_aresetn),
   .done_beat(ff0_clk_counter[25]),
   .axi_full_flash(axi_full_flash),
   .axi_lite_flash(axi_lite_flash),

   .bpi_data_hi_io(sondos_io.bpi_data_hi_io),
   .bpi_addr(sondos_io.bpi_addr),
   .bpi_adv_b(sondos_io.bpi_adv_b),
   .bpi_foe_b(sondos_io.bpi_foe_b),
   .bpi_fwe_b(sondos_io.bpi_fwe_b)
);


sondos_shell_htg930_host_csr shell_csr_inst (
   .clk(axi_aclk),
   .reset(~axi_aresetn),
   .axi_lite_user(axi_lite_shell),

   .ff0_iic_scl_i,
   .ff0_iic_scl_o,
   .ff0_iic_scl_t,
   .ff0_iic_sda_i,
   .ff0_iic_sda_o,
   .ff0_iic_sda_t,

   .ff1_iic_scl_i,
   .ff1_iic_scl_o,
   .ff1_iic_scl_t,
   .ff1_iic_sda_i,
   .ff1_iic_sda_o,
   .ff1_iic_sda_t,

   .main_iic_scl_i,
   .main_iic_scl_o,
   .main_iic_scl_t,
   .main_iic_sda_i,
   .main_iic_sda_o,
   .main_iic_sda_t,

   .fan_speed,
   .remote0_axi4f_write_master_status,
   .remote1_axi4f_write_master_status,
   .remote0_axi4f_read_master_status,
   .remote1_axi4f_read_master_status,

   .main_iic_resetn(sondos_io.main_iic_resetn),
   .main_iic_si_clk1_resetn(sondos_io.main_iic_si_clk1_resetn),
   .main_iic_si_clk2_resetn(sondos_io.main_iic_si_clk2_resetn),
   .ff0_reset_b(sondos_io.ff0_reset_b),
   .ff0_modsel_b(sondos_io.ff0_modsel_b),
   .ff1_reset_b(sondos_io.ff1_reset_b),
   .ff1_modsel_b(sondos_io.ff1_modsel_b),
   .ff_present_b({sondos_io.ff2_present_b,sondos_io.ff1_present_b,sondos_io.ff0_present_b}),

   .ff0_status(ff0_status),
   .ff1_status(ff1_status),

   .ff0_soft_err_counter(ff0_soft_error_counter_cdc),
   .ff0_hard_err_counter(ff0_hard_error_counter_cdc),
   .ff0_crc_pass_fail_n_counter(ff0_crc_pass_fail_n_counter_cdc),

   .ff1_soft_err_counter(ff1_soft_error_counter_cdc),
   .ff1_hard_err_counter(ff1_hard_error_counter_cdc),
   .ff1_crc_pass_fail_n_counter(ff1_crc_pass_fail_n_counter_cdc),

   .aurora_reset,

   .spi_reset(spi_reset),
   .read_reg_command(read_reg_command),
   .spi_fsm_start(spi_fsm_start),
   .spi_fsm_command(spi_fsm_command),
   .spi_starting_address(spi_starting_address),
   .spi_ending_address(spi_ending_address),
   .spi_current_address(spi_current_address),
   .spi_state(spi_state)
);

assign sondos_io.shell_leds[0] = user_clk_heartbeat[26];
assign sondos_io.shell_leds[1] = ff0_clk_counter[26];
assign sondos_io.shell_leds[2] = ff1_clk_counter[26];
assign sondos_io.shell_leds[3] = 1'b0;

//assign sondos_io.iic_mux_reset_b  = 1'b1;

assign sondos_io.fan_en = |pulse_extender;

always_ff @(posedge init_clk) begin
   if(~sys_rst_n) begin
      fan_pwm_counter <= '1;
      fan_prev_msb <= 1'b0;
      pulse_extender <= '1;
   end else begin
      fan_pwm_counter <= fan_pwm_counter + fan_speed_sync;
      fan_prev_msb <= fan_pwm_counter[11];
      pulse_extender <= {pulse_extender[6:0],(fan_pwm_counter[11] ^ fan_prev_msb)};
   end
end
xpm_cdc_handshake #(
   .DEST_EXT_HSK(0),
   .DEST_SYNC_FF(2),
   .SRC_SYNC_FF(2),
   .WIDTH($bits(fan_speed))
)
fan_speed_cdc (
   .dest_out(fan_speed_sync),
   .dest_req(),
   .src_rcv(fan_handshake_sig),
   .dest_ack(),
   .dest_clk(init_clk),
   .src_clk(axi_aclk),
   .src_in(fan_speed),
   .src_send(~fan_handshake_sig)
);

always_ff @(posedge aurora_0_clk) begin
    if(~sys_rst_n) begin
        ff0_clk_counter <= '0;
    end else begin
        ff0_clk_counter <= ff0_clk_counter + 1'b1;
    end
end

always_ff @(posedge aurora_1_clk) begin
    if(~sys_rst_n) begin
        ff1_clk_counter <= '0;
    end else begin
        ff1_clk_counter <= ff1_clk_counter + 1'b1;
    end
end

always @(posedge axi_aclk) begin
   if(~sys_rst_n) begin
      user_clk_heartbeat <= '0;
   end else begin
      user_clk_heartbeat <= user_clk_heartbeat + 1'b1;
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

IOBUF ff1_iic_scl_inst (
   .O (ff1_iic_scl_i),
   .I (ff1_iic_scl_o),
   .IO(sondos_io.ff1_iic_scl),
   .T (ff1_iic_scl_t)
);

IOBUF ff1_iic_sda_inst (
   .O (ff1_iic_sda_i),
   .I (ff1_iic_sda_o),
   .IO(sondos_io.ff1_iic_sda),
   .T (ff1_iic_sda_t)
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

xpm_cdc_single aurora_reset_sync_inst (
   .dest_out(aurora_reset_sync),
   .dest_clk(init_clk),
   .src_clk(axi_aclk),
   .src_in(aurora_reset)
);


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
  .user_reset(aurora_reset_sync),
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

// CDC for aurora error counters
logic [31:0] ff0_hard_err_counter_cdc;
logic [31:0] ff0_soft_err_counter_cdc;
logic [31:0] ff0_crc_pass_fail_n_counter_cdc;

logic [31:0] ff1_hard_err_counter_cdc;
logic [31:0] ff1_soft_err_counter_cdc;
logic [31:0] ff1_crc_pass_fail_n_counter_cdc;

logic [31:0] ff1_hard_err_counter;
logic [31:0] ff1_soft_err_counter;
logic [31:0] ff1_crc_pass_fail_n_counter;

xpm_cdc_gray #(
    .DEST_SYNC_FF(4),
    .INIT_SYNC_FF(0),
    .REG_OUTPUT(0),
    .SIM_ASSERT_CHK(0),
    .SIM_LOSSLESS_GRAY_CHK(0),
    .WIDTH(32)
) xpm_cdc_gray_0 (
    .dest_out_bin   (ff0_crc_pass_fail_n_counter_cdc),
    .dest_clk       (axi_aclk),
    .src_clk        (aurora_0_clk),
    .src_in_bin     (ff0_crc_pass_fail_n_counter)
);

xpm_cdc_gray #(
    .DEST_SYNC_FF(4),
    .INIT_SYNC_FF(0),
    .REG_OUTPUT(0),
    .SIM_ASSERT_CHK(0),
    .SIM_LOSSLESS_GRAY_CHK(0),
    .WIDTH(32)
) xpm_cdc_gray_1 (
    .dest_out_bin   (ff0_hard_err_counter_cdc),
    .dest_clk       (axi_aclk),
    .src_clk        (aurora_0_clk),
    .src_in_bin     (ff0_hard_err_counter)
);

xpm_cdc_gray #(
    .DEST_SYNC_FF(4),
    .INIT_SYNC_FF(0),
    .REG_OUTPUT(0),
    .SIM_ASSERT_CHK(0),
    .SIM_LOSSLESS_GRAY_CHK(0),
    .WIDTH(32)
) xpm_cdc_gray_2 (
    .dest_out_bin   (ff0_soft_err_counter_cdc),
    .dest_clk       (axi_aclk),
    .src_clk        (aurora_0_clk),
    .src_in_bin     (ff0_soft_err_counter)
);

xpm_cdc_gray #(
    .DEST_SYNC_FF(4),
    .INIT_SYNC_FF(0),
    .REG_OUTPUT(0),
    .SIM_ASSERT_CHK(0),
    .SIM_LOSSLESS_GRAY_CHK(0),
    .WIDTH(32)
) xpm_cdc_gray_3 (
    .dest_out_bin   (ff1_crc_pass_fail_n_counter_cdc),
    .dest_clk       (axi_aclk),
    .src_clk        (aurora_1_clk),
    .src_in_bin     (ff1_crc_pass_fail_n_counter)
);

xpm_cdc_gray #(
    .DEST_SYNC_FF(4),
    .INIT_SYNC_FF(0),
    .REG_OUTPUT(0),
    .SIM_ASSERT_CHK(0),
    .SIM_LOSSLESS_GRAY_CHK(0),
    .WIDTH(32)
) xpm_cdc_gray_4 (
    .dest_out_bin   (ff1_hard_err_counter_cdc),
    .dest_clk       (axi_aclk),
    .src_clk        (aurora_1_clk),
    .src_in_bin     (ff1_hard_err_counter)
);

xpm_cdc_gray #(
    .DEST_SYNC_FF(4),
    .INIT_SYNC_FF(0),
    .REG_OUTPUT(0),
    .SIM_ASSERT_CHK(0),
    .SIM_LOSSLESS_GRAY_CHK(0),
    .WIDTH(32)
) xpm_cdc_gray_5 (
    .dest_out_bin   (ff1_soft_error_counter_cdc),
    .dest_clk       (axi_aclk),
    .src_clk        (aurora_1_clk),
    .src_in_bin     (ff1_soft_err_counter)
);

packetized_axi4l_slave packetized_axi4l_slave_inst_1
(
    .host_clk(axi_aclk),
    .user_clk(aurora_1_clk),
    .reset(~axi_aresetn),
    .axi_lite_from_host(axi_lite_remote_1),
    .axi_stream_to_link(remote1_axi_stream_tx_channels[0]), // User K
    .axi_stream_from_link(remote1_axi_stream_rx_channels[0]) // User K
);

packetized_axi4f_write_master axi4f_master_write_inst_1
(
   .axif_clk(axi_aclk),
   .axis_clk(aurora_1_clk),
   .axif_reset(~axi_aresetn),
   .axi_full_to_host(axi_full_remote_1),
   .status(remote1_axi4f_write_master_status),
   .axi_stream_to_link(remote1_axi_stream_tx_channels[1]), // User K
   .axi_stream_from_link(axi_stream_aurora_remote1_to_host) // Bulk
);

packetized_axi4f_read_master axi4f_master_read_inst_1
(
   .axif_clk(axi_aclk),
   .axis_clk(aurora_1_clk),
   .axif_reset(~axi_aresetn),
   .axi_full_to_host(axi_full_remote_1),
   .status(remote1_axi4f_read_master_status),
   .axi_stream_to_link(axi_stream_aurora_host_to_remote1), // Bulk data
   .axi_stream_from_link(remote1_axi_stream_rx_channels[1]) // User K
);

sondos_shell_link_rx_arbiter #(.P_NUM_CH(2)) rx_streaming_arbiter_unit_1
(
   .clk(aurora_1_clk),
   .reset(aurora_1_reset),
   .signatures,
   .axi_stream_from_link(axi_stream_aurora_user_k_remote1_to_host),
   .axi_stream_to_channels(remote1_axi_stream_rx_channels)
);

sondos_shell_link_tx_arbiter #(.P_NUM_CH(2)) tx_streaming_arbiter_unit_1
(
   .clk(aurora_1_clk),
   .reset(aurora_1_reset),
   .axi_stream_from_channels(remote1_axi_stream_tx_channels),
   .axi_stream_to_link(axi_stream_aurora_user_k_host_to_remote1)
);

  aurora_firefly_1_wrapper aurora_firefly_1_inst
(
  .tx(axi_stream_aurora_host_to_remote1), // Bulk data
  .rx(axi_stream_aurora_remote1_to_host), // Bulk data

  .user_k_tx(axi_stream_aurora_user_k_host_to_remote1), // High priority
  .user_k_rx(axi_stream_aurora_user_k_remote1_to_host), // High priority

  .ff1_rx_p       (sondos_io.ff1_rx_p),
  .ff1_rx_n       (sondos_io.ff1_rx_n),
  .ff1_tx_p       (sondos_io.ff1_tx_p),
  .ff1_tx_n       (sondos_io.ff1_tx_n),
  .ff1_refclk_p   (sondos_io.ff1_refclk_p),
  .ff1_refclk_n   (sondos_io.ff1_refclk_n),

  .hard_err_counter(ff1_hard_err_counter),
  .soft_err_counter(ff1_soft_err_counter),
  .crc_pass_fail_n_counter(ff1_crc_pass_fail_n_counter),

  .lane_up(ff1_lane_up), // reversal is per Xilinx
  .channel_up(ff1_channel_up)         , //USR_CLK
  .sys_reset_out(aurora_1_reset)      , //USR_CLK
  .gt_pll_lock(ff1_gt_pll_locked)        ,
  .user_clk_out(aurora_1_clk)       ,
  .mmcm_not_locked_out(ff1_mmcm_not_locked),
  .sys_reset_n(sys_rst_n),
  .user_reset(aurora_reset_sync),
  .init_clk
);

xpm_cdc_array_single #(
   .DEST_SYNC_FF(2),
   .INIT_SYNC_FF(0),
   .SIM_ASSERT_CHK(0),
   .SRC_INPUT_REG(0),
   .WIDTH(6)
)
ff1_status_sync_inst (
   .dest_out(ff1_status),
   .dest_clk(axi_aclk),
   .src_clk(aurora_1_clk),
   .src_in({(~ff1_mmcm_not_locked), ff1_channel_up, ff1_lane_up})
);

endmodule
