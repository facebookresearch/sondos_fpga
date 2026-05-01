## SPDX-License-Identifier: MIT
## (c) Meta Platforms, Inc. and affiliates.


#############################################################################################################
create_clock -name sys_clk -period 10 [get_ports {sondos_io\\.pcie_clk_p}]
#############################################################################################################
set_false_path -from [get_ports {sondos_io\\.pcie_rst_n}]
set_property PULLUP true [get_ports {sondos_io\\.pcie_rst_n}]
set_property IOSTANDARD LVCMOS18 [get_ports {sondos_io\\.pcie_rst_n}]
set_property PACKAGE_PIN BD21 [get_ports {sondos_io\\.pcie_rst_n}]
#
#############################################################################################################

set_property PACKAGE_PIN AM11 [get_ports {sondos_io\\.pcie_clk_p}]
set_property PACKAGE_PIN AM10 [get_ports {sondos_io\\.pcie_clk_n}]

#############################################################################################################
# Bitstream settings
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property CFGBVS GND [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 72.9 [current_design]
set_property BITSTREAM.CONFIG.EXTMASTERCCLK_EN DISABLE [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR Yes [current_design]
