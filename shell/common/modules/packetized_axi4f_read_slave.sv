// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

module packetized_axi4f_read_slave
  (
    input clk,
    input reset,
    so_axi4_if.slave_read axi_full_from_user,

    so_axi4s_if.master axi_stream_to_link,
    so_axi4s_if.slave axi_stream_from_link
 );

parameter logic [7:0] AXI4F_READ_SIGNATURE = 8'h77;
localparam logic [47:0] MAGIC_WORD = 48'hFACEB00CBABE;
localparam int PENDING_DATA_THRESHOLD = 448;
// maximum read length should be 4KB which (axi length = 64 beats)
// given that the data fifo in this module can hold 1024 x 32 Bytes = 512 beats
// we are setting a threshold of 448 above which we stop accepting read requests
// this makes sure that the maximum pending beats would be 447 + 64 = 511 which is below the FIFO limit

typedef enum logic [7:0] {
      AXI4F_CMD_RD_ADDR             = 8'h70,
      AXI4F_CMD_RD_DATA_RESP        = 8'h71
} axi4f_cmd_t;

typedef enum {
      ST_HEADER,
      ST_DATA,
      ST_ERROR
} response_state_t;

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

typedef struct packed {
      logic [7:0] axi_id;
      logic [7:0] axi_user;
      logic [63:0] address;
      logic [7:0] axi_len;
} axis_command_t;

typedef struct packed {
      logic [7:0] axi_id;
      logic [7:0] axi_user;
      logic [7:0] axi_len;
} expected_response_t;

typedef struct packed {
      logic [7:0] axi_id;
      logic [7:0] axi_user;
} resp_info_t;

typedef struct packed {
      logic [255:0] data;
      logic [1:0] axi_resp;
      logic last;
} axif_rdata_t;

logic ready_for_command;
logic [9:0] pending_data;
logic buffered_cmd_valid;

axis_command_t buffered_command;
logic [31:0] command_counter;
logic [31:0] response_counter;

response_state_t response_state;
response_state_t response_next_state;
logic unexpected_header;
logic unexpected_tlast;
logic matched_axi_id;
logic matched_user;
logic matched_packet_id;
logic last_word;

expected_response_t expected_header_fifo_in;
expected_response_t expected_header_fifo_out;
logic expected_header_fifo_write;
logic expected_header_fifo_read;
logic expected_header_fifo_rst_busy;

resp_info_t response_info_fifo_in;
resp_info_t response_info_fifo_out;
logic response_info_fifo_write;
logic response_info_fifo_read;
logic response_info_fifo_empty;
logic response_info_fifo_rst_busy;

logic active_response;
logic lsb_data_is_latched;
logic [255:0] latched_lsb_data;
logic [8:0] response_data_counter;
logic [1:0] combined_rresp;

axif_rdata_t dt_fifo_data_in;
axif_rdata_t dt_fifo_data_out;
logic dt_fifo_write;
logic dt_fifo_read;
logic dt_fifo_rst_busy;
logic dt_fifo_full;
logic dt_fifo_empty;

axi4f_packet_header_t read_resp_packet;
axi4f_packet_header_t command_packet;





//###################################################################
//######################## Command logic #########################
//###################################################################

assign axi_stream_to_link.tvalid = buffered_cmd_valid;
assign axi_stream_to_link.tdata = command_packet;
assign axi_stream_to_link.tlast = 1'b1;
assign axi_stream_to_link.tkeep = 32'h00FFFFFF;

assign axi_full_from_user.arready = ready_for_command;

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
assign command_packet.cmd_metadata = command_counter[15:0];
assign command_packet.address = buffered_command.address;
assign command_packet.magic_word = MAGIC_WORD;
assign command_packet.axi4f_cmd = AXI4F_CMD_RD_ADDR;
assign command_packet.signature = AXI4F_READ_SIGNATURE;

assign expected_header_fifo_in.axi_id = buffered_command.axi_id;
assign expected_header_fifo_in.axi_user = buffered_command.axi_user;
assign expected_header_fifo_in.axi_len = buffered_command.axi_len;

assign expected_header_fifo_write = axi_stream_to_link.tready & axi_stream_to_link.tvalid;

