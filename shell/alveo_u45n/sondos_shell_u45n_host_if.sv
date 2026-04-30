// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

interface sondos_shell_u45n_host_if();

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

    logic   pcie_clk_p;
    logic   pcie_clk_n;
    logic   pcie_rst_n;

    logic   user_clk;

    logic satellite_uart_rxd;
    logic satellite_uart_txd;
    logic [1:0] satellite_gpio;

    modport shell
    (

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

    input  pcie_clk_p,
    input  pcie_clk_n,
    input  pcie_rst_n,

    input  satellite_gpio,
    input  satellite_uart_rxd,
    output satellite_uart_txd,

    input  user_clk
    );

endinterface : sondos_shell_u45n_host_if
