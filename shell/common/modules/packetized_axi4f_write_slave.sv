// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

module packetized_axi4f_write_slave
  (
    input clk,
    input reset,
    so_axi4_if.slave_write axi_full_from_user,

    so_axi4s_if.master axi_stream_to_link,
    so_axi4s_if.slave axi_stream_from_link
 );

parameter logic [7:0] AXI4F_WRITE_SIGNATURE = 8'h88;
localparam logic [47:0] MAGIC_WORD = 48'hFACEB00CBABE;

typedef enum logic [7:0] {
      AXI4F_CMD_WR_ADDR_DATA    = 8'h80,
      //AXI4F_CMD_WR_CONT_DATA    = 8'h81,
      AXI4F_CMD_WR_RESP         = 8'h82
} axi4f_cmd_t;

typedef struct packed {
      logic [64:0] dummy;       // 65 bits
      logic [2:0] axi_prot;     // 3 bits
      logic [3:0] axi_cache;    // 4 bits
      logic [3:0] axi_qos;      // 4 bits
      logic       axi_lock;     // 1 bit
      logic [2:0] axi_size;     // 3 bits
      logic [1:0] axi_burst;    // 2 bits
      logic [1:0] axi_resp;     // 2 bits
      logic [3:0] axi_region;   // 4 bits
      logic [7:0] axi_len;      // 8 bits
      logic [7:0] axi_id;       // 8 bits
      logic [7:0] axi_user;     // 8 bits
      logic [15:0] cmd_metadata;// 16 bits
      logic [63:0] address;     // 64 bits
      logic [47:0] magic_word;  // 48 bits
      axi4f_cmd_t axi4f_cmd;    // 8 bits
      logic [7:0] signature;    // 8 bits
} axi4f_packet_header_t;

typedef enum logic [2:0] {
      ST_AXIF_GET_CMD     = 3'b000,
      ST_AXIF_GET_DATA_L  = 3'b010,
      ST_AXIF_GET_DATA_H  = 3'b011,
      ST_AXIF_SUBMIT_CMD  = 3'b100,
      ST_AXIF_ERROR       = 3'b111
} axif_state_t;

typedef enum {
      ST_AXIS_SEND_CMD,
      ST_AXIS_SEND_DATA
} axis_state_t;

typedef struct packed {
      logic [7:0] axi_id;
      logic [7:0] axi_user;
      logic last_fragment;
      logic [63:0] address;
      logic [7:0] axi_len;
} axis_command_t;

typedef struct packed {
      logic [7:0] axi_id;
      logic [7:0] axi_user;
      logic [1:0] axi_resp;
} axif_wresp_t;

typedef struct packed {
      logic last;
      logic [255:0] data;
} axis_data_t;


logic reset_axis_side;
logic [255:0] latched_lsb_data;

logic ready_for_more_commands;
axif_state_t axif_state;
axif_state_t axif_next_state;
logic received_write_cmd;
logic sent_write_resp;
logic length_mismatch;
logic [8:0] remaining_word_count;
logic [8:0] words_in_this_packet;
logic buffered_cmd_valid;

axis_command_t prepared_command;
axis_command_t buffered_command;
logic [11:0] updated_offset;
logic [31:0] packet_counter;

axis_state_t axis_state;
axis_state_t axis_next_state;

axis_data_t dt_fifo_data_in;
axis_data_t dt_fifo_data_out;
logic dt_fifo_write;
logic dt_fifo_read;
logic dt_fifo_wr_rst_busy;
logic dt_fifo_rd_rst_busy;
logic dt_fifo_prog_full;
logic dt_fifo_full;
logic dt_fifo_empty;

axif_wresp_t resp_fifo_data_in;
axif_wresp_t resp_fifo_data_out;
logic resp_fifo_write;
logic resp_fifo_read;
logic resp_fifo_wr_rst_busy;
logic resp_fifo_rd_rst_busy;
logic resp_fifo_prog_full;
logic resp_fifo_full;
logic resp_fifo_empty;
logic sent_write_cmd;
logic received_write_resp;

