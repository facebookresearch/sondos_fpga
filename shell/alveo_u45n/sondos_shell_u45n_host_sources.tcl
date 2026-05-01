## SPDX-License-Identifier: MIT
## (c) Meta Platforms, Inc. and affiliates.

set SHELL_PATH $env(SONDOS_PATH)/shell
set BOARD_NAME u45n_host
set PROJECT_NAME current_project
set PROJECT_DIR [get_property DIRECTORY [current_project]]

if {[file exists $PROJECT_DIR/sondos_shell.gen]} {
  puts "found sondos_shell.gen folder"
} else {
  puts "creating sondos_shell.gen direcory ..."
  exec mkdir $PROJECT_DIR/sondos_shell.gen
}

if {[file exists $PROJECT_DIR/sondos_shell.gen/sondos_axi_crossbar/sondos_axi_crossbar.xci]} {
  read_ip $PROJECT_DIR/sondos_shell.gen/sondos_axi_crossbar/sondos_axi_crossbar.xci
  puts "found sondos_axi_crossbar.xci"
} else {
  puts "did not find sondos_axi_crossbar.xci, creating the ip ..."
  set argv [list $PROJECT_DIR/sondos_shell.gen]
  source $SHELL_PATH/common/modules/sondos_axi_crossbar_xci.tcl
}

if {[file exists $PROJECT_DIR/sondos_shell.gen/aurora_firefly_0/aurora_firefly_0.xci]} {
  read_ip $PROJECT_DIR/sondos_shell.gen/aurora_firefly_0/aurora_firefly_0.xci
  puts "found aurora_firefly_0.xci"
} else {
  puts "did not find aurora_firefly_0.xci, creating the ip ..."
  set argv [list $PROJECT_DIR/sondos_shell.gen]
  source $SHELL_PATH/common/phy/alveo_u45n/aurora_firefly_0_xci.tcl
}

if {[file exists $PROJECT_DIR/sondos_shell.gen/qdma_0/qdma_0.xci]} {
  read_ip $PROJECT_DIR/sondos_shell.gen/qdma_0/qdma_0.xci
  puts "found qdma_0.xci"
} else {
  puts "did not find qdma_0.xci, creating the ip ..."
  set argv [list $PROJECT_DIR/sondos_shell.gen]
  source $SHELL_PATH/common/phy/alveo_u45n/qdma_0_xci.tcl
}

if {[file exists $PROJECT_DIR/sondos_shell.gen/cms_subsystem/cms_subsystem.bd]} {
  add_files $PROJECT_DIR/sondos_shell.gen/cms_subsystem/cms_subsystem.bd
  puts "found cms_subsystem.bd"
} else {
  puts "did not find cms_subsystem.bd, creating the bd ..."
  set origin_dir_loc [list $PROJECT_DIR/sondos_shell.gen]
  source $SHELL_PATH/common/phy/alveo_u45n/cms_subsystem_bd.tcl
}

add_files -norecurse $SHELL_PATH/sondos_ver.svh

add_files -norecurse $SHELL_PATH/common/interfaces/axi4s/so_axi4s_if_pkg.sv
add_files -norecurse $SHELL_PATH/common/interfaces/axi4/so_axi4_if_pkg.sv
add_files -norecurse $SHELL_PATH/common/interfaces/axi4l/so_axi4l_if_pkg.sv
add_files -norecurse $SHELL_PATH/common/interfaces/axi4s/so_axi4s_if.sv
add_files -norecurse $SHELL_PATH/common/interfaces/axi4/so_axi4_if.sv
add_files -norecurse $SHELL_PATH/common/interfaces/axi4l/so_axi4l_if.sv

add_files -norecurse $SHELL_PATH/common/modules/aurora_firefly_0_wrapper.sv
add_files -norecurse $SHELL_PATH/common/modules/sondos_axi4l_crossbar.sv
add_files -norecurse $SHELL_PATH/common/modules/packetized_axi4l_slave.sv
add_files -norecurse $SHELL_PATH/common/modules/sondos_shell_link_rx_arbiter.sv
add_files -norecurse $SHELL_PATH/common/modules/sondos_shell_link_tx_arbiter.sv
add_files -norecurse $SHELL_PATH/common/modules/packetized_axi4f_write_master.sv
add_files -norecurse $SHELL_PATH/common/modules/packetized_axi4f_read_master.sv
add_files -norecurse $SHELL_PATH/common/modules/sondos_qdma_wrapper.sv
add_files -norecurse $SHELL_PATH/common/modules/sondos_axi_crossbar_wrapper.sv
add_files -norecurse $SHELL_PATH/alveo_u45n/cms_wrapper.sv
add_files -norecurse $SHELL_PATH/alveo_u45n/alveo_u45n_qsfp_init.sv

add_files -norecurse $SHELL_PATH/flash_programmers/common/iprog_icap.sv
add_files -norecurse $SHELL_PATH/flash_programmers/common/sondos_shell_flash_csr.sv
add_files -norecurse $SHELL_PATH/flash_programmers/common/sondos_shell_flash_axi_fsm.sv
add_files -norecurse $SHELL_PATH/flash_programmers/alveo/sondos_shell_alveo_qspi_controller.sv
add_files -norecurse $SHELL_PATH/flash_programmers/alveo/sondos_shell_alveo_flash_top.sv

add_files -norecurse $SHELL_PATH/alveo_u45n/sondos_shell_u45n_host_if.sv
add_files -norecurse $SHELL_PATH/alveo_u45n/sondos_shell_u45n_host_csr.sv
add_files -norecurse $SHELL_PATH/alveo_u45n/sondos_shell_u45n_host.sv

add_files -fileset constrs_1 -norecurse $SHELL_PATH/alveo_u45n/sondos_shell_u45n_host.xdc
