// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.
//-----------------------------------------------------------------------------
// Title      : AXI4-Lite Interface
//-----------------------------------------------------------------------------
// File       : so_axi4l_if.sv
// Created    : August 23, 2019
// Modified   : August 23, 2022
//-----------------------------------------------------------------------------
// Description: This interface defines the Standard AXI4-Lite
//              Interface
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

/*  Instantiation Template
    so_axi4l_if #(C_SO_AXI4L_A32_D32) i_so_axi4l_if(clk, ~rst);
*/

/*  Master Interoperability Assignment Template
    // Default Values set in accordance with AXI spec. (ARM IHI 0022F.b A9.3)
    always_comb begin
        <INST>.awqos    = '0;
        <INST>.awregion = '0;
        <INST>.awuser   = '0;
        <INST>.wstrb    = '1;
        <INST>.wuser    = '0;
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

interface so_axi4l_if
    import so_axi4l_if_pkg::*;
    #(
        so_axi4l_if_param_t P_WIDTH = C_SO_AXI4L_A32_D32
    )(
        input wire aclk,
        input wire aresetn
    );

    // Write Address Channel
    logic [P_WIDTH.ID-1:0]      awid;
    logic [P_WIDTH.ADDR-1:0]    awaddr;
    logic [2:0]                 awprot;
    logic [3:0]                 awqos;
    logic [3:0]                 awregion;
    logic [P_WIDTH.AWUSER-1:0]  awuser;
    logic                       awvalid;
    logic                       awready;

    // Write Data Channel
    logic [8*P_WIDTH.DATA-1:0]  wdata;
    logic [P_WIDTH.DATA-1:0]    wstrb;
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


    /* pragma translate_off */
      default clocking cb @(posedge aclk);
        default input #1step;
        input  aresetn;
        input  awid;
        input  awaddr;
        input  awprot;
        input  awqos;
        input  awregion;
        input  awuser;
        input  awvalid;
        input  awready;
        input  wdata;
        input  wstrb;
        input  wuser;
        input  wvalid;
        input  wready;
        input  bid;
        input  bresp;
        input  buser;
        input  bvalid;
        input  bready;
        input  arid;
        input  araddr;
        input  arprot;
        input  arqos;
        input  arregion;
        input  aruser;
        input  arvalid;
        input  arready;
        input  rid;
        input  rdata;
        input  rresp;
        input  rlast;
        input  ruser;
        input  rvalid;
        input  rready;
      endclocking : cb
    /* pragma translate_on */

    modport master
    (
        /* pragma translate_off */
        clocking cb,
        /* pragma translate_on */

        input  aclk,
        input  aresetn,

        output awid,
        output awaddr,
        output awprot,
        output awqos,
        output awregion,
        output awuser,
        output awvalid,
        input  awready,

        output wdata,
        output wstrb,
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
        output arprot,
        output arqos,
        output arregion,
        output aruser,
        output arvalid,
        input  arready,

        input  rid,
        input  rdata,
        input  rresp,
        input  ruser,
        input  rvalid,
        output rready
    );

    modport slave
    (
        /* pragma translate_off */
        clocking cb,
        /* pragma translate_on */

        input  aclk,
        input  aresetn,

        input  awid,
        input  awaddr,
        input  awprot,
        input  awqos,
        input  awregion,
        input  awuser,
        input  awvalid,
        output awready,

        input  wdata,
        input  wstrb,
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
        input  arprot,
        input  arqos,
        input  arregion,
        input  aruser,
        input  arvalid,
        output arready,

        output rid,
        output rdata,
        output rresp,
        output ruser,
        output rvalid,
        input  rready
    );

    modport monitor
    (
        /* pragma translate_off */
        clocking cb,
        /* pragma translate_on */

        input  aclk,
        input  aresetn,
        input  awid,
        input  awaddr,
        input  awprot,
        input  awqos,
        input  awregion,
        input  awuser,
        input  awvalid,
        input  awready,

        input  wdata,
        input  wstrb,
        input  wuser,
        input  wvalid,
        input  wready,

        input  bid,
        input  bresp,
        input  buser,
        input  bvalid,
        input  bready,

        input  arid,
        input  araddr,
        input  arprot,
        input  arqos,
        input  arregion,
        input  aruser,
        input  arvalid,
        input  arready,

        input  rid,
        input  rdata,
        input  rresp,
        input  ruser,
        input  rvalid,
        input  rready
    );
endinterface : so_axi4l_if