always_ff @(posedge clk) begin
      if(reset) begin
         ready_for_command <= 1'b0;
         buffered_cmd_valid <= 1'b0;
         command_counter <= '0;
         pending_data <= '0;
      end else begin
         ready_for_command <= (pending_data < PENDING_DATA_THRESHOLD) & ~(dt_fifo_rst_busy | buffered_cmd_valid |
                              response_info_fifo_rst_busy | expected_header_fifo_rst_busy);
         buffered_cmd_valid <= (buffered_cmd_valid)? ~axi_stream_to_link.tready: axi_full_from_user.arready & axi_full_from_user.arvalid;
         command_counter <= (axi_stream_to_link.tready & axi_stream_to_link.tvalid)? command_counter + 1'b1: command_counter;
         pending_data <= (axi_full_from_user.arready & axi_full_from_user.arvalid)?
                         pending_data + axi_full_from_user.arlen + 1'b1 - (axi_full_from_user.rready & axi_full_from_user.rvalid):
                         pending_data - (axi_full_from_user.rready & axi_full_from_user.rvalid);
      end

      buffered_command.axi_id <= (buffered_cmd_valid)? buffered_command.axi_id : axi_full_from_user.arid;
      buffered_command.axi_user <= (buffered_cmd_valid)? buffered_command.axi_user : axi_full_from_user.aruser;
      buffered_command.address <= (buffered_cmd_valid)? buffered_command.address : axi_full_from_user.araddr;
      buffered_command.axi_len <= (buffered_cmd_valid)? buffered_command.axi_len : axi_full_from_user.arlen;
end

//###################################################################
//######################## Response logic #########################
//###################################################################

assign axi_stream_from_link.tready = 1'b1;

assign axi_full_from_user.rvalid = active_response & lsb_data_is_latched & ~dt_fifo_empty;
assign axi_full_from_user.rresp = dt_fifo_data_out.axi_resp;
assign axi_full_from_user.ruser = response_info_fifo_out.axi_user;
assign axi_full_from_user.rid = response_info_fifo_out.axi_id;
assign axi_full_from_user.rlast = dt_fifo_data_out.last;
assign axi_full_from_user.rdata = {dt_fifo_data_out.data,latched_lsb_data};

assign read_resp_packet = axi_stream_from_link.tdata;


