// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

interface sondos_shell_u250_host_if();

    logic  [15 : 0]   pci_exp_txp;
    logic  [15 : 0]   pci_exp_txn;
    logic  [15 : 0]   pci_exp_rxp;
    logic  [15 : 0]   pci_exp_rxn;

    logic   pcie_clk_p;
    logic   pcie_clk_n;
    logic   pcie_rst_n;

    modport shell
    (
    output pci_exp_txp,
    output pci_exp_txn,
    input  pci_exp_rxp,
    input  pci_exp_rxn,

    input  pcie_clk_p,
    input  pcie_clk_n,
    input  pcie_rst_n
    );

endinterface : sondos_shell_u250_host_if
