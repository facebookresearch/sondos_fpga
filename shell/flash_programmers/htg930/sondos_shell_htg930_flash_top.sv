// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.


module sondos_shell_htg930_flash_top(
    input clk,
    input reset,
    input done_beat,
    so_axi4_if.master axi_full_flash,
    so_axi4l_if.slave axi_lite_flash,

    // BPI pins not in STARTUPE3
    inout  logic [11:0] bpi_data_hi_io,
    output logic [25:0] bpi_addr,
    output logic        bpi_adv_b,
    output logic        bpi_foe_b,
    output logic        bpi_fwe_b
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

logic [15:0] bpi_dq_i;
logic [15:0] bpi_dq_o;
logic [15:0] bpi_dq_t;
logic bpi_fcs_b;

////////////////////////////////////////////////////////////////////
/////////////// Component Instantiation ////////////////////////////
////////////////////////////////////////////////////////////////////


sondos_shell_flash_csr #(.DEVICE_ID("HTG_930 ")) flash_csr_unit
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


sondos_shell_htg930_bpi_controller sondos_htg930_bpi_controller_unit(
   .clk,
   .reset(controller_reset),
   .controller_state(controller_state),
   .current_address(controller_current_address),
   .fsm_start(controller_fsm_start),
   .fsm_command(controller_fsm_command),
   .starting_address(controller_start_address),
   .ending_address(controller_end_address),

   .bpi_dq_o(bpi_dq_o),
   .bpi_dq_i(bpi_dq_i),
   .bpi_dq_t(bpi_dq_t),
   .bpi_addr(bpi_addr),
   .bpi_adv_b(bpi_adv_b),
   .bpi_fcs_b(bpi_fcs_b),
   .bpi_foe_b(bpi_foe_b),
   .bpi_fwe_b(bpi_fwe_b),

   .data_to_host_valid(data_from_controller_valid),
   .data_to_host(data_from_controller),

   .data_from_host_taken(data_to_controller_taken),
   .data_from_host(data_to_controller)
);

////////////////////////////////////////////////////////////////////
/////////////// Device Pin Connections /////////////////////////////
////////////////////////////////////////////////////////////////////

STARTUPE3#(
   .PROG_USR     ("FALSE"), //Don't activate the program event security feature
   .SIM_CCLK_FREQ(0.0    )  //Set the configuration clock frequency (ns) for simulation
)
STARTUPE3_inst(
   .EOS      (             ), // End of startup (unused)
   .CFGCLK   (             ), // Configuration main clock output (unused)
   .CFGMCLK  (             ), // Configuration internal oscillator output (unused)
   .DI       (bpi_dq_i[3:0]),
   .DO       (bpi_dq_o[3:0]),
   .DTS      (bpi_dq_t[3:0]),
   .FCSBO    (bpi_fcs_b    ), // FPGA RDWR_FCS_B / Flash CE#
   .FCSBTS   (1'b0         ),
   .GSR      (1'b0         ), // No trigger of global set/reset
   .GTS      (1'b0         ), // No trigger of global tri state
   .KEYCLEARB(1'b1         ), // No key clear capability - only useful for encrypted designs
   .PREQ     (             ), // PROGRAM request (unused)
   .PACK     (1'b1         ), // PROGRAM request acknowledgement
   .USRCCLKO (1'b0         ), // Flash CLK
   .USRCCLKTS(1'b0         ), // Set tri-state on FPGA CCLK / Flash CLK
   .USRDONEO (done_beat    ), // FPGA DONE signal is a heartbeat based on PCIe clock
   .USRDONETS(1'b0         )  // FPGA DONE signal is not tristated
);

generate
    for(genvar ii = 4; ii < 16; ii++ ) begin: gen_bpi_io_buf
        IOBUF bpi_io(
           .O (bpi_dq_i[ii] ),
           .I (bpi_dq_o[ii]),
           .T (bpi_dq_t[ii]),
           .IO(bpi_data_hi_io[ii-4])
        );
    end
endgenerate
endmodule
