// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

module ingress_axi_streamer
import so_axi4_if_pkg::*,so_axi4s_if_pkg::*;
  #(
   parameter int MAX_NUM_PAGES = 8*1024,
   parameter int P_USER_CLKS_PER_US = 244,
   parameter int P_TIMESTAMP_WIDTH = 32 // force 32-bit for easy parsing
  ) (
    input host_clk,
    input user_clk,
    input ext_host_reset, // this is the external reset, SW can also issue a reset through the axi_lite reset register in the page table
    so_axi4_if.master_write axi_full_to_host,
    so_axi4l_if.slave axi_lite_from_host,

    so_axi4s_if.slave axi_stream_from_user,
    output logic streaming_enabled,
    output logic unsigned [P_TIMESTAMP_WIDTH-1:0] timestamp
 );

localparam int AXIF_DATAWIDTH = 512;
localparam logic [31:0] MAGIC_WORD_0 = 32'hCAFE_2023;
localparam logic [31:0] MAGIC_WORD_1 = 32'hFACE_B00C;
localparam int DATA_FIFO_DEPTH = 512;
localparam int DATA_FIFO_THRESHOLD = 500;
localparam int COMMAND_FIFO_DEPTH = 64;
localparam int COMMAND_FIFO_THRESHOLD = 58;
localparam int C_TUSER_WIDTH = 32; // force 32-bit for easy parsing
localparam int C_TID_WIDTH = 32; // force 32-bit for easy parsing
localparam int C_HEADER_PAD = 320 - C_TUSER_WIDTH - C_TID_WIDTH - P_TIMESTAMP_WIDTH;

typedef struct packed {
    logic is_header;
    logic [5:0] length;
} command_data_t;

/////////////////////////////////// user side signals ////////////////////////////////

logic reset_user_side;

logic [31:0] packet_id;
logic [31:0] number_of_words;
logic [4:0]  beat_count;
logic [4:0]  command_length_count;
logic [63:0] axis_tkeep;
logic [C_TUSER_WIDTH-1:0] axis_tuser;
logic [C_TID_WIDTH-1:0] axis_tid;
logic unsigned [P_TIMESTAMP_WIDTH-1:0] timestamp_host_clk;
logic write_header_to_fifo;

logic [AXIF_DATAWIDTH:0] fifo_data_in;
logic fifo_write;
logic fifo_wr_rst_busy;
logic fifo_full;
logic fifo_prog_full;
logic fifo_ready;

command_data_t cmd_fifo_data_in;
logic cmd_fifo_write;
logic cmd_fifo_wr_rst_busy;
logic cmd_fifo_full;
logic cmd_fifo_prog_full;

logic [3:0][31:0] debug_data;

logic [14:0] us_counter; // Count for one microsecond

/////////////////////////////////// host side signals ////////////////////////////////

logic reset_interface;
logic reset_host_side;

logic fifo_empty;
logic fifo_rd_rst_busy;
logic fifo_read;
logic [AXIF_DATAWIDTH:0] fifo_data_out;

logic cmd_fifo_empty;
logic cmd_fifo_rd_rst_busy;
logic cmd_fifo_read;
command_data_t cmd_fifo_data_out;

logic enable_streaming;
logic [6:0] word_counter;
(*mark_debug="true",keep="true"*) logic [7:0] pending_writes;
logic last_page;
logic [31:0] buffer_size;
(*mark_debug="true",keep="true"*) logic [31:0] available_hw_credit;
logic add_credit;
logic [31:0] credit_to_add;

so_axi4_if #(C_SO_AXI4_A64_D512) axi_full_virtual (.aclk(host_clk), .aresetn(~reset_host_side));


logic [31:0] axif_data_write_address;
logic [31:0] axif_header_write_address;
logic [15:0] word_stamp;
(*mark_debug="true",keep="true"*) logic [7:0] pending_data_counter;
logic [6:0] check_page_overflow;

logic end_of_page;
logic page_overflow_detected;
logic command_taken;
logic data_taken;
(*mark_debug="true",keep="true"*) logic command_just_sent;

(*mark_debug="true",keep="true"*) logic waiting_to_write_eop_word;
logic split_write_command;
logic [5:0] split_write_command_length;

logic [3:0][31:0] debug_data_sync;
logic sync_handshake_req;
logic sync_handshake_resp;

(*mark_debug="true",keep="true"*) logic axi_full_virtual_awvalid;
assign axi_full_virtual_awvalid = axi_full_virtual.awvalid;

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
always_ff @(posedge user_clk) begin
   if (reset_user_side) begin
      us_counter <= P_USER_CLKS_PER_US-1;
      timestamp <= 0;
   end else begin
      if (us_counter == 0) begin
         us_counter <= P_USER_CLKS_PER_US-1;
         timestamp <= timestamp + 1;
      end else begin
         us_counter <= us_counter - 1;
      end
   end
