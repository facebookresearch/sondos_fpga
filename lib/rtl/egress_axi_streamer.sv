// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

module egress_axi_streamer
import so_axi4_if_pkg::*,so_axi4s_if_pkg::*;
  (
    input host_clk,
    input user_clk,
    input ext_host_reset, // this is the external reset, SW can also issue a reset through the axi_lite reset register in the page table
    so_axi4_if.master_read axi_full_to_host,
    so_axi4l_if.slave axi_lite_from_host,

    so_axi4s_if.master axi_stream_to_user
 );

localparam logic [31:0] MAGIC_WORD_0 = 32'hCAFE_2023;
localparam logic [31:0] MAGIC_WORD_1 = 32'hFACE_B00C;
localparam int DATA_FIFO_DEPTH = 512;
localparam int DATA_FIFO_THRESHOLD = 100; // If output is not taken and we have more than 100 entries we stall
localparam int C_TUSER_WIDTH = 32; // force 32-bit for easy parsing
localparam int C_TID_WIDTH = 32; // force 32-bit for easy parsing
localparam int C_TIMESTAMP_WIDTH = 32; // force 32-bit for easy parsing
localparam int C_HEADER_PAD = 320 - C_TUSER_WIDTH - C_TID_WIDTH - C_TIMESTAMP_WIDTH;

typedef struct packed {
    logic [C_TUSER_WIDTH-1:0] tuser;
    logic [C_TID_WIDTH-1:0] tid;
    logic [511:0] tdata;
    logic [63:0] tkeep;
    logic tlast;
} axis_signals_t;


typedef struct packed {
    logic [31:0] magic_word_1;
    logic [C_HEADER_PAD-1:0] dummy_1;
    logic [C_TIMESTAMP_WIDTH-1:0] timestamp;
    logic [C_TID_WIDTH-1:0] tid;
    logic [C_TUSER_WIDTH-1:0] tuser;
    logic [63:0] tkeep;
    logic [31:0] number_of_words;
    logic [31:0] packet_id;
    logic [31:0] magic_word_0;
} header_format_t;

/////////////////////////////////// user side signals ////////////////////////////////
logic reset_user_side;

logic fifo_empty;
logic fifo_rd_rst_busy;
logic fifo_read;
axis_signals_t fifo_data_out;

logic [15:0][31:0] debug_data;

/////////////////////////////////// host side signals ////////////////////////////////

logic reset_interface;
logic reset_host_side;

header_format_t parsed_header;

axis_signals_t fifo_data_in;
logic fifo_write;
logic fifo_wr_rst_busy;
logic fifo_full;
logic fifo_prog_full;
logic fifo_ready;

logic [7:0] command_length;
logic command_valid;


logic [31:0] packet_id;
logic [31:0] number_of_words;
logic        expecting_header;
logic        correct_header;
logic [63:0] axis_tkeep;
logic [C_TUSER_WIDTH-1:0] axis_tuser;
logic [C_TID_WIDTH-1:0] axis_tid;
logic unsigned [C_TIMESTAMP_WIDTH-1:0] timestamp;
logic [31:0] header_mismatch_count;

logic [8:0] pending_data_counter;

logic [31:0] rresp_err_counter;
logic [31:0] rresp_err_last;

logic last_page;
logic [31:0] buffer_size;
logic [5:0] read_length;

so_axi4_if #(C_SO_AXI4_A64_D512) axi_full_virtual (.aclk(host_clk), .aresetn(~reset_host_side));


logic [31:0] axif_read_address;
logic [31:0] available_hw_credit;
logic add_credit;
logic [31:0] credit_to_add;


logic end_of_page;
logic page_overflow_detected;
logic [6:0] check_page_overflow;
logic [5:0] available_read_size;

logic end_of_buffer;
logic command_taken;
logic data_arrived;
logic ready_for_command;


/////////////////////////////////////////////////////////////////////////////////////////////////////////
localparam so_axi4s_if_param_t C_SO_AXI4S_D512_USER = '{
    ID       : C_TID_WIDTH,
    DATA     : 64,
    DEST     : 1,
    USER     : C_TUSER_WIDTH,
    HAS_ID   : 1,
    HAS_DEST : 0,
    HAS_USER : 1
};
so_axi4s_if #(C_SO_AXI4S_D512_USER) internal_512b_axi4s (.aclk(user_clk), .aresetn(~reset_user_side));

//###################################################################
//######################## user side logic ##########################
//###################################################################

xpm_cdc_sync_rst #(
   .DEST_SYNC_FF(4),   // DECIMAL; range: 2-10
   .INIT(1))
xpm_cdc_sync_rst_inst (
   .dest_rst(reset_user_side),
   .dest_clk(user_clk),
   .src_rst(reset_interface)
);

assign fifo_read = internal_512b_axi4s.tvalid & internal_512b_axi4s.tready;

