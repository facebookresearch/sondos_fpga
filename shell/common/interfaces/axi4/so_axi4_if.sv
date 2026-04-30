// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.
//----------------------------------------------------------------------------
// Title      : AXI4 Interface
//-----------------------------------------------------------------------------
// File       : so_axi4_if.sv
// Created    : August 23, 2019
//-----------------------------------------------------------------------------
// Description: This interface defines the Standard AXI4 Interface
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

/*  Instantiation Template
    so_axi4_if #(C_SO_AXI4_A32_D32) i_so_axi4_if(clk, ~rst);
*/

/*  Master Interoperability Assignment Template
    // Default Values set in accordance with AXI spec. (ARM IHI 0022F.b A9.3)
    always_comb begin
        <INST>.awlen    = '0;
        <INST>.awsize   = $clog2($size(<INST>.wdata)/8);
        <INST>.awburst  = C_SO_AXI4_BURST_INCR;
        <INST>.awlock   = C_SO_AXI4_LOCK_NORMAL;
        <INST>.awcache  = '0;
        <INST>.awqos    = '0;
        <INST>.awregion = '0;
        <INST>.awuser   = '0;
        <INST>.wstrb    = '1;
        <INST>.wuser    = '0;
        <INST>.arlen    = '0;
        <INST>.arsize   = $clog2($size(<INST>.rdata)/8);
        <INST>.arburst  = C_SO_AXI4_BURST_INCR;
        <INST>.arlock   = C_SO_AXI4_LOCK_NORMAL;
        <INST>.arcache  = '0;
        <INST>.arqos    = '0;
        <INST>.arregion = '0;
        <INST>.aruser   = '0;
    end
*/

/*  Slave Interoperability Assignment Template
    // Default Values set in accordance with AXI spec. (ARM IHI 0022F.b A9.3)
    always_comb begin
        <INST>.bresp    = C_SO_AXI4_RESP_OKAY;
        <INST>.buser    = '0;
        <INST>.rresp    = C_SO_AXI4_RESP_OKAY;
        <INST>.ruser    = '0;
    end
*/