end

xpm_cdc_sync_rst #(
   .DEST_SYNC_FF(4),   // DECIMAL; range: 2-10
   .INIT(1))
xpm_cdc_sync_rst_inst (
   .dest_rst(reset_user_side),
   .dest_clk(user_clk),
   .src_rst(reset_interface)
);

xpm_cdc_single #(
   .DEST_SYNC_FF(4),   // DECIMAL; range: 2-10
   .INIT_SYNC_FF(0),   // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
   .SRC_INPUT_REG(1)   // DECIMAL; 0=do not register input, 1=register input
)
enable_streaming_cdc_inst (
   .dest_out(streaming_enabled),
   .dest_clk(user_clk),
   .src_clk(host_clk),
   .src_in(enable_streaming)
);

assign fifo_write = (internal_512b_axi4s.tvalid | write_header_to_fifo) & fifo_ready;
assign cmd_fifo_write = fifo_write & (internal_512b_axi4s.tlast | write_header_to_fifo | (&beat_count));
assign internal_512b_axi4s.tready = fifo_ready & ~write_header_to_fifo;
assign fifo_data_in = (write_header_to_fifo)?
    {1'b1,MAGIC_WORD_1,{C_HEADER_PAD{1'b0}},timestamp,axis_tid,axis_tuser,axis_tkeep,number_of_words,packet_id,MAGIC_WORD_0} :
    {cmd_fifo_write,internal_512b_axi4s.tdata};
assign cmd_fifo_data_in.is_header = write_header_to_fifo;
assign cmd_fifo_data_in.length = (write_header_to_fifo)? 6'd0 : command_length_count;

 always_ff @(posedge user_clk) begin
    if(reset_user_side) begin
        write_header_to_fifo <= 1'b0;
        packet_id <= '0;
        number_of_words <= '0;
        beat_count <= 1;
        command_length_count <= 0;
        fifo_ready <= '0;
    end else begin
        write_header_to_fifo <= (write_header_to_fifo)? ~fifo_ready : internal_512b_axi4s.tvalid & internal_512b_axi4s.tlast & fifo_ready;
        packet_id <= (write_header_to_fifo & fifo_ready)? packet_id + 1'b1 : packet_id;
        number_of_words <= (write_header_to_fifo & fifo_ready)? '0:
                           (internal_512b_axi4s.tvalid & fifo_ready)? number_of_words + 1'b1: number_of_words;
        beat_count <= (write_header_to_fifo & fifo_ready)? beat_count+1 :
                      (internal_512b_axi4s.tvalid & fifo_ready)? beat_count + 1'b1: beat_count;
        command_length_count <= (cmd_fifo_write)? 0 :
                                (internal_512b_axi4s.tvalid & fifo_ready)? command_length_count + 1 : command_length_count;
        fifo_ready <= ~(cmd_fifo_prog_full | cmd_fifo_wr_rst_busy | fifo_prog_full | fifo_wr_rst_busy);
    end
    // Store the TID on the last beat of a transfer
    axis_tid <= (internal_512b_axi4s.tvalid & internal_512b_axi4s.tlast & fifo_ready) ? internal_512b_axi4s.tid : axis_tid;
    axis_tkeep <= (internal_512b_axi4s.tvalid & internal_512b_axi4s.tlast & fifo_ready)? internal_512b_axi4s.tkeep : axis_tkeep;
    // Logically OR all beat TUSER values per packet so that the header will capture the TUSER value
    axis_tuser <= (write_header_to_fifo & fifo_ready)? '0 : (internal_512b_axi4s.tvalid & fifo_ready)? internal_512b_axi4s.tuser | axis_tuser : axis_tuser;
end

always_ff @(posedge user_clk) begin
    if(reset_user_side) begin
        debug_data <= '0;
        sync_handshake_req <= 1'b0;
    end else begin
        debug_data[0] <= packet_id;
        debug_data[1] <= debug_data[1] + (internal_512b_axi4s.tvalid & internal_512b_axi4s.tready);
        debug_data[2] <= debug_data[2] + (axi_stream_from_user.tvalid & axi_stream_from_user.tready);
        debug_data[3] <= {internal_512b_axi4s.tvalid,internal_512b_axi4s.tready,axi_stream_from_user.tvalid,axi_stream_from_user.tready};
        sync_handshake_req <= ~sync_handshake_resp;
    end
