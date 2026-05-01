// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

module sondos_shell_flash_csr #(
    parameter logic [63:0] DEVICE_ID = "UNKNOWN"
)
(
    input           clk,
    input           reset,

    so_axi4l_if.slave axi_lite_flash,

    output start_reading,
    output start_writing,
    output enable_memory_access,
    output add_phy_page,
    output [31:0] new_phy_page_address,
    input [31:0] axi_pipeline_state,
    input [31:0] time_since_last_op,
    input [15:0] pending_pages,
    input [31:0] write_word_count,
    input [31:0] read_word_count,

    output [31:0] generic_config,

    output controller_reset,
    output controller_fsm_start,
    output [7:0] controller_fsm_command,
    output [31:0] controller_start_address,
    output [31:0] controller_end_address,
    input [31:0] controller_current_address,
    input [7:0] controller_state
);

parameter int WATCHDOG_TIMOUT_VALUE = 250*1000*1000; // 1 second timeout based on the 250MHz clock
localparam int NUM_REGS = 16;
localparam int ADDRESS_WIDTH = $clog2(NUM_REGS);


logic controller_reset_r;
logic controller_fsm_start_r;
logic [7:0] controller_fsm_command_r;
logic [31:0] watchdog_timer;
logic watchdog_timeout;
logic module_active;
logic start_reading_r;
logic start_writing_r;
logic add_phy_page_r;

logic [NUM_REGS-1:0][31:0] my_reg_array;

logic [ADDRESS_WIDTH-1:0]  read_address;
logic [ADDRESS_WIDTH-1:0]  write_address;
logic axil_received_write_address;
logic [31:0] write_data;
logic write_enable;
logic read_req;
logic read_data_valid;
logic [31:0] read_data;



assign axi_lite_flash.awready = ~axil_received_write_address;
assign axi_lite_flash.wready = axil_received_write_address;
assign axi_lite_flash.bid = '0;
assign axi_lite_flash.bresp = '0;
assign axi_lite_flash.buser = '0;
assign axi_lite_flash.bvalid = 1'b1;
assign axi_lite_flash.arready = 1'b1;
assign axi_lite_flash.rid = '0;
assign axi_lite_flash.rdata = read_data;
assign axi_lite_flash.rresp = '0;
assign axi_lite_flash.ruser = '0;
assign axi_lite_flash.rvalid = read_data_valid;


assign controller_reset = controller_reset_r;
assign controller_fsm_start = controller_fsm_start_r;
assign controller_fsm_command = controller_fsm_command_r;
assign start_reading = start_reading_r;
assign start_writing = start_writing_r;
assign controller_start_address = my_reg_array[1];
assign controller_end_address = my_reg_array[2];
assign new_phy_page_address = my_reg_array[3];
assign add_phy_page = add_phy_page_r;
assign enable_memory_access = module_active;

assign generic_config = my_reg_array[11];


assign watchdog_timeout = (watchdog_timer == WATCHDOG_TIMOUT_VALUE);

always_ff @(posedge clk) begin
    if(reset) begin
        write_enable <= 1'b0;
        axil_received_write_address <= 1'b0;
    end else begin
        write_enable <= axi_lite_flash.wvalid  & axil_received_write_address;
        axil_received_write_address <= (axil_received_write_address)? ~axi_lite_flash.wvalid : axi_lite_flash.awvalid;
    end
    write_data <= axi_lite_flash.wdata;
    write_address <= (axi_lite_flash.awvalid)? axi_lite_flash.awaddr[2+:ADDRESS_WIDTH] : write_address;
    read_address <= (axi_lite_flash.arvalid)? axi_lite_flash.araddr[2+:ADDRESS_WIDTH] : read_address;
    read_req <= axi_lite_flash.arvalid;
    read_data_valid <= read_req;
    read_data <= my_reg_array[read_address];
end

// The watchdog timer together with the module active register allow the SW to limit access to this module to be
// only one process at any given time, and to automatically disable the module when that process is terminated

always_ff @(posedge clk) begin
    if(reset) begin
        controller_reset_r <= 1'b1;
        controller_fsm_start_r <= 1'b0;
        controller_fsm_command_r <= '0;
        start_reading_r <= 1'b0;
        start_writing_r <= 1'b0;
        add_phy_page_r <= 1'b0;
        watchdog_timer <= WATCHDOG_TIMOUT_VALUE;
        module_active <= 1'b0;
    end else begin
        controller_reset_r <= write_enable & (write_address == 6'd0) & write_data[16];
        controller_fsm_start_r <= write_enable & (write_address == 6'd0) & write_data[8];
        controller_fsm_command_r <= (write_enable & (write_address == 6'd0))? write_data[7:0] : controller_fsm_command_r;
        start_reading_r <= write_enable & (write_address == 6'd0) & write_data[9];
        start_writing_r <= write_enable & (write_address == 6'd0) & write_data[10];

        add_phy_page_r <= write_enable & (write_address == 6'd3);

        watchdog_timer <= (write_enable & (write_address == 6'd12))? '0 :
                          (watchdog_timeout)? watchdog_timer : watchdog_timer + 1'b1;

        module_active <= (read_req & (read_address == 6'd13))? 1'b1 :
                         (watchdog_timeout)? 1'b0 : module_active;
    end
end

always_ff @(posedge clk) begin
    my_reg_array[0] <= '0; // reserved for controller fsm commands
    if(reset) begin
        my_reg_array[1] <= '0;
        my_reg_array[2] <= '0;
        my_reg_array[3] <= '0;
    end else begin
        my_reg_array[1] <= (write_enable & (write_address==4'd1))? write_data : my_reg_array[1];
        my_reg_array[2] <= (write_enable & (write_address==4'd2))? write_data : my_reg_array[2];
        my_reg_array[3] <= (write_enable & (write_address==4'd3))? write_data : my_reg_array[3];
    end

    my_reg_array[4] <= controller_current_address;
    my_reg_array[5] <= controller_state;
    my_reg_array[6] <= axi_pipeline_state;
    my_reg_array[7] <= time_since_last_op;
    my_reg_array[8] <= pending_pages;
    my_reg_array[9] <= write_word_count;
    my_reg_array[10] <= read_word_count;

    if(reset) begin
        my_reg_array[11] <= '0;
    end else begin
        my_reg_array[11] <= (write_enable & (write_address==4'd11))? write_data : my_reg_array[11]; // generic config
    end

    my_reg_array[12] <= watchdog_timer;
    my_reg_array[13] <= module_active;
    my_reg_array[14] <= DEVICE_ID[31:0];//32'h466c6173; // Regs 14 & 15 are ASCII for "FlashReg"
    my_reg_array[15] <= DEVICE_ID[63:32];//32'h68526567;
end

endmodule
