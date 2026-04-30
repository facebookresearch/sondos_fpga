// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

module sondos_shell_u250_host

import so_axi4_if_pkg::*,so_axi4l_if_pkg::*,so_axi4s_if_pkg::*;
(
   sondos_shell_u250_host_if.shell sondos_io,

   output shell_clk,
   output shell_reset,

   so_axi4l_if.master axi_lite_user,
   so_axi4_if.slave axi_full_user
 );

    wire user_lnk_up;
    wire  sys_clk;
    wire  sys_rst_n;

    so_axi4_if #(C_SO_AXI4_A64_D512) axi_full_flash (.aclk(axi_aclk), .aresetn(axi_aresetn));
    so_axi4_if #(C_SO_AXI4_A64_D512) axi_full_shell (.aclk(axi_aclk), .aresetn(axi_aresetn));
    so_axi4_if #(C_SO_AXI4_A64_D512) axi_full_dummy (.aclk(axi_aclk), .aresetn(axi_aresetn));
    so_axi4_if #(C_SO_AXI4_A64_D512) axi_full_to_host (.aclk(axi_aclk), .aresetn(axi_aresetn));

    so_axi4l_if #(C_SO_AXI4L_A32_D32) axi_lite_mmio_registers (.aclk(axi_aclk), .aresetn(axi_aresetn));
    so_axi4l_if #(C_SO_AXI4L_A32_D32) axi_lite_shell (.aclk(axi_aclk), .aresetn(axi_aresetn));
    so_axi4l_if #(C_SO_AXI4L_A32_D32) axi_lite_flash (.aclk(axi_aclk), .aresetn(axi_aresetn));
    so_axi4l_if #(C_SO_AXI4L_A32_D32) axi_lite_leaves [2:0] (.aclk(axi_aclk), .aresetn(axi_aresetn));
    logic [2:0][1:0][63:0] register_address_map;


logic [28:0] user_clk_heartbeat;

assign shell_clk = axi_aclk;
assign shell_reset = ~axi_aresetn;

assign sys_rst_n = sondos_io.pcie_rst_n;


assign register_address_map[0][0]=64'h0000_0000_0000_0000; //user
assign register_address_map[0][1]=64'h0000_0000_00EF_FFFF;

assign register_address_map[1][0]=64'h0000_0000_00F0_0000; // shell common
assign register_address_map[1][1]=64'h0000_0000_00F7_FFFF;

assign register_address_map[2][0]=64'h0000_0000_00FF_0000; // shell Flash
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


sondos_axi4l_crossbar
#(.P_NUM_LEAFS(3)
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

sondos_shell_alveo_flash_top #(.DEVICE_ID("ALV_U250")) u250_flash_programmer_inst
(
   .clk(axi_aclk),
   .reset(~axi_aresetn),
   .done_beat(user_clk_heartbeat[25]),
   .axi_full_flash(axi_full_flash),
   .axi_lite_flash(axi_lite_flash)
);

sondos_shell_u250_host_csr shell_csr_inst (
   .clk(axi_aclk),
   .reset(~axi_aresetn),
   .axi_lite_user(axi_lite_shell)
);


always @(posedge axi_aclk) begin
   if(~sys_rst_n) begin
      user_clk_heartbeat <= '0;
   end else begin
      user_clk_heartbeat <= user_clk_heartbeat + 1'b1;
   end
end


endmodule
