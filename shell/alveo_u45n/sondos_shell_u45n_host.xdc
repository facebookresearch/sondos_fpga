## SPDX-License-Identifier: MIT
## (c) Meta Platforms, Inc. and affiliates.


#############################################################################################################
create_clock -name sys_clk -period 10 [get_ports {sondos_io\\.pcie_clk_p}]
create_clock -name user_clk -period 8 [get_ports {sondos_io\\.user_clk}]
create_clock -name ff0_refclk -period 6.206 [get_ports {sondos_io\\.ff0_refclk_p}]
#############################################################################################################
set_false_path -from [get_ports {sondos_io\\.pcie_rst_n}]
set_property PULLUP true [get_ports {sondos_io\\.pcie_rst_n}]
set_property IOSTANDARD LVCMOS18 [get_ports {sondos_io\\.pcie_rst_n}]
set_property PACKAGE_PIN AK18 [get_ports {sondos_io\\.pcie_rst_n}]
#
#############################################################################################################

set_property PACKAGE_PIN AL10 [get_ports {sondos_io\\.pcie_clk_p}]
set_property PACKAGE_PIN AL9  [get_ports {sondos_io\\.pcie_clk_n}]

set_property PACKAGE_PIN P9 [get_ports {sondos_io\\.ff0_refclk_p}]
set_property PACKAGE_PIN P8 [get_ports {sondos_io\\.ff0_refclk_n}]

set_property -dict {PACKAGE_PIN AH17 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.user_clk}]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets {sondos_io\\.user_clk}]
#

# Satellite Controller (CMS) UART
set_property -dict {PACKAGE_PIN AK21 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.satellite_uart_rxd}]
set_property -dict {PACKAGE_PIN AJ21 IOSTANDARD LVCMOS18 DRIVE 4} [get_ports {sondos_io\\.satellite_uart_txd}]

# Satellite Controller (CMS) GPIO
set_property -dict {PACKAGE_PIN AM17 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.satellite_gpio[0]}]
set_property -dict {PACKAGE_PIN AL18 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.satellite_gpio[1]}]

#
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
