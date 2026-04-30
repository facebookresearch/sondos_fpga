## SPDX-License-Identifier: MIT
## (c) Meta Platforms, Inc. and affiliates.


#############################################################################################################
create_clock -name sys_clk -period 10 [get_ports {sondos_io\\.pcie_clk_p}]
create_clock -name user_clk -period 5 [get_ports {sondos_io\\.user_clk_p}]
create_clock -name ff0_refclk -period 6.400 [get_ports {sondos_io\\.ff0_refclk_p}]
create_clock -name ff1_refclk -period 6.400 [get_ports {sondos_io\\.ff1_refclk_p}]
#############################################################################################################
set_false_path -from [get_ports {sondos_io\\.pcie_rst_n}]
set_property PULLUP true [get_ports {sondos_io\\.pcie_rst_n}]
set_property IOSTANDARD LVCMOS18 [get_ports {sondos_io\\.pcie_rst_n}]
set_property PACKAGE_PIN AR26 [get_ports {sondos_io\\.pcie_rst_n}]
#
#############################################################################################################

set_property PACKAGE_PIN AM11 [get_ports {sondos_io\\.pcie_clk_p}]
set_property PACKAGE_PIN AM10 [get_ports {sondos_io\\.pcie_clk_n}]

set_property PACKAGE_PIN K11 [get_ports {sondos_io\\.ff0_refclk_p}]
set_property PACKAGE_PIN K10 [get_ports {sondos_io\\.ff0_refclk_n}]

########################################################################################################################
# Swapping the pins for the middle Firefly module FF1
set_property LOC GTYE4_CHANNEL_X1Y39 [get_cells -hierarchical -filter {NAME =~ *gen_channel_container[34].*gen_gtye4_channel_inst[2].GTYE4_CHANNEL_PRIM_INST}]

set_property LOC GTYE4_CHANNEL_X1Y42 [get_cells -hierarchical -filter {NAME =~ *gen_channel_container[34].*gen_gtye4_channel_inst[1].GTYE4_CHANNEL_PRIM_INST}]
set_property LOC GTYE4_CHANNEL_X1Y41 [get_cells -hierarchical -filter {NAME =~ *gen_channel_container[34].*gen_gtye4_channel_inst[0].GTYE4_CHANNEL_PRIM_INST}]
set_property LOC GTYE4_CHANNEL_X1Y40 [get_cells -hierarchical -filter {NAME =~ *gen_channel_container[34].*gen_gtye4_channel_inst[2].GTYE4_CHANNEL_PRIM_INST}]
set_property LOC GTYE4_CHANNEL_X1Y43 [get_cells -hierarchical -filter {NAME =~ *gen_channel_container[34].*gen_gtye4_channel_inst[3].GTYE4_CHANNEL_PRIM_INST}]
########################################################################################################################

set_property PACKAGE_PIN P11 [get_ports {sondos_io\\.ff1_refclk_p}]
set_property PACKAGE_PIN P10 [get_ports {sondos_io\\.ff1_refclk_n}]

# 200MHz LVDS 1V8 default.
set_property -dict {PACKAGE_PIN C38 IOSTANDARD LVDS} [get_ports {sondos_io\\.user_clk_p}]
set_property -dict {PACKAGE_PIN C39 IOSTANDARD LVDS} [get_ports {sondos_io\\.user_clk_n}]
#
#
#############################################################################################################
# Lower LEDs for VCU118
set_property -dict {PACKAGE_PIN R20 IOSTANDARD LVCMOS18 DRIVE 8} [get_ports {sondos_io\\.shell_leds[0]}]
set_property -dict {PACKAGE_PIN P20 IOSTANDARD LVCMOS18 DRIVE 8} [get_ports {sondos_io\\.shell_leds[1]}]
set_property -dict {PACKAGE_PIN N21 IOSTANDARD LVCMOS18 DRIVE 8} [get_ports {sondos_io\\.shell_leds[2]}]
set_property -dict {PACKAGE_PIN M21 IOSTANDARD LVCMOS18 DRIVE 8} [get_ports {sondos_io\\.shell_leds[3]}]
#############################################################################################################

set_property -dict {PACKAGE_PIN BD11 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.fan_en}]

set_property -dict {PACKAGE_PIN A14 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.main_iic_resetn}]
set_property -dict {PACKAGE_PIN H38 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.main_iic_si_clk1_resetn}]
set_property -dict {PACKAGE_PIN M30 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.main_iic_si_clk2_resetn}]

set_property -dict {PACKAGE_PIN A13 IOSTANDARD LVCMOS18 DRIVE 4 SLEW SLOW} [get_ports {sondos_io\\.main_iic_scl}]
set_property -dict {PACKAGE_PIN D14 IOSTANDARD LVCMOS18 DRIVE 4 SLEW SLOW} [get_ports {sondos_io\\.main_iic_sda}]

set_property -dict {PACKAGE_PIN G14 IOSTANDARD LVCMOS18 DRIVE 4 SLEW SLOW} [get_ports {sondos_io\\.ff0_iic_scl}]
set_property -dict {PACKAGE_PIN F14 IOSTANDARD LVCMOS18 DRIVE 4 SLEW SLOW} [get_ports {sondos_io\\.ff0_iic_sda}]

