// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

module sondos_qdma_wrapper
import so_axi4_if_pkg::*,so_axi4l_if_pkg::*,so_axi4s_if_pkg::*;
(
    input sys_clk_p,
    input sys_clk_n,
    input sys_rst_n,

    output user_clk_250,
    output user_reset_n,
    output user_lnk_up,

    output [15:0] pci_exp_txp,
    output [15:0] pci_exp_txn,
    input  [15:0] pci_exp_rxp,
    input  [15:0] pci_exp_rxn,

    so_axi4_if.slave axi_full_c2h,
    so_axi4l_if.master axi_lite_mmio_registers
    );


logic sys_clk;
logic sys_clk_gt;

`ifdef SONDOS_SIM
    sondos_qdma_harness harness();
`else

IBUFDS_GTE4 # (.REFCLK_HROW_CK_SEL(2'b00)) refclk_ibuf (.O(sys_clk_gt), .ODIV2(sys_clk), .I(sys_clk_p), .CEB(1'b0), .IB(sys_clk_n));

    qdma_0 qdma_0_i
     (
      .sys_rst_n       ( sys_rst_n ),

      .sys_clk         ( sys_clk ),
      .sys_clk_gt      ( sys_clk_gt),
      //---------------------------------------------------------------------------------------//
      //  PCI Express (pci_exp) Interface                                                      //
      //---------------------------------------------------------------------------------------//
      // Tx
      .pci_exp_txn,
      .pci_exp_txp,

      // R
      .pci_exp_rxn,
      .pci_exp_rxp,

      .m_axi_awready(1'b0),
      .m_axi_wready(1'b0),
      .m_axi_bid('0),
      .m_axi_bresp('0),
      .m_axi_bvalid(1'b0),
      .m_axi_arready(1'b0),
      .m_axi_rid('0),
      .m_axi_rdata('0),
      .m_axi_rresp('0),
      .m_axi_rlast('0),
      .m_axi_rvalid(1'b0),
      .m_axi_awid(),
      .m_axi_awaddr(),
      .m_axi_awuser(),
      .m_axi_awlen(),
      .m_axi_awsize(),
      .m_axi_awburst(),
      .m_axi_awprot(),
      .m_axi_awvalid(),
      .m_axi_awlock(),
      .m_axi_awcache(),
      .m_axi_wdata(),
      .m_axi_wuser(),
      .m_axi_wstrb(),
      .m_axi_wlast(),
      .m_axi_wvalid(),
      .m_axi_bready(),
      .m_axi_arid(),
      .m_axi_araddr(),
      .m_axi_aruser(),
      .m_axi_arlen(),
      .m_axi_arsize(),
      .m_axi_arburst(),
      .m_axi_arprot(),
      .m_axi_arvalid(),
      .m_axi_arlock(),
      .m_axi_arcache(),
      .m_axi_rready(),

      //////////////////////////

      .s_axib_awid(axi_full_c2h.awid),
      .s_axib_awaddr(axi_full_c2h.awaddr),
      .s_axib_awregion(axi_full_c2h.awregion),
      .s_axib_awlen(axi_full_c2h.awlen),
      .s_axib_awsize(axi_full_c2h.awsize),
      .s_axib_awburst(axi_full_c2h.awburst),
      .s_axib_awvalid(axi_full_c2h.awvalid),
      .s_axib_wdata(axi_full_c2h.wdata),
      .s_axib_wstrb(axi_full_c2h.wstrb),
      .s_axib_wlast(axi_full_c2h.wlast),
      .s_axib_wvalid(axi_full_c2h.wvalid),
      .s_axib_wuser('0),
      .s_axib_ruser(),
      .s_axib_bready(axi_full_c2h.bready),
      .s_axib_arid(axi_full_c2h.arid),
      .s_axib_araddr(axi_full_c2h.araddr),
      .s_axib_aruser('0),
      .s_axib_awuser('0),
      .s_axib_arregion(axi_full_c2h.arregion),
      .s_axib_arlen(axi_full_c2h.arlen),
      .s_axib_arsize(axi_full_c2h.arsize),
      .s_axib_arburst(axi_full_c2h.arburst),
      .s_axib_arvalid(axi_full_c2h.arvalid),
      .s_axib_rready(axi_full_c2h.rready),
      .s_axib_awready(axi_full_c2h.awready),
      .s_axib_wready(axi_full_c2h.wready),
      .s_axib_bid(axi_full_c2h.bid),
      .s_axib_bresp(axi_full_c2h.bresp),
      .s_axib_bvalid(axi_full_c2h.bvalid),
      .s_axib_arready(axi_full_c2h.arready),
      .s_axib_rid(axi_full_c2h.rid),
      .s_axib_rdata(axi_full_c2h.rdata),
      .s_axib_rresp(axi_full_c2h.rresp),
      .s_axib_rlast(axi_full_c2h.rlast),
      .s_axib_rvalid(axi_full_c2h.rvalid),


      // LITE interface
      //-- AXI Master Write Address Channel
      .m_axil_awaddr    (axi_lite_mmio_registers.awaddr),
      .m_axil_awprot    (axi_lite_mmio_registers.awprot),
      .m_axil_awvalid   (axi_lite_mmio_registers.awvalid),
      .m_axil_awready   (axi_lite_mmio_registers.awready),
      //-- AXI Master Write Data Channel
      .m_axil_wdata     (axi_lite_mmio_registers.wdata),
      .m_axil_wstrb     (axi_lite_mmio_registers.wstrb),
      .m_axil_wvalid    (axi_lite_mmio_registers.wvalid),
      .m_axil_wready    (axi_lite_mmio_registers.wready),
      //-- AXI Master Write Response Channel
      .m_axil_bvalid    (axi_lite_mmio_registers.bvalid),
      .m_axil_bresp     (axi_lite_mmio_registers.bresp),
      .m_axil_bready    (axi_lite_mmio_registers.bready),
      //-- AXI Master Read Address Channel
      .m_axil_araddr    (axi_lite_mmio_registers.araddr),
      .m_axil_arprot    (axi_lite_mmio_registers.arprot),
      .m_axil_arvalid   (axi_lite_mmio_registers.arvalid),
      .m_axil_arready   (axi_lite_mmio_registers.arready),
      .m_axil_rdata     (axi_lite_mmio_registers.rdata),
      //-- AXI Master Read Data Channel
      .m_axil_rresp     (axi_lite_mmio_registers.rresp),
      .m_axil_rvalid    (axi_lite_mmio_registers.rvalid),
      .m_axil_rready    (axi_lite_mmio_registers.rready),


      .s_axil_csr_awaddr('0),
      .s_axil_csr_awprot('0),
      .s_axil_csr_awvalid('0),
      .s_axil_csr_awready(),
      .s_axil_csr_wdata('0),
      .s_axil_csr_wstrb('0),
      .s_axil_csr_wvalid('0),
      .s_axil_csr_wready(),
      .s_axil_csr_bvalid(),
      .s_axil_csr_bresp(),
      .s_axil_csr_bready(1'b1),
      .s_axil_csr_araddr('0),
      .s_axil_csr_arprot('0),
      .s_axil_csr_arvalid('0),
      .s_axil_csr_arready(),
      .s_axil_csr_rdata(),
      .s_axil_csr_rresp(),
      .s_axil_csr_rvalid(),
      .s_axil_csr_rready(1'b1),


      //-- AXI Global
      .axi_aclk        (user_clk_250),
      .axi_aresetn     (user_reset_n ),
      .soft_reset_n    (1'b1 ),
      .phy_ready       (),

      .tm_dsc_sts_vld       (),
      .tm_dsc_sts_qen       (),
      .tm_dsc_sts_byp       (),
      .tm_dsc_sts_dir       (),
      .tm_dsc_sts_mm        (),
      .tm_dsc_sts_error     (),
      .tm_dsc_sts_qid       (),
      .tm_dsc_sts_avl       (),
      .tm_dsc_sts_qinv      (),
      .tm_dsc_sts_irq_arm   (),
      .tm_dsc_sts_rdy       (1'b1),

      .st_rx_msg_rdy        (1'b1),

      .dsc_crdt_in_vld      ('0),
      .dsc_crdt_in_rdy      (),
      .dsc_crdt_in_dir      ('0),
      .dsc_crdt_in_fence    ('0),
      .dsc_crdt_in_qid      ('0),
      .dsc_crdt_in_crdt     ('0),

      .qsts_out_op      (),
      .qsts_out_data    (),
      .qsts_out_port_id (),
      .qsts_out_qid     (),
      .qsts_out_vld     (),
      .qsts_out_rdy     (1'b1),

      .usr_irq_in_vld   ('0),
      .usr_irq_in_vec   ('0),
      .usr_irq_in_fnc   ('0),
      .usr_irq_out_ack  (),
      .usr_irq_out_fail (),
      .user_lnk_up      (user_lnk_up)
    );
`endif
endmodule
