// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

module page_translation_stage_read
import so_axi4_if_pkg::*,so_axi4l_if_pkg::*;
#(
    parameter int NUM_DEBUG_REGS = 1
)(
    input clk,
    input reset,
    output interface_is_active,
    output [31:0] memory_size,
    input [31:0] current_hw_address,
    input [31:0] remaining_hw_credit,
    output [31:0] hw_credit_value,
    output increment_hw_credit,
    output reset_interface,
    input [NUM_DEBUG_REGS-1:0][31:0] debug_inputs,
    so_axi4_if.slave axi_full_from_app,
    so_axi4_if.master_read axi_full_to_host,
    so_axi4l_if.slave axi_lite_user
 );
parameter int MAX_NUM_PAGES = 8*1024;
parameter int TABLE_ADDR_WIDTH = $clog2(MAX_NUM_PAGES);
parameter int WATCHDOG_TIMOUT_VALUE = 250*1000*1000; // 1 second timeout based on the 250MHz clock


logic [31:0] watchdog_timer;
logic [31:0] allocated_mem_size;
logic [31:0] credit_value;
logic increment_credit;
logic reset_interface_r;
logic page_table_active;
logic [31:0] selected_read_reg;
logic [31:0] selected_read_c;
logic [NUM_DEBUG_REGS-1:0][31:0] debug_regs;
logic [TABLE_ADDR_WIDTH-1:0] read_address;
logic [TABLE_ADDR_WIDTH-1:0] write_address;
logic [TABLE_ADDR_WIDTH-1:0] memory_read_address;
logic [TABLE_ADDR_WIDTH-1:0] memory_read_address_d1;
logic [TABLE_ADDR_WIDTH-1:0] original_axif_page_waddress;
logic [TABLE_ADDR_WIDTH-1:0] original_axif_page_raddress;
logic [31:0] translated_axif_page_waddress;
logic [31:0] translated_axif_page_raddress;
logic write_address_translation;
logic read_address_translation;
logic [31:0] write_data;
logic write_enable_reg;
logic write_enable_mem;
logic memory_write_select;
logic read_req_reg;
logic read_req_reg_d1;
logic read_req_mem;
logic read_req_mem_d1;
logic axil_read_data_valid;
logic [31:0] axil_read_data;
logic [31:0] mem_read_data;
logic round_robin_req;
logic allow_axif_read_req;
logic allow_axif_write_req;

logic axil_received_write_address;


assign memory_size = allocated_mem_size;
assign hw_credit_value = credit_value;
assign increment_hw_credit = increment_credit;
assign reset_interface = reset_interface_r;

assign axi_lite_user.awready = ~axil_received_write_address;
assign axi_lite_user.wready = axil_received_write_address;
assign axi_lite_user.bid = '0;
assign axi_lite_user.bresp = '0;
assign axi_lite_user.buser = '0;
assign axi_lite_user.bvalid = 1'b1;
assign axi_lite_user.arready = 1'b1;
assign axi_lite_user.rid = '0;
assign axi_lite_user.rdata = axil_read_data;
assign axi_lite_user.rresp = '0;
assign axi_lite_user.ruser = '0;
assign axi_lite_user.rvalid = axil_read_data_valid;

assign axi_full_to_host.arlock = '0;
assign axi_full_to_host.arcache = '0;
assign axi_full_to_host.arprot = '0;
assign axi_full_to_host.arqos = '0;

assign axi_full_from_app.arready = axi_full_to_host.arready & allow_axif_read_req;
assign axi_full_to_host.arid    = axi_full_from_app.arid;
assign axi_full_to_host.araddr  = {translated_axif_page_raddress,axi_full_from_app.araddr[11:0]};
assign axi_full_to_host.aruser  = axi_full_from_app.aruser;
assign axi_full_to_host.arregion= axi_full_from_app.arregion;
assign axi_full_to_host.arlen   = axi_full_from_app.arlen;
assign axi_full_to_host.arsize  = axi_full_from_app.arsize;
assign axi_full_to_host.arburst = axi_full_from_app.arburst;
assign axi_full_to_host.arvalid = axi_full_from_app.arvalid & allow_axif_read_req;

assign axi_full_to_host.rready  = axi_full_from_app.rready;
assign axi_full_from_app.rid    = axi_full_to_host.rid;
assign axi_full_from_app.rdata  = axi_full_to_host.rdata;
assign axi_full_from_app.rresp  = axi_full_to_host.rresp;
assign axi_full_from_app.rlast  = axi_full_to_host.rlast;
assign axi_full_from_app.ruser  = axi_full_to_host.ruser;
assign axi_full_from_app.rvalid = axi_full_to_host.rvalid;


assign watchdog_timeout = (watchdog_timer == WATCHDOG_TIMOUT_VALUE);
assign interface_is_active = page_table_active;

assign allow_axif_read_req = (axi_full_from_app.araddr[12+:TABLE_ADDR_WIDTH] == original_axif_page_raddress) & page_table_active;
assign allow_axif_write_req = (axi_full_from_app.awaddr[12+:TABLE_ADDR_WIDTH] == original_axif_page_waddress) & page_table_active;