interface so_axi4_if
    import so_axi4_if_pkg::*;
    #(
        so_axi4_if_param_t P_WIDTH = C_SO_AXI4_A32_D32
    )(
        input wire aclk,
        input wire aresetn
    );

    // Write Address Channel
    logic [P_WIDTH.ID-1:0]      awid;
    logic [P_WIDTH.ADDR-1:0]      awaddr;
    logic [7:0]                 awlen;
    logic [2:0]                 awsize;
    logic [1:0]                 awburst;
    logic                       awlock;
    logic [3:0]                 awcache;
    logic [2:0]                 awprot;
    logic [3:0]                 awqos;
    logic [3:0]                 awregion;
    logic [P_WIDTH.AWUSER-1:0]  awuser;
    logic                       awvalid;
    logic                       awready;

    // Write Data Channel
    logic [P_WIDTH.ID-1:0]      wid;
    logic [8*P_WIDTH.DATA-1:0]  wdata;
    logic [P_WIDTH.DATA-1:0]    wstrb;
    logic                       wlast;
    logic [P_WIDTH.WUSER-1:0]   wuser;
    logic                       wvalid;
    logic                       wready;

    // Write Response Channel
    logic [P_WIDTH.ID-1:0]      bid;
    logic [1:0]                 bresp;
    logic [P_WIDTH.BUSER-1:0]   buser;
    logic                       bvalid;
    logic                       bready;

    // Read Address Channel
    logic [P_WIDTH.ID-1:0]      arid;
    logic [P_WIDTH.ADDR-1:0]    araddr;
    logic [7:0]                 arlen;
    logic [2:0]                 arsize;
    logic [1:0]                 arburst;
    logic                       arlock;
    logic [3:0]                 arcache;
    logic [2:0]                 arprot;
    logic [3:0]                 arqos;
    logic [3:0]                 arregion;
    logic [P_WIDTH.ARUSER-1:0]  aruser;
    logic                       arvalid;
    logic                       arready;

    // Read Data Channel
    logic [P_WIDTH.ID-1:0]      rid;
    logic [8*P_WIDTH.DATA-1:0]  rdata;
    logic [1:0]                 rresp;
    logic                       rlast;
    logic [P_WIDTH.RUSER-1:0]   ruser;
    logic                       rvalid;
    logic                       rready;

    modport master
    (
        input  aclk,
        input  aresetn,

        output awid,
        output awaddr,
        output awlen,
        output awsize,
        output awburst,
        output awlock,
        output awcache,
        output awprot,
        output awqos,
        output awregion,
        output awuser,
        output awvalid,
        input  awready,

        output wid,
        output wdata,
        output wstrb,
        output wlast,
        output wuser,
        output wvalid,
        input  wready,

        input  bid,
        input  bresp,
        input  buser,
        input  bvalid,
        output bready,

        output arid,
        output araddr,
        output arlen,
        output arsize,
        output arburst,
        output arlock,
        output arcache,
        output arprot,
        output arqos,
        output arregion,
        output aruser,
        output arvalid,
        input  arready,

        input  rid,
        input  rdata,
        input  rresp,
        input  rlast,
        input  ruser,
        input  rvalid,
        output rready
    );

    modport master_write
    (
        input  aclk,
        input  aresetn,

        output awid,
        output awaddr,
        output awlen,
        output awsize,
        output awburst,
        output awlock,
        output awcache,
        output awprot,
        output awqos,
        output awregion,
        output awuser,
        output awvalid,
        input  awready,

        output wid,
        output wdata,
        output wstrb,
        output wlast,
        output wuser,
        output wvalid,
        input  wready,

        input  bid,
        input  bresp,
        input  buser,
        input  bvalid,
        output bready
    );

    modport master_read
    (
        input  aclk,
        input  aresetn,

        output arid,
        output araddr,
        output arlen,
        output arsize,
        output arburst,
        output arlock,
        output arcache,
        output arprot,
        output arqos,
        output arregion,
        output aruser,
        output arvalid,
        input  arready,

        input  rid,
        input  rdata,
        input  rresp,
        input  rlast,
        input  ruser,
        input  rvalid,
        output rready
    );

    modport slave_write
    (
        input  aclk,
        input  aresetn,

        input  awid,
        input  awaddr,
        input  awlen,
        input  awsize,
        input  awburst,
        input  awlock,
        input  awcache,
        input  awprot,
        input  awqos,
        input  awregion,
        input  awuser,
        input  awvalid,
        output awready,

        input  wid,
        input  wdata,
        input  wstrb,
        input  wlast,
        input  wuser,
        input  wvalid,
        output wready,

        output bid,
        output bresp,
        output buser,
        output bvalid,
        input  bready
    );

    modport slave_read
    (
        input  aclk,
        input  aresetn,

        input  arid,
        input  araddr,
        input  arlen,
        input  arsize,
        input  arburst,
        input  arlock,
        input  arcache,
        input  arprot,
        input  arqos,
        input  arregion,
        input  aruser,
        input  arvalid,
        output arready,

        output rid,
        output rdata,
        output rresp,
        output rlast,
        output ruser,
        output rvalid,
        input  rready
    );

    modport slave
    (
        input  aclk,
        input  aresetn,

        input  awid,
        input  awaddr,
        input  awlen,
        input  awsize,
        input  awburst,
        input  awlock,
        input  awcache,
        input  awprot,
        input  awqos,
        input  awregion,
        input  awuser,
        input  awvalid,
        output awready,

        input  wid,
        input  wdata,
        input  wstrb,
        input  wlast,
        input  wuser,
        input  wvalid,
        output wready,

        output bid,
        output bresp,
        output buser,
        output bvalid,
        input  bready,

        input  arid,
        input  araddr,
        input  arlen,
        input  arsize,
        input  arburst,
        input  arlock,
        input  arcache,
        input  arprot,
        input  arqos,
        input  arregion,
        input  aruser,
        input  arvalid,
        output arready,

        output rid,
        output rdata,
        output rresp,
        output rlast,
        output ruser,
        output rvalid,
        input  rready
    );

    modport monitor
    (
        input aclk,
        input aresetn,
        input awid,
        input awaddr,
        input awlen,
        input awsize,
        input awburst,
        input awlock,
        input awcache,
        input awprot,
        input awqos,
        input awregion,
        input awuser,
        input awvalid,
        input awready,

        input wid,
        input wdata,
        input wstrb,
        input wlast,
        input wuser,
        input wvalid,
        input wready,

        input bid,
        input bresp,
        input buser,
        input bvalid,
        input bready,

        input arid,
        input araddr,
        input arlen,
        input arsize,
        input arburst,
        input arlock,
        input arcache,
        input arprot,
        input arqos,
        input arregion,
        input aruser,
        input arvalid,
        input arready,

        input rid,
        input rdata,
        input rresp,
        input rlast,
        input ruser,
        input rvalid,
        input rready
    );

endinterface : so_axi4_if