assign last_word = (response_data_counter[8:1] == expected_header_fifo_out.axi_len) & response_data_counter[0];
assign unexpected_tlast = axi_stream_from_link.tvalid & (combined_rresp == 2'b00) &
                          (response_state == ST_DATA) & (last_word ^ axi_stream_from_link.tlast);

assign matched_axi_id = (expected_header_fifo_out.axi_id == read_resp_packet.axi_id);
assign matched_user = (expected_header_fifo_out.axi_user == read_resp_packet.axi_user);
assign matched_packet_id = (read_resp_packet.cmd_metadata == response_counter[15:0]);
assign unexpected_header = ~(matched_axi_id & matched_user & matched_packet_id);


assign expected_header_fifo_read = (response_state == ST_DATA) & axi_stream_from_link.tvalid & axi_stream_from_link.tlast;


assign response_info_fifo_in.axi_id = expected_header_fifo_out.axi_id;
assign response_info_fifo_in.axi_user = expected_header_fifo_out.axi_user;
assign response_info_fifo_write = (response_state == ST_HEADER) & axi_stream_from_link.tvalid;

assign dt_fifo_data_in.data = axi_stream_from_link.tdata;
assign dt_fifo_data_in.axi_resp = combined_rresp;
assign dt_fifo_data_in.last = axi_stream_from_link.tlast & (response_state == ST_DATA);
assign dt_fifo_write = (response_state == ST_DATA) & axi_stream_from_link.tvalid;

assign dt_fifo_read = active_response & (~dt_fifo_empty) & (axi_full_from_user.rready | ~lsb_data_is_latched);
assign response_info_fifo_read = dt_fifo_read & dt_fifo_data_out.last;

always_ff @(posedge clk) begin
      if(reset) begin
         response_state <= ST_HEADER;
         response_data_counter <= '0;
         active_response <= '0;
         lsb_data_is_latched <= '0;
         response_counter <= '0;
      end else begin
         response_state <= response_next_state;
         response_data_counter <= (response_state == ST_HEADER)? '0 :
                                  (response_state == ST_DATA)? response_data_counter + axi_stream_from_link.tvalid : response_data_counter;
         active_response <= (active_response)? ~(response_info_fifo_read) : ~response_info_fifo_empty;
         lsb_data_is_latched <= lsb_data_is_latched ^ dt_fifo_read;
         response_counter <= ((response_state == ST_DATA) & axi_stream_from_link.tvalid & axi_stream_from_link.tlast)? response_counter + 1'b1:
                                                                                                                       response_counter;
      end
      combined_rresp <= (response_state == ST_HEADER)? read_resp_packet.axi_resp : combined_rresp;
      latched_lsb_data <= (lsb_data_is_latched)? latched_lsb_data : dt_fifo_data_out.data;
end

always_comb begin
   case (response_state)
      ST_HEADER:        if(axi_stream_from_link.tvalid & unexpected_header) response_next_state = ST_ERROR;
                        else if(axi_stream_from_link.tvalid) response_next_state = ST_DATA;
                        else response_next_state = ST_HEADER;

      ST_DATA:          if(unexpected_tlast) response_next_state = ST_ERROR;
                        else if(axi_stream_from_link.tvalid & axi_stream_from_link.tlast) response_next_state = ST_HEADER;
                        else response_next_state = ST_DATA;

      default:          response_next_state = ST_ERROR;
   endcase
end


//###################################################################
xpm_fifo_sync #(
   .FIFO_MEMORY_TYPE("block"),
   .FIFO_READ_LATENCY(0),
   .FIFO_WRITE_DEPTH(1024),
   .READ_DATA_WIDTH($size(axif_rdata_t)),
   .READ_MODE("fwft"),
   .USE_ADV_FEATURES("0000"),
   .WRITE_DATA_WIDTH($size(axif_rdata_t))
)
data_fifo
(
   .almost_empty(),
   .almost_full(),
   .data_valid(),
   .dbiterr(),
   .dout(dt_fifo_data_out),
   .empty(dt_fifo_empty),
   .full(dt_fifo_full),
   .overflow(),
   .prog_empty(),
   .prog_full(),
   .rd_data_count(),
   .rd_rst_busy(),
   .sbiterr(),
   .underflow(),
   .wr_ack(),
   .wr_data_count(),
   .wr_rst_busy(dt_fifo_rst_busy),
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
   .READ_DATA_WIDTH($size(expected_response_t)),
   .READ_MODE("fwft"),
   .USE_ADV_FEATURES("0003"),
   .WRITE_DATA_WIDTH($size(expected_response_t))
)
expected_header_fifo
(
   .almost_empty(),
   .almost_full(),
   .data_valid(),
   .dbiterr(),
   .dout(expected_header_fifo_out),
   .empty(),
   .full(),
   .overflow(),
   .prog_empty(),
   .prog_full(),
   .rd_data_count(),
   .rd_rst_busy(),
   .sbiterr(),
   .underflow(),
   .wr_ack(),
   .wr_data_count(),
   .wr_rst_busy(expected_header_fifo_rst_busy),
   .din(expected_header_fifo_in),
   .injectdbiterr(1'b0),
   .injectsbiterr(1'b0),
   .rd_en(expected_header_fifo_read),
   .rst(reset),
   .sleep(1'b0),
   .wr_clk(clk),
   .wr_en(expected_header_fifo_write)
);


xpm_fifo_sync #(
   .FIFO_MEMORY_TYPE("auto"),
   .FIFO_READ_LATENCY(0),
   .FIFO_WRITE_DEPTH(64),
   .PROG_FULL_THRESH(31),
   .RD_DATA_COUNT_WIDTH(1),
   .READ_DATA_WIDTH($size(resp_info_t)),
   .READ_MODE("fwft"),
   .USE_ADV_FEATURES("0003"),
   .WRITE_DATA_WIDTH($size(resp_info_t))
)
resp_info_fifo
(
   .almost_empty(),
   .almost_full(),
   .data_valid(),
   .dbiterr(),
   .dout(response_info_fifo_out),
   .empty(response_info_fifo_empty),
   .full(),
   .overflow(),
   .prog_empty(),
   .prog_full(),
   .rd_data_count(),
   .rd_rst_busy(),
   .sbiterr(),
   .underflow(),
   .wr_ack(),
   .wr_data_count(),
   .wr_rst_busy(response_info_fifo_rst_busy),
   .din(response_info_fifo_in),
   .injectdbiterr(1'b0),
   .injectsbiterr(1'b0),
   .rd_en(response_info_fifo_read),
   .rst(reset),
   .sleep(1'b0),
   .wr_clk(clk),
   .wr_en(response_info_fifo_write)
);


endmodule
