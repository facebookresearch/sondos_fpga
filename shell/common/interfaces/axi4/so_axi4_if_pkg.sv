// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.
//-----------------------------------------------------------------------------
// Title      : AXI4 Interface Package
//-----------------------------------------------------------------------------
// File       : so_axi4_if_pkg.sv
// Created    : August 23, 2019
// Updated    : April 13, 2021
//-----------------------------------------------------------------------------
// Description: This package contains the parameter types and standard
//              AXI4 interface configurations.
//
// note: The AXI specification is ambiguous about supporting asymetric read and
//       write channels. This implementation intentionally supports only
//       symetric read and write channels for simplicity.
//
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

package so_axi4_if_pkg;

    // unless otherwise specified each width field is specified in bits
    typedef struct packed {
        int ID;
        int ADDR;
        int DATA;   // width in bytes
        int AWUSER;
        int WUSER;
        int BUSER;
        int ARUSER;
        int RUSER;
        int HAS_AWUSER;
        int HAS_WUSER;
        int HAS_BUSER;
        int HAS_ARUSER;
        int HAS_RUSER;
    } so_axi4_if_param_t;

    // standard configurations

    localparam so_axi4_if_param_t C_SO_AXI4_A32_D32 = '{
        ID         : 4,
        ADDR       : 32,
        DATA       : 4,
        AWUSER     : 1,
        WUSER      : 1,
        BUSER      : 1,
        ARUSER     : 1,
        RUSER      : 1,
        HAS_AWUSER : 0,
        HAS_WUSER  : 0,
        HAS_BUSER  : 0,
        HAS_ARUSER : 0,
        HAS_RUSER  : 0
    };

    localparam so_axi4_if_param_t C_SO_AXI4_A32_D64 = '{
        ID         : 4,
        ADDR       : 32,
        DATA       : 8,
        AWUSER     : 1,
        WUSER      : 1,
        BUSER      : 1,
        ARUSER     : 1,
        RUSER      : 1,
        HAS_AWUSER : 0,
        HAS_WUSER  : 0,
        HAS_BUSER  : 0,
        HAS_ARUSER : 0,
        HAS_RUSER  : 0
    };

    localparam so_axi4_if_param_t C_SO_AXI4_A32_D128 = '{
        ID         : 4,
        ADDR       : 32,
        DATA       : 16,
        AWUSER     : 1,
        WUSER      : 1,
        BUSER      : 1,
        ARUSER     : 1,
        RUSER      : 1,
        HAS_AWUSER : 0,
        HAS_WUSER  : 0,
        HAS_BUSER  : 0,
        HAS_ARUSER : 0,
        HAS_RUSER  : 0
    };

    localparam so_axi4_if_param_t C_SO_AXI4_A32_D256 = '{
        ID         : 4,
        ADDR       : 32,
        DATA       : 32,
        AWUSER     : 1,
        WUSER      : 1,
        BUSER      : 1,
        ARUSER     : 1,
        RUSER      : 1,
        HAS_AWUSER : 0,
        HAS_WUSER  : 0,
        HAS_BUSER  : 0,
        HAS_ARUSER : 0,
        HAS_RUSER  : 0
    };

    localparam so_axi4_if_param_t C_SO_AXI4_A32_D512 = '{
        ID         : 4,
        ADDR       : 32,
        DATA       : 64,
        AWUSER     : 1,
        WUSER      : 1,
        BUSER      : 1,
        ARUSER     : 1,
        RUSER      : 1,
        HAS_AWUSER : 0,
        HAS_WUSER  : 0,
        HAS_BUSER  : 0,
        HAS_ARUSER : 0,
        HAS_RUSER  : 0
    };

    localparam so_axi4_if_param_t C_SO_AXI4_A31_D512 = '{
        ID         : 4,
        ADDR       : 31,
        DATA       : 64,
        AWUSER     : 1,
        WUSER      : 1,
        BUSER      : 1,
        ARUSER     : 1,
        RUSER      : 1,
        HAS_AWUSER : 0,
        HAS_WUSER  : 0,
        HAS_BUSER  : 0,
        HAS_ARUSER : 0,
        HAS_RUSER  : 0
    };

    localparam so_axi4_if_param_t C_SO_AXI4_A30_D32 = '{
        ID         : 4,
        ADDR       : 30,
        DATA       : 4,
        AWUSER     : 1,
        WUSER      : 1,
        BUSER      : 1,
        ARUSER     : 1,
        RUSER      : 1,
        HAS_AWUSER : 0,
        HAS_WUSER  : 0,
        HAS_BUSER  : 0,
        HAS_ARUSER : 0,
        HAS_RUSER  : 0
    };

    localparam so_axi4_if_param_t C_SO_AXI4_A30_D512 = '{
        ID         : 4,
        ADDR       : 30,
        DATA       : 64,
        AWUSER     : 48,
        WUSER      : 1,
        BUSER      : 1,
        ARUSER     : 48,
        RUSER      : 1,
        HAS_AWUSER : 1,
        HAS_WUSER  : 0,
        HAS_BUSER  : 0,
        HAS_ARUSER : 1,
        HAS_RUSER  : 0
    };

    localparam so_axi4_if_param_t C_SO_AXI4_A44_D128 = '{
        ID         : 6,
        ADDR       : 44,
        DATA       : 16,
        AWUSER     : 1,
        WUSER      : 1,
        BUSER      : 1,
        ARUSER     : 1,
        RUSER      : 1,
        HAS_AWUSER : 0,
        HAS_WUSER  : 0,
        HAS_BUSER  : 0,
        HAS_ARUSER : 0,
        HAS_RUSER  : 0
    };

    localparam so_axi4_if_param_t C_SO_AXI4_A64_D512 = '{
        ID         : 8,
        ADDR       : 64,
        DATA       : 64,
        AWUSER     : 8,
        WUSER      : 1,
        BUSER      : 8,
        ARUSER     : 8,
        RUSER      : 8,
        HAS_AWUSER : 1,
        HAS_WUSER  : 0,
        HAS_BUSER  : 1,
        HAS_ARUSER : 1,
        HAS_RUSER  : 1
    };

    // helper parameters for decode

    // BURST
    localparam logic [1:0] C_SO_AXI4_BURST_FIXED = 2'b00;
    localparam logic [1:0] C_SO_AXI4_BURST_INCR  = 2'b01;
    localparam logic [1:0] C_SO_AXI4_BURST_WRAP  = 2'b10;

    // RESP
    localparam logic [1:0] C_SO_AXI4_RESP_OKAY   = 2'b00;
    localparam logic [1:0] C_SO_AXI4_RESP_EXOKAY = 2'b01;
    localparam logic [1:0] C_SO_AXI4_RESP_SLVERR = 2'b10;
    localparam logic [1:0] C_SO_AXI4_RESP_DECERR = 2'b11;

    // LOC
    localparam logic C_SO_AXI4_LOCK_NORMAL    = 1'b0;
    localparam logic C_SO_AXI4_LOCK_EXCLUSIVE = 1'b1;

    //======================================
    // Macros
    `define CONNECT_SO_AXI4_IF_RSP(A, B)\
        assign B.awready   = A.awready;\
        assign B.wready    = A.wready;\
        assign B.bid       = A.bid;\
        assign B.bresp     = A.bresp;\
        assign B.buser     = A.buser;\
        assign B.bvalid    = A.bvalid;\
        assign B.arready   = A.arready;\
        assign B.rid       = A.rid;\
        assign B.rdata     = A.rdata;\
        assign B.rresp     = A.rresp;\
        assign B.rlast     = A.rlast;\
        assign B.ruser     = A.ruser;\
        assign B.rvalid    = A.rvalid;

    `define CONNECT_SO_AXI4_IF_REQ(A, B)\
        assign B.awid      = A.awid;\
        assign B.awaddr    = A.awaddr;\
        assign B.awlen     = A.awlen;\
        assign B.awsize    = A.awsize;\
        assign B.awburst   = A.awburst;\
        assign B.awlock    = A.awlock;\
        assign B.awcache   = A.awcache;\
        assign B.awprot    = A.awprot;\
        assign B.awqos     = A.awqos;\
        assign B.awregion  = A.awregion;\
        assign B.awuser    = A.awuser;\
        assign B.awvalid   = A.awvalid;\
        assign B.wdata     = A.wdata;\
        assign B.wstrb     = A.wstrb;\
        assign B.wlast     = A.wlast;\
        assign B.wuser     = A.wuser;\
        assign B.wvalid    = A.wvalid;\
        assign B.bready    = A.bready;\
        assign B.arid      = A.arid;\
        assign B.araddr    = A.araddr;\
        assign B.arlen     = A.arlen;\
        assign B.arsize    = A.arsize;\
        assign B.arburst   = A.arburst;\
        assign B.arlock    = A.arlock;\
        assign B.arcache   = A.arcache;\
        assign B.arprot    = A.arprot;\
        assign B.arqos     = A.arqos;\
        assign B.arregion  = A.arregion;\
        assign B.aruser    = A.aruser;\
        assign B.arvalid   = A.arvalid;\
        assign B.rready    = A.rready;

    `define CONNECT_SO_AXI4_IF(A, B)\
        `CONNECT_SO_AXI4_IF_RSP(A, B)\
        `CONNECT_SO_AXI4_IF_REQ(B, A)

    `define INIT_UNUSED_SO_AXI4_IF_RSP(A)\
        assign A.bresp    = C_SO_AXI4_RESP_OKAY;\
        assign A.buser    = '0;\
        assign A.rresp    = C_SO_AXI4_RESP_OKAY;\
        assign A.ruser    = '0;

    `define INIT_UNUSED_SO_AXI4_IF_REQ(A)\
        assign A.awlen    = '0;\
        assign A.awsize   = $clog2($size(A.wdata)/8);\
        assign A.awburst  = C_SO_AXI4_BURST_INCR;\
        assign A.awlock   = C_SO_AXI4_LOCK_NORMAL;\
        assign A.awcache  = '0;\
        assign A.awqos    = '0;\
        assign A.awregion = '0;\
        assign A.awuser   = '0;\
        assign A.wstrb    = '1;\
        assign A.wuser    = '0;\
        assign A.arlen    = '0;\
        assign A.arsize   = $clog2($size(A.rdata)/8);\
        assign A.arburst  = C_SO_AXI4_BURST_INCR;\
        assign A.arlock   = C_SO_AXI4_LOCK_NORMAL;\
        assign A.arcache  = '0;\
        assign A.arqos    = '0;\
        assign A.arregion = '0;\
        assign A.aruser   = '0;

endpackage : so_axi4_if_pkg