end
xpm_cdc_handshake #(
   .DEST_EXT_HSK(0),
   .DEST_SYNC_FF(3),
   .SRC_SYNC_FF(3),
   .WIDTH($bits(debug_data)+P_TIMESTAMP_WIDTH)
)
xpm_cdc_handshake_inst (
   .dest_out({timestamp_host_clk, debug_data_sync}),
   .dest_req(),
   .src_rcv(sync_handshake_resp),
   .dest_ack(),
   .dest_clk(host_clk),
   .src_clk(user_clk),
   .src_in({timestamp, debug_data}),
   .src_send(sync_handshake_req)
);
//###################################################################
//######################## host side logic ##########################
//###################################################################

assign reset_host_side = reset_interface; // reset needs to be handled correctly to avoid stalling the AXI full interface to the hoost

assign command_taken = axi_full_virtual.awvalid & axi_full_virtual.awready;
assign data_taken = axi_full_virtual.wvalid & axi_full_virtual.wready;
assign end_of_page = page_overflow_detected | (&check_page_overflow[5:0]);
assign page_overflow_detected = check_page_overflow[6];
assign check_page_overflow = axif_data_write_address[11:6] + cmd_fifo_data_out.length;

assign fifo_read = data_taken;
assign cmd_fifo_read = command_taken & ~page_overflow_detected;

