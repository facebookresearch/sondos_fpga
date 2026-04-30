## SPDX-License-Identifier: MIT
## (c) Meta Platforms, Inc. and affiliates.
create_ip -name qdma -vendor xilinx.com -library ip -module_name qdma_0 -dir [lindex $argv 0]
set_property -dict [list CONFIG.pcie_blk_locn {X1Y2} CONFIG.csr_axilite_slave {true} CONFIG.testname {mm} CONFIG.pf0_bar2_scale_qdma {Megabytes} CONFIG.pf0_bar2_size_qdma {64} CONFIG.pf1_bar2_scale_qdma {Megabytes} CONFIG.pf1_bar2_size_qdma {64} \
                           CONFIG.pf2_bar2_scale_qdma {Megabytes} CONFIG.pf2_bar2_size_qdma {64} CONFIG.pf3_bar2_scale_qdma {Megabytes} CONFIG.pf3_bar2_size_qdma {64} CONFIG.dma_intf_sel_qdma {AXI_MM} CONFIG.en_axi_st_qdma {false} \
                           CONFIG.en_bridge_slv {true} CONFIG.axibar_notranslate {true} CONFIG.vdm_en {1} CONFIG.axibar_highaddr_0 {0x00000000FFFFFFFF} \
                           CONFIG.vendor_id {1D9B} CONFIG.pf1_vendor_id {1D9B} CONFIG.pf2_vendor_id {1D9B} CONFIG.pf3_vendor_id {1D9B} CONFIG.pf0_device_id {CAFE} \
                           CONFIG.pf0_subsystem_vendor_id {1D9B} CONFIG.pf1_subsystem_vendor_id {1D9B} CONFIG.pf2_subsystem_vendor_id {1D9B} CONFIG.pf3_subsystem_vendor_id {1D9B} \
                           CONFIG.pf0_subsystem_id {2023} CONFIG.pf0_base_class_menu_qdma {Data_acquisition_and_signal_processing_controllers} CONFIG.pf0_class_code_base_qdma {11} \
                           CONFIG.pf0_class_code_sub_qdma {80} CONFIG.pf0_sub_class_interface_menu_qdma {Other_data_acquisition/signal_processing_controllers} CONFIG.pf0_class_code_qdma {118000}] [get_ips qdma_0]
