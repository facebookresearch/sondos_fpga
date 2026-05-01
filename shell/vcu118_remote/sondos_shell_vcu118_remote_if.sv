// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

interface sondos_shell_vcu118_remote_if();

    logic [3:0]  shell_leds;

    logic     [3:0]       ff0_rx_p;
    logic     [3:0]       ff0_rx_n;
    logic     [3:0]       ff0_tx_p;
    logic     [3:0]       ff0_tx_n;
    logic                 ff0_refclk_p;
    logic                 ff0_refclk_n;

    logic spi_cs_1_n;
    wire [3:0] spi_io_1_io;

    logic [1:0] qsfp_modsell;
    logic [1:0] qsfp_resetl ;
    logic [1:0] qsfp_lpmode ;
    logic [1:0] qsfp_modprsl;
    logic  [1:0] qsfp_intl   ;

    logic ff0_modsel_b;
    logic ff0_reset_b;


    logic aurora_external_reset;

    logic                iic_mux_reset_b;
    wire                 iic_scl;
    wire                 iic_sda;

    logic   user_clk_p;
    logic   user_clk_n;

    modport shell
    (

    output shell_leds,

    input  ff0_rx_p,
    input  ff0_rx_n,
    output ff0_tx_p,
    output ff0_tx_n,
    input  ff0_refclk_p,
    input  ff0_refclk_n,

    output spi_cs_1_n,
    inout  spi_io_1_io,

    output qsfp_modsell,
    output qsfp_resetl,
    output qsfp_lpmode,
    output qsfp_modprsl,
    input  qsfp_intl,

    output ff0_modsel_b,
    output ff0_reset_b,

    input aurora_external_reset,

    output iic_mux_reset_b,
    inout  iic_scl,
    inout  iic_sda,

    input  user_clk_p,
    input  user_clk_n
    );

endinterface : sondos_shell_vcu118_remote_if
