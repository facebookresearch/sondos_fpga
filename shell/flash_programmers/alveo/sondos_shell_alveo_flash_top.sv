// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.


module sondos_shell_alveo_flash_top #(
    parameter logic [63:0] DEVICE_ID = "UNKNOWN"
)(
    input clk,
    input reset,
    input done_beat,
    so_axi4_if.master axi_full_flash,
    so_axi4l_if.slave axi_lite_flash
    );


logic start_reading;
logic start_writing;
logic add_phy_page;
logic enable_memory_access;
logic [31:0] new_phy_page_address;
logic [31:0] axi_pipeline_state;
logic [31:0] time_since_last_op;
logic [15:0] pending_pages;
logic [31:0] read_word_count;
logic [31:0] write_word_count;

logic data_from_controller_valid;
logic [255:0] data_from_controller;
logic data_to_controller_taken;
logic [255:0] data_to_controller;

logic [31:0] generic_config;
logic controller_reset;
logic controller_fsm_start;
logic [7:0] controller_fsm_command;
logic [31:0] controller_start_address;
logic [31:0] controller_end_address;
logic [31:0] controller_current_address;
logic [7:0] controller_state;


////////////////////////////////////////////////////////////////////
/////////////// Component Instantiation ////////////////////////////
////////////////////////////////////////////////////////////////////


sondos_shell_flash_csr #(.DEVICE_ID(DEVICE_ID)) flash_csr_unit
(
   .clk,
   .reset,

   .axi_lite_flash,

   .start_reading,
   .start_writing,
   .enable_memory_access,
   .add_phy_page,
   .new_phy_page_address,
   .axi_pipeline_state,
   .time_since_last_op,
   .pending_pages,
   .write_word_count,
   .read_word_count,

   .generic_config,

   .controller_reset,
   .controller_fsm_start,
   .controller_fsm_command,
   .controller_start_address,
   .controller_end_address,
   .controller_current_address,
   .controller_state
);

sondos_shell_flash_axi_fsm axi_fsm_unit
(
   .clk,
   .reset(controller_reset),

   .axi_full_flash,

   .start_reading,
   .start_writing,
   .enable_memory_access,
   .add_phy_page,
   .new_phy_page_address,
   .axi_pipeline_state,
   .time_since_last_op,
   .pending_pages,
   .write_word_count,
   .read_word_count,

   .data_from_controller_valid,
   .data_from_controller,
   .data_to_controller_taken,
   .data_to_controller
);


sondos_shell_alveo_qspi_controller sondos_io_alveo_controller_unit(
   .clk,
   .reset(controller_reset),
   .done_beat,
   .spi_state(controller_state),
   .current_address(controller_current_address),
   .fsm_start(controller_fsm_start),
   .fsm_command(controller_fsm_command),
   .starting_address(controller_start_address),
   .ending_address(controller_end_address),
   .clk_shift(generic_config[3:0]),

   .data_to_host_valid(data_from_controller_valid),
   .data_to_host(data_from_controller),

   .data_from_host_taken(data_to_controller_taken),
   .data_from_host(data_to_controller)
);


endmodule
