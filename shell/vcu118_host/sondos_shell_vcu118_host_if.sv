// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

interface sondos_shell_vcu118_host_if();

    logic [3:0]  shell_leds;

    logic  [15 : 0]   pci_exp_txp;
    logic  [15 : 0]   pci_exp_txn;
    logic  [15 : 0]   pci_exp_rxp;
    logic  [15 : 0]   pci_exp_rxn;

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

    logic                iic_mux_reset_b;
    wire                 iic_scl;
    wire                 iic_sda;


    logic   pcie_clk_p;
    logic   pcie_clk_n;
    logic   pcie_rst_n;

    logic   user_clk_p;
    logic   user_clk_n;

    modport shell
    (

    output shell_leds,

    output pci_exp_txp,
    output pci_exp_txn,
    input  pci_exp_rxp,
    input  pci_exp_rxn,

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

    output iic_mux_reset_b,
    inout  iic_scl,
    inout  iic_sda,


    input  pcie_clk_p,
    input  pcie_clk_n,
    input  pcie_rst_n,

    input  user_clk_p,
    input  user_clk_n
    );

endinterface : sondos_shell_vcu118_host_if