assign internal_512b_axi4s.tvalid = ~fifo_empty;
assign internal_512b_axi4s.tdata = fifo_data_out.tdata;
assign internal_512b_axi4s.tlast = fifo_data_out.tlast;
assign internal_512b_axi4s.tkeep = fifo_data_out.tkeep;
assign internal_512b_axi4s.tuser = fifo_data_out.tuser;
assign internal_512b_axi4s.tid   = fifo_data_out.tid;


//###################################################################
//######################## host side logic ##########################
//###################################################################

assign reset_host_side = reset_interface;

assign parsed_header = axi_full_virtual.rdata;

assign command_taken = axi_full_virtual.arvalid & axi_full_virtual.arready;
assign data_arrived = axi_full_virtual.rvalid;
assign end_of_buffer = last_page & end_of_page;
assign end_of_page = check_page_overflow[6] | (&check_page_overflow[5:0]);
assign page_overflow_detected = check_page_overflow[6];
assign check_page_overflow = axif_read_address[11:6] + available_read_size;
assign available_read_size = (|available_hw_credit[31:5])? 6'd31: available_hw_credit[4:0] - 1'b1;

assign fifo_data_in.tdata = axi_full_virtual.rdata;
assign fifo_data_in.tlast = (number_of_words==32'd1);
assign fifo_data_in.tkeep = (number_of_words==32'd1)? axis_tkeep : {64{1'b1}};
assign fifo_data_in.tuser = axis_tuser;
assign fifo_data_in.tid   = axis_tid;

assign fifo_write = axi_full_virtual.rvalid & ~expecting_header;

assign correct_header = (parsed_header.magic_word_0 == MAGIC_WORD_0) & (parsed_header.magic_word_1 == MAGIC_WORD_1) & (parsed_header.packet_id == packet_id);

assign axi_full_virtual.arid    = '0;
assign axi_full_virtual.araddr  = axif_read_address;
assign axi_full_virtual.aruser  = '0;
assign axi_full_virtual.arregion= '0;
assign axi_full_virtual.arlen   = command_length;
assign axi_full_virtual.arsize  = 3'b110;
assign axi_full_virtual.arburst = 2'b01;
assign axi_full_virtual.arvalid = command_valid;

assign axi_full_virtual.rready  = 1'b1;


assign debug_data[ 0] = packet_id;
assign debug_data[ 1] = header_mismatch_count;
assign debug_data[ 2] = number_of_words;
assign debug_data[ 3] = expecting_header;
assign debug_data[ 4] = pending_data_counter;
assign debug_data[ 5] = axi_full_to_host.araddr[31:0];
assign debug_data[ 6] = axi_full_to_host.araddr[63:32];
assign debug_data[ 7] = {axi_full_to_host.arready, axi_full_to_host.arvalid, axi_full_to_host.rready, axi_full_to_host.rvalid};
assign debug_data[ 8] = axi_full_virtual.araddr[31:0];
assign debug_data[ 9] = axi_full_virtual.araddr[63:32];
assign debug_data[10] = {axi_full_virtual.arready, axi_full_virtual.arvalid, axi_full_virtual.rready, axi_full_virtual.rvalid};
assign debug_data[11] = rresp_err_counter;
assign debug_data[12] = rresp_err_last;