axi4f_packet_header_t write_resp_packet;
axi4f_packet_header_t command_packet;

logic [7:0] pending_writes;




//###################################################################
//######################## AXI-F side logic #########################
//###################################################################


assign axi_full_from_user.awready = (axif_state == ST_AXIF_GET_CMD) & ready_for_more_commands;
assign axi_full_from_user.wready = (axif_state == ST_AXIF_GET_DATA_H);
assign axi_full_from_user.bvalid = ~resp_fifo_empty;
assign axi_full_from_user.bresp = resp_fifo_data_out.axi_resp;
assign axi_full_from_user.buser = resp_fifo_data_out.axi_user;
assign axi_full_from_user.bid = resp_fifo_data_out.axi_id;

assign received_write_cmd = axi_full_from_user.awvalid & axi_full_from_user.awready;
assign sent_write_resp = axi_full_from_user.bvalid & axi_full_from_user.bready;

assign length_mismatch = axi_full_from_user.wvalid & axi_full_from_user.wlast & (|remaining_word_count);

assign updated_offset = prepared_command.address[11:0] + 12'd256;

assign dt_fifo_write = ((axif_state == ST_AXIF_GET_DATA_L) | (axif_state == ST_AXIF_GET_DATA_H)) & axi_full_from_user.wvalid;
assign dt_fifo_data_in.data = (axif_state == ST_AXIF_GET_DATA_L)? axi_full_from_user.wdata[255:0] : axi_full_from_user.wdata[511:256];
assign dt_fifo_data_in.last = (axif_state == ST_AXIF_GET_DATA_H) & axi_full_from_user.wlast;

assign resp_fifo_read = (~resp_fifo_empty) & axi_full_from_user.bready;

always_ff @(posedge clk) begin
      if(reset) begin
         axif_state <= ST_AXIF_GET_CMD;
         ready_for_more_commands <= '0;
         words_in_this_packet <= '0;
      end else begin
         axif_state <= axif_next_state;
         ready_for_more_commands <= ~(dt_fifo_prog_full | dt_fifo_rd_rst_busy | dt_fifo_wr_rst_busy |resp_fifo_prog_full | (|pending_writes[7:5]));
         words_in_this_packet <= (axif_state == ST_AXIF_SUBMIT_CMD)? '0:
                                 (axi_full_from_user.wvalid & axi_full_from_user.wready)? words_in_this_packet + 1'b1 : words_in_this_packet;
      end
      remaining_word_count <= (axif_state == ST_AXIF_GET_CMD)? axi_full_from_user.awlen:
                              (axi_full_from_user.wvalid & axi_full_from_user.wready)? remaining_word_count - 1'b1 : remaining_word_count;

      prepared_command.last_fragment <= (axif_state == ST_AXIF_GET_DATA_H)? ~(|remaining_word_count) : prepared_command.last_fragment;
      prepared_command.axi_id <= (axif_state == ST_AXIF_GET_CMD)? axi_full_from_user.awid : prepared_command.axi_id;
      prepared_command.axi_user <= (axif_state == ST_AXIF_GET_CMD)? axi_full_from_user.awuser : prepared_command.axi_user;
      prepared_command.address <= (axif_state == ST_AXIF_GET_CMD)?                            axi_full_from_user.awaddr :
                                  ((axif_state == ST_AXIF_SUBMIT_CMD) & ~buffered_cmd_valid)? {prepared_command.address[63:12],updated_offset} :
                                                                                              prepared_command.address;
      prepared_command.axi_len <= (axif_state == ST_AXIF_SUBMIT_CMD)? prepared_command.axi_len : words_in_this_packet;
      latched_lsb_data <= (axif_state==ST_AXIF_GET_DATA_L)? axi_stream_from_link.tdata : latched_lsb_data;
end


