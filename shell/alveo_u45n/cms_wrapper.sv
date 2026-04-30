// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.
// Copyright (c) Meta Platforms, Inc. and affiliates.
//-----------------------------------------------------------------------------
// Title: Wrapper for the Alveo Card Management Solution Subsystem
//-----------------------------------------------------------------------------
// Description: The Alveo system uses a Microblaze to configure the card.
//   https://docs.amd.com/r/en-US/pg348-cms-subsystem/Introduction
//-----------------------------------------------------------------------------
module cms_wrapper
(
   input wire clk,
   input wire rst_n,
   input wire [1:0] satellite_gpio,

   input wire satellite_uart_rxd,
   output wire satellite_uart_txd,
   so_axi4l_if.slave axi_lite_user,
   so_axi4l_if.slave axi_lite_autoconfig,
   output wire interrupt_host
);

   cms_subsystem cms_subsystem_i (
      .clk250                 (clk),
      .resetn                 (rst_n),
      .interrupt_host         (interrupt_host),
      .user_axi_araddr        (axi_lite_user.araddr[17:0]),
      .user_axi_arprot        (axi_lite_user.arprot),
      .user_axi_arready       (axi_lite_user.arready),
      .user_axi_arvalid       (axi_lite_user.arvalid),
      .user_axi_awaddr        (axi_lite_user.awaddr[17:0]),
      .user_axi_awprot        (axi_lite_user.awprot),
      .user_axi_awready       (axi_lite_user.awready),
      .user_axi_awvalid       (axi_lite_user.awvalid),
      .user_axi_bready        (axi_lite_user.bready),
      .user_axi_bresp         (axi_lite_user.bresp),
      .user_axi_bvalid        (axi_lite_user.bvalid),
      .user_axi_rdata         (axi_lite_user.rdata),
      .user_axi_rready        (axi_lite_user.rready),
      .user_axi_rresp         (axi_lite_user.rresp),
      .user_axi_rvalid        (axi_lite_user.rvalid),
      .user_axi_wdata         (axi_lite_user.wdata),
      .user_axi_wready        (axi_lite_user.wready),
      .user_axi_wstrb         (axi_lite_user.wstrb),
      .user_axi_wvalid        (axi_lite_user.wvalid),
      .autoconfig_axi_araddr  (axi_lite_autoconfig.araddr[17:0]),
      .autoconfig_axi_arprot  (axi_lite_autoconfig.arprot),
      .autoconfig_axi_arready (axi_lite_autoconfig.arready),
      .autoconfig_axi_arvalid (axi_lite_autoconfig.arvalid),
      .autoconfig_axi_awaddr  (axi_lite_autoconfig.awaddr[17:0]),
      .autoconfig_axi_awprot  (axi_lite_autoconfig.awprot),
      .autoconfig_axi_awready (axi_lite_autoconfig.awready),
      .autoconfig_axi_awvalid (axi_lite_autoconfig.awvalid),
      .autoconfig_axi_bready  (axi_lite_autoconfig.bready),
      .autoconfig_axi_bresp   (axi_lite_autoconfig.bresp),
      .autoconfig_axi_bvalid  (axi_lite_autoconfig.bvalid),
      .autoconfig_axi_rdata   (axi_lite_autoconfig.rdata),
      .autoconfig_axi_rready  (axi_lite_autoconfig.rready),
      .autoconfig_axi_rresp   (axi_lite_autoconfig.rresp),
      .autoconfig_axi_rvalid  (axi_lite_autoconfig.rvalid),
      .autoconfig_axi_wdata   (axi_lite_autoconfig.wdata),
      .autoconfig_axi_wready  (axi_lite_autoconfig.wready),
      .autoconfig_axi_wstrb   (axi_lite_autoconfig.wstrb),
      .autoconfig_axi_wvalid  (axi_lite_autoconfig.wvalid),
      .satellite_gpio         (satellite_gpio),
      .satellite_uart_rxd     (satellite_uart_rxd),
      .satellite_uart_txd     (satellite_uart_txd)
   );

endmodule
