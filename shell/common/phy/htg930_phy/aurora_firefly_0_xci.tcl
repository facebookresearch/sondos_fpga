## SPDX-License-Identifier: MIT
## (c) Meta Platforms, Inc. and affiliates.
create_ip -name aurora_64b66b -vendor xilinx.com -library ip -module_name aurora_firefly_0 -dir [lindex $argv 0]
set_property -dict [list CONFIG.CHANNEL_ENABLE {X1Y44 X1Y45 X1Y46 X1Y47} CONFIG.C_AURORA_LANES {4} CONFIG.C_LINE_RATE {15.625} CONFIG.C_INIT_CLK {200} CONFIG.C_USER_K {true} CONFIG.C_START_QUAD {Quad_X1Y11} CONFIG.C_START_LANE {X1Y44} CONFIG.C_REFCLK_SOURCE {MGTREFCLK0_of_Quad_X1Y11} CONFIG.C_GT_LOC_4 {4} CONFIG.C_GT_LOC_3 {3} CONFIG.C_GT_LOC_2 {2} CONFIG.crc_mode {true} CONFIG.SupportLevel {1} CONFIG.C_USE_BYTESWAP {true}] [get_ips aurora_firefly_0]