always_comb begin
   case(axif_state)
      ST_AXIF_GET_CMD      :  if(received_write_cmd) axif_next_state = ST_AXIF_GET_DATA_L;
                              else axif_next_state = ST_AXIF_GET_CMD;

      ST_AXIF_GET_DATA_L   :  if(axi_full_from_user.wvalid) axif_next_state = ST_AXIF_GET_DATA_H;
                              else axif_next_state = ST_AXIF_GET_DATA_L;

      ST_AXIF_GET_DATA_H   :  if(length_mismatch) axif_next_state = ST_AXIF_ERROR;
                              else if(axi_full_from_user.wvalid & axi_full_from_user.wlast) axif_next_state = ST_AXIF_SUBMIT_CMD;
                              else if(axi_full_from_user.wvalid) axif_next_state = ST_AXIF_GET_DATA_L;
                              else axif_next_state = ST_AXIF_GET_DATA_H;

      ST_AXIF_SUBMIT_CMD   :  if(buffered_cmd_valid) axif_next_state = ST_AXIF_SUBMIT_CMD;
                              else if(remaining_word_count[8]) axif_next_state = ST_AXIF_GET_CMD;
                              else axif_next_state = ST_AXIF_GET_DATA_L;

      default              :   axif_next_state = ST_AXIF_ERROR;
   endcase
end
//###################################################################
//######################## AXI-S side logic #########################
//###################################################################

assign axi_stream_from_link.tready = 1'b1;

assign axi_stream_to_link.tvalid = (axis_state == ST_AXIS_SEND_CMD)? buffered_cmd_valid : 1'b1;
assign axi_stream_to_link.tdata = (axis_state == ST_AXIS_SEND_DATA)? dt_fifo_data_out.data : command_packet;
assign axi_stream_to_link.tlast = (axis_state == ST_AXIS_SEND_DATA)? dt_fifo_data_out.last : 1'b0;
assign axi_stream_to_link.tkeep = 32'hFFFFFFFF;



assign command_packet.dummy = '0;
assign command_packet.axi_prot = '0;
assign command_packet.axi_cache = '0;
assign command_packet.axi_qos = '0;
assign command_packet.axi_lock = '0;
assign command_packet.axi_size = '0;
assign command_packet.axi_burst = '0;
assign command_packet.axi_resp = '0;
assign command_packet.axi_region = '0;
assign command_packet.axi_len = buffered_command.axi_len;
assign command_packet.axi_id = buffered_command.axi_id;
assign command_packet.axi_user = buffered_command.axi_user;
assign command_packet.cmd_metadata = {buffered_command.last_fragment,packet_counter[14:0]};
assign command_packet.address = buffered_command.address;
assign command_packet.magic_word = MAGIC_WORD;
assign command_packet.axi4f_cmd = AXI4F_CMD_WR_ADDR_DATA;
assign command_packet.signature = AXI4F_WRITE_SIGNATURE;



assign sent_write_cmd = axi_stream_to_link.tready & buffered_cmd_valid & (axis_state == ST_AXIS_SEND_CMD);
assign received_write_resp = axi_stream_from_link.tvalid;
assign write_resp_packet = axi_stream_from_link.tdata;

assign dt_fifo_read = (axis_state == ST_AXIS_SEND_DATA) & axi_stream_to_link.tvalid & axi_stream_to_link.tready;

assign resp_fifo_write = axi_stream_from_link.tvalid & write_resp_packet.cmd_metadata[15] & (write_resp_packet.magic_word==MAGIC_WORD) &
                         (write_resp_packet.axi4f_cmd==AXI4F_CMD_WR_RESP) & (write_resp_packet.signature==AXI4F_WRITE_SIGNATURE);

assign resp_fifo_data_in.axi_id = write_resp_packet.axi_id;
assign resp_fifo_data_in.axi_user = write_resp_packet.axi_user;
assign resp_fifo_data_in.axi_resp = write_resp_packet.axi_resp;



