// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

interface sondos_shell_htg930_host_if();

    logic [3:0]  shell_leds;

    logic  [15 : 0]   pci_exp_txp;
    logic  [15 : 0]   pci_exp_txn;
    logic  [15 : 0]   pci_exp_rxp;
    logic  [15 : 0]   pci_exp_rxn;

    logic    [3:0]        ff0_rx_p;
    logic    [3:0]        ff0_rx_n;
    logic    [3:0]        ff0_tx_p;
    logic    [3:0]        ff0_tx_n;
    logic                 ff0_refclk_p;
    logic                 ff0_refclk_n;

    logic    [3:0]        ff1_rx_p;
    logic    [3:0]        ff1_rx_n;
    logic    [3:0]        ff1_tx_p;
    logic    [3:0]        ff1_tx_n;
    logic                 ff1_refclk_p;
    logic                 ff1_refclk_n;

    logic                 ff0_present_b;
    logic                 ff0_modsel_b;
    logic                 ff0_reset_b;
    logic                 ff0_iic_scl;
    logic                 ff0_iic_sda;

    logic                 ff1_present_b;
    logic                 ff1_modsel_b;
    logic                 ff1_reset_b;
    logic                 ff1_iic_scl;
    logic                 ff1_iic_sda;

    logic                 ff2_present_b;

    logic                 main_iic_scl;
    logic                 main_iic_sda;
    logic                 main_iic_resetn;
    logic                 main_iic_si_clk1_resetn;
    logic                 main_iic_si_clk2_resetn;

    logic    [11:0]       bpi_data_hi_io;
    logic    [25:0]       bpi_addr;
    logic                 bpi_adv_b;
    logic                 bpi_cso_b;
    logic                 bpi_foe_b;
    logic                 bpi_fwe_b;

    logic                 fan_en;

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

    input  ff1_rx_p,
    input  ff1_rx_n,
    output ff1_tx_p,
    output ff1_tx_n,
    input  ff1_refclk_p,
    input  ff1_refclk_n,

    input  ff0_present_b,
    output ff0_modsel_b,
    output ff0_reset_b,
    inout  ff0_iic_scl,
    inout  ff0_iic_sda,

    input  ff1_present_b,
    output ff1_modsel_b,
    output ff1_reset_b,
    inout  ff1_iic_scl,
    inout  ff1_iic_sda,

    input  ff2_present_b,

    inout  main_iic_scl,
    inout  main_iic_sda,

    output main_iic_resetn,
    output main_iic_si_clk1_resetn,
    output main_iic_si_clk2_resetn,

    inout  bpi_data_hi_io,
    output bpi_addr,
    output bpi_adv_b,
    input  bpi_cso_b,
    output bpi_foe_b,
    output bpi_fwe_b,


    output fan_en,

    input  pcie_clk_p,
    input  pcie_clk_n,
    input  pcie_rst_n,

    input  user_clk_p,
    input  user_clk_n
    );

endinterface : sondos_shell_htg930_host_if