always_ff @(posedge clk) begin
    if(reset) begin
        write_enable_reg <= 1'b0;
        write_enable_mem <= 1'b0;
        round_robin_req <= 1'b0;
        axil_received_write_address <= 1'b0;
    end else begin
        write_enable_reg <= axi_lite_user.wvalid & axil_received_write_address & ~memory_write_select;
        write_enable_mem <= axi_lite_user.wvalid & axil_received_write_address & memory_write_select;
        round_robin_req <= ~round_robin_req;
        axil_received_write_address <= (axil_received_write_address)? ~axi_lite_user.wvalid : axi_lite_user.awvalid;
    end
    write_data <= axi_lite_user.wdata;
    memory_write_select <= (axi_lite_user.awvalid & ~axil_received_write_address)? axi_lite_user.awaddr[16] : memory_write_select;
    write_address <= (axi_lite_user.awvalid & ~axil_received_write_address)? axi_lite_user.awaddr[2+:TABLE_ADDR_WIDTH] : write_address;
    read_address <= (axi_lite_user.arvalid)? axi_lite_user.araddr[2+:TABLE_ADDR_WIDTH] : read_address;
    read_req_reg <= axi_lite_user.arvalid & ~axi_lite_user.araddr[16];
    read_req_reg_d1 <= read_req_reg;
    read_req_mem <= axi_lite_user.arvalid & axi_lite_user.araddr[16];
    read_req_mem_d1 <= read_req_mem;
    axil_read_data_valid <= read_req_reg_d1 | read_req_mem_d1;
    axil_read_data <= (read_req_mem_d1)? mem_read_data : selected_read_reg;
    memory_read_address_d1 <= memory_read_address;

    write_address_translation <= ~read_req_mem & round_robin_req;
    read_address_translation <= ~read_req_mem & ~round_robin_req;
    original_axif_page_waddress <= (write_address_translation)? memory_read_address_d1 : original_axif_page_waddress;
    original_axif_page_raddress <= (read_address_translation)? memory_read_address_d1 : original_axif_page_raddress;
    translated_axif_page_waddress <= (write_address_translation)? mem_read_data : translated_axif_page_waddress;
    translated_axif_page_raddress <= (read_address_translation)? mem_read_data : translated_axif_page_raddress;
end

assign memory_read_address = (read_req_mem)? read_address :
                             (round_robin_req)? axi_full_from_app.awaddr[12+:TABLE_ADDR_WIDTH] : axi_full_from_app.araddr[12+:TABLE_ADDR_WIDTH];

sync_sdp_sram #(
    .ADDRESS_WIDTH(TABLE_ADDR_WIDTH),
    .DATA_WIDTH(32),
    .BYTE_WRITE_WIDTH(32),
    .READ_LATENCY(1)
) page_table_memory_inst
  (
    .clk(clk),
    .wr_enable(write_enable_mem),
    .wr_address(write_address),
    .wr_data(write_data),
    .rd_address(memory_read_address),
    .rd_data(mem_read_data)
 );

 always_ff @(posedge clk) begin
    if(reset) begin
        watchdog_timer <= WATCHDOG_TIMOUT_VALUE;
        page_table_active <= 1'b0;
        allocated_mem_size <= '0;
        increment_credit <= 1'b0;
        reset_interface_r <= 1'b1;
    end else begin
        watchdog_timer <= (write_enable_reg & (write_address == 6'd1))? '0 :
                          (watchdog_timeout)? watchdog_timer : watchdog_timer + 1'b1;
        page_table_active <= (write_enable_reg & (write_address == 6'd2))? write_data[0] :
                             (watchdog_timeout)? 1'b0 : page_table_active;
        allocated_mem_size <= (write_enable_reg & (write_address == 6'd4))? write_data : allocated_mem_size;
        increment_credit <= write_enable_reg & (write_address == 6'd7);
        reset_interface_r <= write_enable_reg & (write_address == 6'd8);
    end
    credit_value <= (write_enable_reg & (write_address == 6'd7))? write_data : credit_value;
    debug_regs <= debug_inputs;
    selected_read_reg <= (|read_address[TABLE_ADDR_WIDTH-1:4])? debug_regs[read_address-16] : selected_read_c;

end

always_comb begin
    case(read_address[3:0])
        'd0 : selected_read_c = 32'hADECEBE1;
        'd1 : selected_read_c = watchdog_timer;
        'd2 : selected_read_c = {31'd0,page_table_active};
        'd3 : selected_read_c = MAX_NUM_PAGES;
        'd4 : selected_read_c = allocated_mem_size;
        'd5 : selected_read_c = current_hw_address;
        'd6 : selected_read_c = remaining_hw_credit;
        'd7 : selected_read_c = credit_value;
        'd8 : selected_read_c = '0;
        default : selected_read_c = 32'hDEADBEEF;
    endcase
end

endmodule
