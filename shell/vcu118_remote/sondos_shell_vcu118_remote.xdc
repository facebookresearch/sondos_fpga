## SPDX-License-Identifier: MIT
## (c) Meta Platforms, Inc. and affiliates.


#############################################################################################################
create_clock -name user_clk -period 8 [get_ports {sondos_io\\.user_clk_p}]
create_clock -name ff0_refclk -period 6.400 [get_ports {sondos_io\\.ff0_refclk_p}]
#############################################################################################################

#############################################################################################################
#
set_property PACKAGE_PIN L9 [get_ports {sondos_io\\.ff0_refclk_p}]
set_property PACKAGE_PIN L8 [get_ports {sondos_io\\.ff0_refclk_n}]

set_property PACKAGE_PIN AY24 [get_ports {sondos_io\\.user_clk_p}]
set_property PACKAGE_PIN AY23 [get_ports {sondos_io\\.user_clk_n}]

set_property IOSTANDARD LVDS [get_ports {sondos_io\\.user_clk_p}]
set_property IOSTANDARD LVDS [get_ports {sondos_io\\.user_clk_n}]
#
#
#############################################################################################################
# Lower LEDs for VCU118
set_property -dict {PACKAGE_PIN AT32 IOSTANDARD LVCMOS12 DRIVE 8} [get_ports {sondos_io\\.shell_leds[0]}]
set_property -dict {PACKAGE_PIN AV34 IOSTANDARD LVCMOS12 DRIVE 8} [get_ports {sondos_io\\.shell_leds[1]}]
set_property -dict {PACKAGE_PIN AY30 IOSTANDARD LVCMOS12 DRIVE 8} [get_ports {sondos_io\\.shell_leds[2]}]
set_property -dict {PACKAGE_PIN BB32 IOSTANDARD LVCMOS12 DRIVE 8} [get_ports {sondos_io\\.shell_leds[3]}]
#############################################################################################################

set_property -dict {PACKAGE_PIN BB24 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.aurora_external_reset}]

# FireFly pin locations
set_property -dict {PACKAGE_PIN BC23 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.ff0_modsel_b}]
set_property -dict {PACKAGE_PIN BE24 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.ff0_reset_b}]

# QSFP1 (top) pin locations
set_property -dict {PACKAGE_PIN AM21 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.qsfp_modsell[1]}]
set_property -dict {PACKAGE_PIN AY22 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.qsfp_resetl[1]}]
set_property -dict {PACKAGE_PIN AT24 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.qsfp_lpmode[1]}]
set_property -dict {PACKAGE_PIN AN24 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.qsfp_modprsl[1]}]
set_property -dict {PACKAGE_PIN AT21 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.qsfp_intl[1]}]

# QSFP0 (bottom) pin locations
set_property -dict {PACKAGE_PIN AN23 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.qsfp_modsell[0]}]
set_property -dict {PACKAGE_PIN BA22 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.qsfp_resetl[0]}]
set_property -dict {PACKAGE_PIN AN21 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.qsfp_lpmode[0]}]
set_property -dict {PACKAGE_PIN AL21 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.qsfp_modprsl[0]}]
set_property -dict {PACKAGE_PIN AP21 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.qsfp_intl[0]}]

set_property -dict {PACKAGE_PIN AM24 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.iic_scl}]
set_property -dict {PACKAGE_PIN AL24 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.iic_sda}]
set_property -dict {PACKAGE_PIN AL25 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.iic_mux_reset_b}]


set_property -dict {PACKAGE_PIN AM19 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.spi_io_1_io[0]}]
set_property -dict {PACKAGE_PIN AM18 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.spi_io_1_io[1]}]
set_property -dict {PACKAGE_PIN AN20 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.spi_io_1_io[2]}]
set_property -dict {PACKAGE_PIN AP20 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.spi_io_1_io[3]}]
set_property -dict {PACKAGE_PIN BF16 IOSTANDARD LVCMOS18} [get_ports {sondos_io\\.spi_cs_1_n}]

set_property PULLUP true [get_ports {sondos_io\\.spi_io_1_io[0]}]
set_property PULLUP true [get_ports {sondos_io\\.spi_io_1_io[1]}]
set_property PULLUP true [get_ports {sondos_io\\.spi_io_1_io[2]}]
set_property PULLUP true [get_ports {sondos_io\\.spi_io_1_io[3]}]

# The following max delays are set to 15 ns with no min delay which makes the max (worst case) skew between signals 15 ns
# The clock period for QSPI is ~64 ns, whith the source changing output data on the falling edge and capturing input data on the rising edge
# so effectively the skew should be < 32 ns to avoid timing violations
# to allow for external (board level) skew of another ~16 ns, we set the maximum delay to < 16 ns in this case 15
# We should note that we have plenty of room here,
# so if the 15 ns constraint start annoying us in the future we should be able to ease it up to ~ 20 ns
# but for now it has been meeting easily at 13 ns, so 15 should be fine for a while
# we can also introduce min delay constraint, which would allow us to push this number even higher

set_max_delay  15  -to [get_ports {sondos_io\\.spi_io_1_io[0]}]
set_max_delay  15  -to [get_ports {sondos_io\\.spi_io_1_io[1]}]
set_max_delay  15  -to [get_ports {sondos_io\\.spi_io_1_io[2]}]
set_max_delay  15  -to [get_ports {sondos_io\\.spi_io_1_io[3]}]
set_max_delay  15  -to [get_ports {sondos_io\\.spi_cs_1_n}]

set_max_delay  15  -from [get_ports {sondos_io\\.spi_io_1_io[0]}]
set_max_delay  15  -from [get_ports {sondos_io\\.spi_io_1_io[1]}]
set_max_delay  15  -from [get_ports {sondos_io\\.spi_io_1_io[2]}]
set_max_delay  15  -from [get_ports {sondos_io\\.spi_io_1_io[3]}]

set_max_delay  15  -through [get_pins -hierarchical -filter {NAME =~ "*STARTUPE3_inst*USRCCLKO"}]
set_max_delay  15  -through [get_pins -hierarchical -filter {NAME =~ "*STARTUPE3_inst*FCSBO"}]
set_max_delay  15  -through [get_pins -hierarchical -filter {NAME =~ "*STARTUPE3_inst*DI[*]"}]
set_max_delay  15  -through [get_pins -hierarchical -filter {NAME =~ "*STARTUPE3_inst*DO[*]"}]
set_max_delay  15  -through [get_pins -hierarchical -filter {NAME =~ "*STARTUPE3_inst*DTS[*]"}]

#############################################################################################################
# Bitstream settings

set_property CONFIG_MODE SPIx8 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 8 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 56.7 [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR yes [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS true [current_design]