always_ff @(posedge clk) begin
      if(reset) begin
         axis_state <= ST_AXIS_SEND_CMD;
         buffered_cmd_valid <= '0;
         pending_writes <= '0;
         packet_counter <= '0;
      end else begin
         axis_state <= axis_next_state;
         buffered_cmd_valid <= (buffered_cmd_valid)? ~(axi_stream_to_link.tready & (axis_state == ST_AXIS_SEND_CMD)) : (axif_state == ST_AXIF_SUBMIT_CMD);
         pending_writes <= (sent_write_cmd & ~received_write_resp)? pending_writes + 1'b1:
                           (received_write_resp & ~sent_write_cmd)? pending_writes - 1'b1: pending_writes;
         packet_counter <= (axi_stream_to_link.tready & (axis_state == ST_AXIS_SEND_CMD))? packet_counter + 1'b1 : packet_counter;
      end
      buffered_command <= (buffered_cmd_valid)? buffered_command : prepared_command;
end


always_comb begin
   case(axis_state)
      ST_AXIS_SEND_CMD     :  if(axi_stream_to_link.tready & buffered_cmd_valid) axis_next_state = ST_AXIS_SEND_DATA;
                              else axis_next_state = ST_AXIS_SEND_CMD;

      ST_AXIS_SEND_DATA    :  if(axi_stream_to_link.tready & axi_stream_to_link.tlast) axis_next_state = ST_AXIS_SEND_CMD;
                              else axis_next_state = ST_AXIS_SEND_DATA;

      default         :   axis_next_state = ST_AXIS_SEND_CMD;
   endcase
end


//###################################################################
xpm_fifo_sync #(
   .FIFO_MEMORY_TYPE("block"),
   .FIFO_READ_LATENCY(0),
   .FIFO_WRITE_DEPTH(256),
   .PROG_FULL_THRESH(240),
   .RD_DATA_COUNT_WIDTH(1),
   .READ_DATA_WIDTH($size(axis_data_t)),
   .READ_MODE("fwft"),
   .USE_ADV_FEATURES("0003"),
   .WRITE_DATA_WIDTH($size(axis_data_t))
)
data_fifo (
   .almost_empty(),
   .almost_full(),
   .data_valid(),
   .dbiterr(),
   .dout(dt_fifo_data_out),
   .empty(dt_fifo_empty),
   .full(dt_fifo_full),
   .overflow(),
   .prog_empty(),
   .prog_full(dt_fifo_prog_full),
   .rd_data_count(),
   .rd_rst_busy(dt_fifo_rd_rst_busy),
   .sbiterr(),
   .underflow(),
   .wr_ack(),
   .wr_data_count(),
   .wr_rst_busy(dt_fifo_wr_rst_busy),
   .din(dt_fifo_data_in),
   .injectdbiterr(1'b0),
   .injectsbiterr(1'b0),
   .rd_en(dt_fifo_read),
   .rst(reset),
   .sleep(1'b0),
   .wr_clk(clk),
   .wr_en(dt_fifo_write)
);


xpm_fifo_sync #(
   .FIFO_MEMORY_TYPE("auto"),
   .FIFO_READ_LATENCY(0),
   .FIFO_WRITE_DEPTH(64),
   .PROG_FULL_THRESH(31),
   .RD_DATA_COUNT_WIDTH(1),
   .READ_DATA_WIDTH($size(axif_wresp_t)),
   .READ_MODE("fwft"),
   .USE_ADV_FEATURES("0003"),
   .WRITE_DATA_WIDTH($size(axif_wresp_t))
)
resp_fifo (
   .almost_empty(),
   .almost_full(),
   .data_valid(),
   .dbiterr(),
   .dout(resp_fifo_data_out),
   .empty(resp_fifo_empty),
   .full(resp_fifo_full),
   .overflow(),
   .prog_empty(),
   .prog_full(resp_fifo_prog_full),
   .rd_data_count(),
   .rd_rst_busy(resp_fifo_rd_rst_busy),
   .sbiterr(),
   .underflow(),
   .wr_ack(),
   .wr_data_count(),
   .wr_rst_busy(resp_fifo_wr_rst_busy),
   .din(resp_fifo_data_in),
   .injectdbiterr(1'b0),
   .injectsbiterr(1'b0),
   .rd_en(resp_fifo_read),
   .rst(reset),
   .sleep(1'b0),
   .wr_clk(clk),
   .wr_en(resp_fifo_write)
);


endmodule