always_ff @(posedge host_clk) begin
    if(reset_host_side) begin
        packet_id <= '0;
        command_valid<= 1'b0;
        ready_for_command <= 1'b0;
        expecting_header <= 1'b1;
        header_mismatch_count <= '0;
        number_of_words <= '0;
        axif_read_address <= '0;
        pending_data_counter <= '0;
        rresp_err_counter <= '0;
        available_hw_credit <= '0;
        last_page <= 1'b0;
        fifo_ready <= 1'b0;
        read_length <= 6'd0;
    end else begin

        packet_id <= ((number_of_words==32'd1) & axi_full_virtual.rvalid & ~expecting_header)? packet_id + 1'b1 : packet_id;
        command_valid <= (command_valid)? ~command_taken : fifo_ready & (|available_hw_credit) & ready_for_command & ~(&pending_data_counter[8:7]);
        // command valid is rate limited by design to be asserted at most once every 3 cycles to
        // allow for couple of cycles tp perform the length computation and credit update
        // a new command is created only when there is available credit, the pending data counter is less than 384 words (checking bits 8 & 7) and
        // the data fifo is not almost full (have at least 412 words of unused space to account for maximum pending data)
        ready_for_command <= ~(command_taken | add_credit);
        expecting_header <= (expecting_header)? ~(axi_full_virtual.rvalid & correct_header) : (number_of_words==32'd1) & axi_full_virtual.rvalid;
        header_mismatch_count <= (expecting_header & axi_full_virtual.rvalid & ~correct_header)? header_mismatch_count + 1'b1 : header_mismatch_count;
        number_of_words <= (expecting_header)? parsed_header.number_of_words :
                           (axi_full_virtual.rvalid)? number_of_words - 1'b1 : number_of_words;
        axif_read_address <= (command_taken & end_of_buffer)? 'd0:
                             (command_taken)? axif_read_address + {23'd0,command_length,6'd0} + 32'd64 : axif_read_address;
        pending_data_counter <= (command_taken)? pending_data_counter + command_length + {7'd0,(~data_arrived)} : pending_data_counter - data_arrived;
        available_hw_credit <= (add_credit & command_taken)? available_hw_credit + credit_to_add + {{24{1'b1}},(~command_length)}:
                               (add_credit)? available_hw_credit + credit_to_add:
                               (command_taken)? available_hw_credit + {{24{1'b1}},(~command_length)}: available_hw_credit;
        last_page <= (axif_read_address[31:12]==buffer_size[31:12]);
        fifo_ready <= ~(fifo_prog_full | fifo_wr_rst_busy);
        read_length <= (page_overflow_detected)? ~axif_read_address[11:6] : available_read_size;

        rresp_err_counter <= ((axi_full_to_host.rresp != '0) && axi_full_to_host.rvalid && axi_full_to_host.rready) ? rresp_err_counter + 1'b1 :
                                                                                                                      rresp_err_counter;
        rresp_err_last    <= ((axi_full_to_host.rresp != '0) && axi_full_to_host.rvalid && axi_full_to_host.rready) ? axi_full_to_host.rresp :
                                                                                                                      rresp_err_last;
    end
    axis_tkeep <= (expecting_header)? parsed_header.tkeep : axis_tkeep;
    axis_tuser <= (expecting_header)? parsed_header.tuser : axis_tuser;
    axis_tid   <= (expecting_header)? parsed_header.tid   : axis_tid;
    command_length <= (command_valid)? command_length : read_length;
end




// Inline same-width passthrough (was um_axi4s_resize axi4s_resize_unit).
    // OSS release fixes AXI4-Stream width at 512 bits — no resize logic needed.
    always_comb begin
        axi_stream_to_user.tvalid = internal_512b_axi4s.tvalid;
        axi_stream_to_user.tdata  = internal_512b_axi4s.tdata;
        axi_stream_to_user.tstrb  = internal_512b_axi4s.tstrb;
        axi_stream_to_user.tkeep  = internal_512b_axi4s.tkeep;
        axi_stream_to_user.tlast  = internal_512b_axi4s.tlast;
        axi_stream_to_user.tid    = internal_512b_axi4s.tid;
        axi_stream_to_user.tdest  = internal_512b_axi4s.tdest;
        axi_stream_to_user.tuser  = internal_512b_axi4s.tuser;
        internal_512b_axi4s.tready = axi_stream_to_user.tready;
    end


xpm_fifo_async #(
   .FIFO_MEMORY_TYPE("block"),
   .FIFO_READ_LATENCY(0),
   .FIFO_WRITE_DEPTH(DATA_FIFO_DEPTH),
   .PROG_FULL_THRESH(DATA_FIFO_THRESHOLD),
   .RD_DATA_COUNT_WIDTH(1),
   .READ_DATA_WIDTH($bits(axis_signals_t)),
   .READ_MODE("fwft"),
   .USE_ADV_FEATURES("0002"), // enabling programmable full signal
   .WRITE_DATA_WIDTH($bits(axis_signals_t))
)
data_fifo (
   .almost_empty(),
   .almost_full(),
   .data_valid(),
   .dbiterr(),
   .dout(fifo_data_out),
   .empty(fifo_empty),
   .full(fifo_full),
   .overflow(),
   .prog_empty(),
   .prog_full(fifo_prog_full),
   .rd_data_count(),
   .rd_rst_busy(fifo_rd_rst_busy),
   .sbiterr(),
   .underflow(),
   .wr_ack(),
   .wr_data_count(),
   .wr_rst_busy(fifo_wr_rst_busy),
   .din(fifo_data_in),
   .injectdbiterr(1'b0),
   .injectsbiterr(1'b0),
   .rd_en(fifo_read),
   .rst(reset_host_side),
   .sleep(1'b0),
   .wr_clk(host_clk),
   .rd_clk(user_clk),
   .wr_en(fifo_write)
);


page_translation_stage_read #(.NUM_DEBUG_REGS(16)) page_translation_unit(
    .clk(host_clk),
    .reset(ext_host_reset),
    .interface_is_active(),
    .memory_size(buffer_size),
    .current_hw_address(axif_read_address),
    .remaining_hw_credit(available_hw_credit),
    .hw_credit_value(credit_to_add),
    .increment_hw_credit(add_credit),
    .reset_interface(reset_interface),
    .debug_inputs(debug_data),
    .axi_full_from_app(axi_full_virtual),
    .axi_full_to_host(axi_full_to_host),
    .axi_lite_user(axi_lite_from_host)
 );


endmodule