assign axi_full_virtual.awid    = '0;
assign axi_full_virtual.awaddr  = (cmd_fifo_data_out.is_header)? {axif_header_write_address[31:6],6'd0} : {axif_data_write_address[31:6],6'd0};
assign axi_full_virtual.awregion= '0;
assign axi_full_virtual.awlen   = (split_write_command)? split_write_command_length :
                                  (page_overflow_detected)? {1'b0,(~axif_data_write_address[11:6])} : cmd_fifo_data_out.length;
assign axi_full_virtual.awsize  = 3'b110;
assign axi_full_virtual.awburst = 2'b01;
assign axi_full_virtual.awvalid = enable_streaming & (~cmd_fifo_empty) &
                                  ~(waiting_to_write_eop_word | pending_writes[7] | pending_data_counter[7] | available_hw_credit[31] | command_just_sent);
// A command can be sent when the all following options are satisfied:
//      - Streaming is enabled and command FIFO is not empty
//      - HW credit is not negative (0 or positive)
//      - No back to back commands fastest is every 2 cycle
//      - pending data on wdata channel is less than 128 words
//      - pending writes (awaiting response) are less than 16
// on top of that when a write operation crosses the page boundary the design will split the command into 2 commands and flush all data
// between the first and the second command, flushing is just an artifact of the design and would be removed in the next revision

assign axi_full_virtual.awuser  = '0;

assign axi_full_virtual.wdata   = fifo_data_out[511:0];
assign axi_full_virtual.wstrb   = 64'hFFFFFFFFFFFFFFFF;
assign axi_full_virtual.wlast   = (waiting_to_write_eop_word & (pending_data_counter==8'd1))? 1'b1 : fifo_data_out[512];
assign axi_full_virtual.wvalid  = |pending_data_counter;
assign axi_full_virtual.wuser   = '0;

assign axi_full_virtual.bready  = 1'b1;

 always_ff @(posedge host_clk) begin
    if(reset_host_side) begin
        waiting_to_write_eop_word<= 1'b0;
        command_just_sent <= 1'b0;
        axif_header_write_address <= '0;
        axif_data_write_address <= 32'd64;
        pending_data_counter <= '0;
        available_hw_credit <= '1;
        last_page <= 1'b0;
        pending_writes <= '0;
        split_write_command <= '0;
        split_write_command_length <= '0;
    end else begin
        waiting_to_write_eop_word<= (waiting_to_write_eop_word)? |pending_data_counter : command_taken & page_overflow_detected;
        command_just_sent <= command_taken;
        axif_header_write_address <= (command_taken & cmd_fifo_data_out.is_header)? axif_data_write_address : axif_header_write_address;
        axif_data_write_address <= (command_taken & end_of_page & last_page)? 'd0:
                                   (command_taken & end_of_page)? {(axif_data_write_address[31:12] + 1'b1),12'd0}:
                                   (command_taken)? axif_data_write_address + {axi_full_virtual.awlen,6'd0} + 7'd64 : axif_data_write_address;
        pending_data_counter <= (command_taken)? pending_data_counter + axi_full_virtual.awlen + {1'b0,~data_taken} :
                                                 pending_data_counter - data_taken ;
        available_hw_credit <= (add_credit & command_taken)? available_hw_credit + credit_to_add + {{24{1'd1}},(~axi_full_virtual.awlen)}:
                               (add_credit)? available_hw_credit + credit_to_add:
                               (command_taken)? available_hw_credit + {{24{1'd1}},(~axi_full_virtual.awlen)}: available_hw_credit;
        last_page <= (axif_data_write_address[31:12]==buffer_size[31:12]);
        pending_writes <= (command_taken & ~axi_full_virtual.bvalid)? pending_writes + 1'b1 :
                          (axi_full_virtual.bvalid & ~command_taken)? pending_writes - 1'b1 : pending_writes;
        split_write_command <= (split_write_command)? ~command_taken : command_taken & page_overflow_detected;
        split_write_command_length <= (split_write_command)? split_write_command_length : cmd_fifo_data_out.length + axif_data_write_address[11:6];

    end
end



// Inline same-width passthrough (was um_axi4s_resize axi4s_resize_unit).
// OSS release fixes AXI4-Stream width at 512 bits — no resize logic needed.
always_comb begin
    internal_512b_axi4s.tvalid = axi_stream_from_user.tvalid;
    internal_512b_axi4s.tdata  = axi_stream_from_user.tdata;
    internal_512b_axi4s.tstrb  = axi_stream_from_user.tstrb;
    internal_512b_axi4s.tkeep  = axi_stream_from_user.tkeep;
    internal_512b_axi4s.tlast  = axi_stream_from_user.tlast;
    internal_512b_axi4s.tid    = axi_stream_from_user.tid;
    internal_512b_axi4s.tdest  = axi_stream_from_user.tdest;
    internal_512b_axi4s.tuser  = axi_stream_from_user.tuser;
    axi_stream_from_user.tready = internal_512b_axi4s.tready;
end


xpm_fifo_async #(
   .FIFO_MEMORY_TYPE("block"),
   .FIFO_READ_LATENCY(0),
   .FIFO_WRITE_DEPTH(DATA_FIFO_DEPTH),
   .PROG_FULL_THRESH(DATA_FIFO_THRESHOLD),
   .RD_DATA_COUNT_WIDTH(1),
   .READ_DATA_WIDTH(AXIF_DATAWIDTH+1),
   .READ_MODE("fwft"),
   .USE_ADV_FEATURES("0002"), // enabling programmable full signal
   .WRITE_DATA_WIDTH(AXIF_DATAWIDTH+1)
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
   .rst(reset_user_side),
   .sleep(1'b0),
   .wr_clk(user_clk),
   .rd_clk(host_clk),
   .wr_en(fifo_write)
);


xpm_fifo_async #(
   .FIFO_MEMORY_TYPE("auto"),
   .FIFO_READ_LATENCY(0),
   .FIFO_WRITE_DEPTH(COMMAND_FIFO_DEPTH),
   .PROG_FULL_THRESH(COMMAND_FIFO_THRESHOLD),
   .RD_DATA_COUNT_WIDTH(1),
   .READ_DATA_WIDTH($size(command_data_t)),
   .READ_MODE("fwft"),
   .USE_ADV_FEATURES("0002"), // enabling programmable full signal
   .WRITE_DATA_WIDTH($size(command_data_t))
)
command_fifo (
   .almost_empty(),
   .almost_full(),
   .data_valid(),
   .dbiterr(),
   .dout(cmd_fifo_data_out),
   .empty(cmd_fifo_empty),
   .full(cmd_fifo_full),
   .overflow(),
   .prog_empty(),
   .prog_full(cmd_fifo_prog_full),
   .rd_data_count(),
   .rd_rst_busy(cmd_fifo_rd_rst_busy),
   .sbiterr(),
   .underflow(),
   .wr_ack(),
   .wr_data_count(),
   .wr_rst_busy(cmd_fifo_wr_rst_busy),
   .din(cmd_fifo_data_in),
   .injectdbiterr(1'b0),
   .injectsbiterr(1'b0),
   .rd_en(cmd_fifo_read),
   .rst(reset_user_side),
   .sleep(1'b0),
   .wr_clk(user_clk),
   .rd_clk(host_clk),
   .wr_en(cmd_fifo_write)
);

page_translation_stage_write #(
   .NUM_DEBUG_REGS(4),
   .MAX_NUM_PAGES(MAX_NUM_PAGES)
) page_translation_unit(
    .clk(host_clk),
    .reset(ext_host_reset),
    .interface_is_active(enable_streaming),
    .memory_size(buffer_size),
    .current_hw_address(axif_data_write_address),
    .remaining_hw_credit(available_hw_credit),
    .hw_credit_value(credit_to_add),
    .increment_hw_credit(add_credit),
    .reset_interface(reset_interface),
    .debug_inputs(debug_data_sync),
    .timestamp(timestamp_host_clk),
    .axi_full_from_app(axi_full_virtual),
    .axi_full_to_host(axi_full_to_host),
    .axi_lite_user(axi_lite_from_host)
 );


endmodule
