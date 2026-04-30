// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.
//-----------------------------------------------------------------------------
// Title      : AXI4 Stream Interface Package
//-----------------------------------------------------------------------------
// File       : so_axi4l_if_pkg.sv
// Created    : August 23, 2019
// Updated    : April 13, 2021
//-----------------------------------------------------------------------------
// Description: This package contains the parameter types and standard
//              AXI4 Stream interface configurations.
//
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

package so_axi4s_if_pkg;

    // unless otherwise specified each width field is specified in bits
    typedef struct packed
    {
        int ID;
        int DATA;   // width in bytes
        int DEST;
        int USER;
        int HAS_ID;
        int HAS_DEST;
        int HAS_USER;
    } so_axi4s_if_param_t;

    localparam so_axi4s_if_param_t C_SO_AXI4S_D8 = '{
        ID       : 1,
        DATA     : 1,
        DEST     : 1,
        USER     : 1,
        HAS_ID   : 0,
        HAS_DEST : 0,
        HAS_USER : 0
    };

    localparam so_axi4s_if_param_t C_SO_AXI4S_D16 = '{
        ID       : 1,
        DATA     : 2,
        DEST     : 1,
        USER     : 1,
        HAS_ID   : 0,
        HAS_DEST : 0,
        HAS_USER : 0
    };

    localparam so_axi4s_if_param_t C_SO_AXI4S_D32 = '{
        ID       : 1,
        DATA     : 4,
        DEST     : 1,
        USER     : 1,
        HAS_ID   : 0,
        HAS_DEST : 0,
        HAS_USER : 0
    };

    localparam so_axi4s_if_param_t C_SO_AXI4S_D64 = '{
        ID       : 1,
        DATA     : 8,
        DEST     : 1,
        USER     : 1,
        HAS_ID   : 0,
        HAS_DEST : 0,
        HAS_USER : 0
    };

    localparam so_axi4s_if_param_t C_SO_AXI4S_D128 = '{
        ID       : 1,
        DATA     : 16,
        DEST     : 1,
        USER     : 1,
        HAS_ID   : 0,
        HAS_DEST : 0,
        HAS_USER : 0
    };

    localparam so_axi4s_if_param_t C_SO_AXI4S_D256 = '{
        ID       : 1,
        DATA     : 32,
        DEST     : 1,
        USER     : 1,
        HAS_ID   : 0,
        HAS_DEST : 0,
        HAS_USER : 0
    };

    localparam so_axi4s_if_param_t C_SO_AXI4S_D512 = '{
        ID       : 1,
        DATA     : 64,
        DEST     : 1,
        USER     : 1,
        HAS_ID   : 0,
        HAS_DEST : 0,
        HAS_USER : 0
    };

    localparam so_axi4s_if_param_t C_SO_AXI4S_D24 = '{
        ID       : 1,
        DATA     : 3,
        DEST     : 1,
        USER     : 1,
        HAS_ID   : 0,
        HAS_DEST : 0,
        HAS_USER : 0
    };

    localparam so_axi4s_if_param_t C_SO_AXI4S_D40 = '{
        ID       : 1,
        DATA     : 5,
        DEST     : 1,
        USER     : 1,
        HAS_ID   : 0,
        HAS_DEST : 0,
        HAS_USER : 0
    };

    localparam so_axi4s_if_param_t C_SO_AXI4S_D72 = '{
        ID       : 1,
        DATA     : 9,
        DEST     : 1,
        USER     : 1,
        HAS_ID   : 0,
        HAS_DEST : 0,
        HAS_USER : 0
    };

    localparam so_axi4s_if_param_t C_SO_AXI4S_D96 = '{
        ID       : 1,
        DATA     : 12,
        DEST     : 1,
        USER     : 1,
        HAS_ID   : 0,
        HAS_DEST : 0,
        HAS_USER : 0
    };

    localparam so_axi4s_if_param_t C_SO_AXI4S_D192 = '{
        ID       : 1,
        DATA     : 24,
        DEST     : 1,
        USER     : 1,
        HAS_ID   : 0,
        HAS_DEST : 0,
        HAS_USER : 0
    };


    //====================================
    // Params with 1b user.
    localparam so_axi4s_if_param_t C_SO_AXI4S_D8_U1 = '{
        ID       : 1,
        DATA     : 1,
        DEST     : 1,
        USER     : 1,
        HAS_ID   : 0,
        HAS_DEST : 0,
        HAS_USER : 1
    };

    localparam so_axi4s_if_param_t C_SO_AXI4S_D16_U1 = '{
        ID       : 1,
        DATA     : 2,
        DEST     : 1,
        USER     : 1,
        HAS_ID   : 0,
        HAS_DEST : 0,
        HAS_USER : 1
    };

    localparam so_axi4s_if_param_t C_SO_AXI4S_D24_U1 = '{
        ID       : 1,
        DATA     : 3,
        DEST     : 1,
        USER     : 1,
        HAS_ID   : 0,
        HAS_DEST : 0,
        HAS_USER : 1
    };

    localparam so_axi4s_if_param_t C_SO_AXI4S_D32_U1 = '{
        ID       : 1,
        DATA     : 4,
        DEST     : 1,
        USER     : 1,
        HAS_ID   : 0,
        HAS_DEST : 0,
        HAS_USER : 1
    };

    localparam so_axi4s_if_param_t C_SO_AXI4S_D48_U1 = '{
        ID       : 1,
        DATA     : 6,
        DEST     : 1,
        USER     : 1,
        HAS_ID   : 0,
        HAS_DEST : 0,
        HAS_USER : 1
    };

    localparam so_axi4s_if_param_t C_SO_AXI4S_D64_U1 = '{
        ID       : 1,
        DATA     : 8,
        DEST     : 1,
        USER     : 1,
        HAS_ID   : 0,
        HAS_DEST : 0,
        HAS_USER : 1
    };

    localparam so_axi4s_if_param_t C_SO_AXI4S_D72_U1 = '{
        ID       : 1,
        DATA     : 9,
        DEST     : 1,
        USER     : 1,
        HAS_ID   : 0,
        HAS_DEST : 0,
        HAS_USER : 1
    };

    localparam so_axi4s_if_param_t C_SO_AXI4S_D128_U1 = '{
        ID       : 1,
        DATA     : 16,
        DEST     : 1,
        USER     : 1,
        HAS_ID   : 0,
        HAS_DEST : 0,
        HAS_USER : 1
    };

    localparam so_axi4s_if_param_t C_SO_AXI4S_D256_U1 = '{
        ID       : 1,
        DATA     : 32,
        DEST     : 1,
        USER     : 1,
        HAS_ID   : 0,
        HAS_DEST : 0,
        HAS_USER : 1
    };

   localparam so_axi4s_if_param_t SO_AXI4S_SIZE_ARRAY[7] = {C_SO_AXI4S_D8,  C_SO_AXI4S_D16,
                                                          C_SO_AXI4S_D32, C_SO_AXI4S_D64,
                                                          C_SO_AXI4S_D128,C_SO_AXI4S_D256,
                                                          C_SO_AXI4S_D512};


   //======================================
   // Macros
   `define CONNECT_SO_AXI4S_IF_RSP(so_axi4s_if_master, so_axi4s_if_slave)\
      assign so_axi4s_if_slave.tready = so_axi4s_if_master.tready;

   `define CONNECT_SO_AXI4S_IF_REQ(so_axi4s_if_master, so_axi4s_if_slave)\
      assign so_axi4s_if_slave.tvalid = so_axi4s_if_master.tvalid;\
      assign so_axi4s_if_slave.tdata  = so_axi4s_if_master.tdata;\
      assign so_axi4s_if_slave.tstrb  = so_axi4s_if_master.tstrb;\
      assign so_axi4s_if_slave.tkeep  = so_axi4s_if_master.tkeep;\
      assign so_axi4s_if_slave.tlast  = so_axi4s_if_master.tlast;\
      assign so_axi4s_if_slave.tid    = so_axi4s_if_master.tid;\
      assign so_axi4s_if_slave.tdest  = so_axi4s_if_master.tdest;\
      assign so_axi4s_if_slave.tuser  = so_axi4s_if_master.tuser;

   `define CONNECT_SO_AXI4S(so_axi4s_if_master, so_axi4s_if_slave) \
      `CONNECT_SO_AXI4S_IF_REQ(so_axi4s_if_master, so_axi4s_if_slave)\
      `CONNECT_SO_AXI4S_IF_RSP(so_axi4s_if_slave, so_axi4s_if_master)

   // Create a copy of the macro to match the version that Jim added previously
   `define PATCH_SO_AXI4S(so_axi4s_if_master, so_axi4s_if_slave) \
      `CONNECT_SO_AXI4S(so_axi4s_if_master, so_axi4s_if_slave)

   `define INIT_UNUSED_SO_AXI4S_IF_REQ(so_axi4s_if_slave)\
      assign so_axi4s_if_slave.tstrb  = '1;\
      assign so_axi4s_if_slave.tkeep  = '1;\
      assign so_axi4s_if_slave.tid    = '0;\
      assign so_axi4s_if_slave.tdest  = '0;\
      assign so_axi4s_if_slave.tuser  = '0;

endpackage : so_axi4s_if_pkg
