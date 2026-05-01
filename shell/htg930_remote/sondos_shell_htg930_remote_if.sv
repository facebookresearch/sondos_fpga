// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

interface sondos_shell_htg930_remote_if();

    logic [3:0]  shell_leds;

    logic    [3:0]        ff0_rx_p;
    logic    [3:0]        ff0_rx_n;
    logic    [3:0]        ff0_tx_p;
    logic    [3:0]        ff0_tx_n;
    logic                 ff0_refclk_p;
    logic                 ff0_refclk_n;

    logic                 ff0_present_b;
    logic                 ff0_modsel_b;
    logic                 ff0_reset_b;
    logic                 ff0_iic_scl;
    logic                 ff0_iic_sda;

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
    logic                 fan_pwm_bypass;

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

    input  ff0_present_b,
    output ff0_modsel_b,
    output ff0_reset_b,
    inout  ff0_iic_scl,
    inout  ff0_iic_sda,

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
    input  fan_pwm_bypass,

    input  user_clk_p,
    input  user_clk_n
    );

endinterface : sondos_shell_htg930_remote_if