set_property -dict {PACKAGE_PIN J20 IOSTANDARD LVCMOS18 DRIVE 4 SLEW SLOW} [get_ports {sondos_io\\.ff1_iic_scl}]
set_property -dict {PACKAGE_PIN J19 IOSTANDARD LVCMOS18 DRIVE 4 SLEW SLOW} [get_ports {sondos_io\\.ff1_iic_sda}]

# FireFly pin locations
set_property -dict {PACKAGE_PIN E16 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.ff0_present_b}]
set_property -dict {PACKAGE_PIN E17 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.ff0_modsel_b}]
set_property -dict {PACKAGE_PIN E18 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.ff0_reset_b}]

set_property -dict {PACKAGE_PIN C21 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.ff1_present_b}]
set_property -dict {PACKAGE_PIN E20 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.ff1_modsel_b}]
set_property -dict {PACKAGE_PIN E21 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.ff1_reset_b}]

set_property -dict {PACKAGE_PIN D13 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.ff2_present_b}]

#############################################################################################################
# BPI programming pins, except those in bank 0 (handled by STARTUPE3)
# See UG570 table 1-8, Configuration Pins - Parallel Modes
# bpi_data_hi[0] == D[4]
set_property -dict {PACKAGE_PIN AM26 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_data_hi_io[0]}]
set_property -dict {PACKAGE_PIN AN26 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_data_hi_io[1]}]
set_property -dict {PACKAGE_PIN AL25 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_data_hi_io[2]}]
set_property -dict {PACKAGE_PIN AM25 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_data_hi_io[3]}]
set_property -dict {PACKAGE_PIN AN28 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_data_hi_io[4]}]
set_property -dict {PACKAGE_PIN AP28 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_data_hi_io[5]}]
set_property -dict {PACKAGE_PIN AP25 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_data_hi_io[6]}]
set_property -dict {PACKAGE_PIN AP26 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_data_hi_io[7]}]
set_property -dict {PACKAGE_PIN AR28 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_data_hi_io[8]}]
set_property -dict {PACKAGE_PIN AT28 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_data_hi_io[9]}]
set_property -dict {PACKAGE_PIN AR27 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_data_hi_io[10]}]
set_property -dict {PACKAGE_PIN AT27 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_data_hi_io[11]}]

set_property -dict {PACKAGE_PIN AR25 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_addr[0]}]
set_property -dict {PACKAGE_PIN AT25 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_addr[1]}]
set_property -dict {PACKAGE_PIN AU26 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_addr[2]}]
set_property -dict {PACKAGE_PIN AU27 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_addr[3]}]
set_property -dict {PACKAGE_PIN AV27 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_addr[4]}]
set_property -dict {PACKAGE_PIN AV28 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_addr[5]}]
set_property -dict {PACKAGE_PIN AV26 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_addr[6]}]
set_property -dict {PACKAGE_PIN AW26 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_addr[7]}]
set_property -dict {PACKAGE_PIN AW28 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_addr[8]}]
set_property -dict {PACKAGE_PIN AY28 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_addr[9]}]
set_property -dict {PACKAGE_PIN AY26 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_addr[10]}]
set_property -dict {PACKAGE_PIN AY27 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_addr[11]}]
set_property -dict {PACKAGE_PIN AW25 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_addr[12]}]
set_property -dict {PACKAGE_PIN AY25 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_addr[13]}]
set_property -dict {PACKAGE_PIN BA27 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_addr[14]}]
set_property -dict {PACKAGE_PIN BA28 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_addr[15]}]
set_property -dict {PACKAGE_PIN BB26 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_addr[16]}]
set_property -dict {PACKAGE_PIN BB27 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_addr[17]}]
set_property -dict {PACKAGE_PIN BA25 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_addr[18]}]
set_property -dict {PACKAGE_PIN BB25 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_addr[19]}]
set_property -dict {PACKAGE_PIN BC26 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_addr[20]}]
set_property -dict {PACKAGE_PIN BC27 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_addr[21]}]
set_property -dict {PACKAGE_PIN BE25 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_addr[22]}]
set_property -dict {PACKAGE_PIN BF25 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_addr[23]}]
set_property -dict {PACKAGE_PIN BD26 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_addr[24]}]
set_property -dict {PACKAGE_PIN BE26 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_addr[25]}]

set_property -dict {PACKAGE_PIN AU25 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_adv_b}]
set_property -dict {PACKAGE_PIN AL28 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_cso_b}]
set_property -dict {PACKAGE_PIN BE27 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_foe_b}]
set_property -dict {PACKAGE_PIN BF27 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.bpi_fwe_b}]


#############################################################################################################
# Bitstream settings

set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property CFGBVS         GND [current_design]

set_property BITSTREAM.GENERAL.COMPRESS true   [current_design]

set_property CONFIG_MODE BPI16 [current_design]

set_property BITSTREAM.CONFIG.BPI_SYNC_MODE    TYPE1    [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE       85.0    [current_design]
set_property BITSTREAM.CONFIG.DONEPIN          PULLNONE [current_design]
set_property BITSTREAM.CONFIG.INITSIGNALSERROR ENABLE   [current_design]

set_property BITSTREAM.STARTUP.MATCH_CYCLE  2   [current_design]
set_property BITSTREAM.STARTUP.LCK_CYCLE    3   [current_design]
set_property BITSTREAM.STARTUP.GWE_CYCLE    4   [current_design]
set_property BITSTREAM.STARTUP.GTS_CYCLE  5   [current_design]
set_property BITSTREAM.STARTUP.DONE_CYCLE 6   [current_design]
