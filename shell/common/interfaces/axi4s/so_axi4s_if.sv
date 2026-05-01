// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.
//-----------------------------------------------------------------------------
// Title      : AXI4 Stream Interface
//-----------------------------------------------------------------------------
// File       : so_axi4s_if.sv
// Created    : August 23, 2019
// Modified   : August 23, 2022
//-----------------------------------------------------------------------------
// Description: This interface defines the Standard AXI Stream
//              Interface
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

/*  Instantiation Template
    so_axi4s_if #(C_SO_AXI4S_D32) i_so_axi4s_if(clk, ~rst);
*/

/*  Master Interoperability Assignment Template
    // Default Values set in accordance with AXI spec. (ARM IHI 0022F.b A9.3)
    always_comb begin
        <INST>.tstrb  = '1;
        <INST>.tkeep  = '1;
        <INST>.tid    = '0;
        <INST>.tdest  = '0;
        <INST>.tuser  = '0;
    end
*/

interface so_axi4s_if
    import so_axi4s_if_pkg::*;
    #(
        so_axi4s_if_param_t P_WIDTH = C_SO_AXI4S_D8,
        type P_TDATA_TYPE = int
    )(
        input wire aclk,
        input wire aresetn
    );

    // Stream Signals
    logic                      tvalid;
    logic                      tready;
    logic [8*P_WIDTH.DATA-1:0] tdata;
    logic [P_WIDTH.DATA-1:0]   tstrb;
    logic [P_WIDTH.DATA-1:0]   tkeep;
    logic                      tlast;
    logic [P_WIDTH.ID-1:0]     tid;
    logic [P_WIDTH.DEST-1:0]   tdest;
    logic [P_WIDTH.USER-1:0]   tuser;
    P_TDATA_TYPE tdata_typed; // debug

    //========================
    // For debug
    int element_cnt;

    always_ff @ (posedge aclk) begin
        if (~aresetn) begin
            element_cnt <= 0;
        end else begin
            if(tready & tvalid) begin
                element_cnt <= element_cnt + 1;
                if (tlast) begin
                   element_cnt <= 0;
                end
            end
        end
    end

    assign tdata_typed = tdata;

    /* pragma translate_off */
      default clocking cb @(posedge aclk);
        default input #1step;
        input   aresetn;
        input   tvalid;
        input   tready;
        input   tdata;
        input   tstrb;
        input   tkeep;
        input   tdest;
        input   tid;
        input   tuser;
        input   tlast;
        input   element_cnt;
        input   tdata_typed;
      endclocking : cb
    /* pragma translate_on */

    modport master
    (
        /* pragma translate_off */
        clocking cb,
        /* pragma translate_on */

        input  aclk,
        input  aresetn,

        output tvalid,
        input  tready,
        output tdata,
        output tstrb,
        output tkeep,
        output tlast,
        output tid,
        output tdest,
        output tuser
    );

    modport slave
    (
        /* pragma translate_off */
        clocking cb,
        /* pragma translate_on */

        input  aclk,
        input  aresetn,

        input  tvalid,
        output tready,
        input  tdata,
        input  tstrb,
        input  tkeep,
        input  tlast,
        input  tid,
        input  tdest,
        input  tuser
    );

    modport monitor
    (
        /* pragma translate_off */
        clocking cb,
        /* pragma translate_on */

        input  aclk,
        input  aresetn,

        input  tvalid,
        input  tready,
        input  tdata,
        input  tstrb,
        input  tkeep,
        input  tlast,
        input  tid,
        input  tdest,
        input  tuser
    );

    modport rotinom
    (
        /* pragma translate_off */
        clocking cb,
        /* pragma translate_on */

        input  aclk,
        input  aresetn,

        output tvalid,
        output tready,
        output tdata,
        output tstrb,
        output tkeep,
        output tlast,
        output tid,
        output tdest,
        output tuser
    );
endinterface : so_axi4s_if
