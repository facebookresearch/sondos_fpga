// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

module packetized_axi4f_write_master
  (
    input axif_clk,
    input axis_clk,
    input axif_reset,
    output [31:0] status,
    so_axi4_if.master_write axi_full_to_host,

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

typedef enum {
      ST_W_GET_CMD,
      ST_W_GET_DATA_L,
      ST_W_GET_DATA_H,
      ST_W_ERROR
   } w_state_t;

typedef struct packed {
      logic [7:0] axi_id;
      logic [7:0] axi_user;
      logic [15:0] cmd_metadata;
      logic [63:0] address;
      logic [7:0] axi_len;
} axif_command_t;

typedef struct packed {
      logic last;
      logic [511:0] data;
} axif_wdata_t;

typedef struct packed {
      logic [7:0] axi_id;
      logic [7:0] axi_user;
      logic [15:0] cmd_metadata;
      logic [1:0] axi_resp;
} axif_wresp_t;

typedef struct packed {
      logic [7:0] axi_id;
      logic [7:0] axi_user;
      logic [15:0] cmd_metadata;
} write_metadata_t;

logic reset_axis_side;
logic [255:0] latched_lsb_data;

w_state_t write_state;
w_state_t write_next_state;
logic received_write_cmd;
logic [8:0] words_in_this_packet;

axif_command_t cmd_fifo_data_in;
axif_command_t cmd_fifo_data_out;
logic cmd_fifo_write;
logic cmd_fifo_read;
logic cmd_fifo_wr_rst_busy;
logic cmd_fifo_rd_rst_busy;
logic cmd_fifo_prog_full;
logic cmd_fifo_full;
logic cmd_fifo_empty;

axif_wdata_t dt_fifo_data_in;
axif_wdata_t dt_fifo_data_out;
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

axi4f_packet_header_t write_resp_packet;
axi4f_packet_header_t command_packet;
axi4f_packet_header_t hold_command_packet;

logic [3:0] pending_writes;

logic [1:0] latched_resp_value;
logic wr_response_received;

write_metadata_t metadata_fifo_in;
write_metadata_t metadata_fifo_out;

// error detection signals (all on axif_clk)
logic reached_write_error_state;
logic unexpected_pending_writes;

logic [15:0] command_backpressure_timeout;
logic [15:0] response_timeout;
logic [15:0] wresp_error_count;

//###################################################################
//######################## AXI-S side logic #########################
//###################################################################
xpm_cdc_sync_rst #(
   .DEST_SYNC_FF(4),
   .INIT(1))
xpm_cdc_sync_rst_inst (
   .dest_rst(reset_axis_side),
   .dest_clk(axis_clk),
   .src_rst(axif_reset)
);


assign axi_stream_from_link.tready = 1'b1;
assign command_packet = axi_stream_from_link.tdata;

assign received_write_cmd = axi_stream_from_link.tvalid & (command_packet.magic_word==MAGIC_WORD) &
                            (command_packet.axi4f_cmd==AXI4F_CMD_WR_ADDR_DATA) & (command_packet.signature==AXI4F_WRITE_SIGNATURE);

assign cmd_fifo_data_in.cmd_metadata = hold_command_packet.cmd_metadata;
assign cmd_fifo_data_in.axi_id = hold_command_packet.axi_id;
assign cmd_fifo_data_in.axi_user = hold_command_packet.axi_user;
assign cmd_fifo_data_in.address = hold_command_packet.address;
assign cmd_fifo_data_in.axi_len = words_in_this_packet;
assign cmd_fifo_write = axi_stream_from_link.tlast & axi_stream_from_link.tvalid;

assign dt_fifo_data_in.last = axi_stream_from_link.tlast;
assign dt_fifo_data_in.data[511:256] = axi_stream_from_link.tdata;
assign dt_fifo_data_in.data[255:0] = (write_state == ST_W_GET_DATA_H)? latched_lsb_data : axi_stream_from_link.tdata;
assign dt_fifo_write = ((write_state == ST_W_GET_DATA_H) | axi_stream_from_link.tlast) & axi_stream_from_link.tvalid;

assign write_resp_packet.axi_id     = resp_fifo_data_out.axi_id;
assign write_resp_packet.axi_user   = resp_fifo_data_out.axi_user;
assign write_resp_packet.axi_resp       = resp_fifo_data_out.axi_resp;
assign write_resp_packet.cmd_metadata     = resp_fifo_data_out.cmd_metadata;
assign write_resp_packet.magic_word = MAGIC_WORD;
assign write_resp_packet.axi4f_cmd  = AXI4F_CMD_WR_RESP;
assign write_resp_packet.signature  = AXI4F_WRITE_SIGNATURE;


assign axi_stream_to_link.tlast = 1'b1;
assign axi_stream_to_link.tkeep = 32'h00FFFFFF;
assign axi_stream_to_link.tvalid = ~resp_fifo_empty;
assign axi_stream_to_link.tdata = write_resp_packet;

assign resp_fifo_read = axi_stream_to_link.tvalid & axi_stream_to_link.tready;

always_ff @(posedge axis_clk) begin
      if(reset_axis_side) begin
        write_state <= ST_W_GET_CMD;
      end else begin
        write_state <= write_next_state;
      end
      words_in_this_packet <= (write_state == ST_W_GET_CMD)? 0:
                              (dt_fifo_write)? words_in_this_packet + 1'b1 : words_in_this_packet;
      hold_command_packet <= (write_state == ST_W_GET_CMD)? axi_stream_from_link.tdata : hold_command_packet;
      latched_lsb_data <= (write_state==ST_W_GET_DATA_L)? axi_stream_from_link.tdata : latched_lsb_data;
end


always_comb begin
    case(write_state)
        ST_W_GET_CMD    :  if(received_write_cmd) write_next_state = ST_W_GET_DATA_L;
                           else write_next_state = ST_W_GET_CMD;

        ST_W_GET_DATA_L   :  if(axi_stream_from_link.tvalid & axi_stream_from_link.tlast) write_next_state = ST_W_GET_CMD;
                           else if(axi_stream_from_link.tvalid) write_next_state = ST_W_GET_DATA_H;
                           else write_next_state = ST_W_GET_DATA_L;

        ST_W_GET_DATA_H   :  if(axi_stream_from_link.tvalid & axi_stream_from_link.tlast) write_next_state = ST_W_GET_CMD;
                           else if(axi_stream_from_link.tvalid) write_next_state = ST_W_GET_DATA_L;
                           else write_next_state = ST_W_GET_DATA_H;

        default         :   write_next_state = ST_W_ERROR;
    endcase
end
//###################################################################
//######################## AXI-F side logic #########################
//###################################################################

assign axi_full_to_host.bready = (|pending_writes);

assign axi_full_to_host.awid    = '0;
assign axi_full_to_host.awaddr  = cmd_fifo_data_out.address;
assign axi_full_to_host.awregion= '0;
assign axi_full_to_host.awlen   = cmd_fifo_data_out.axi_len;
assign axi_full_to_host.awsize  = 3'b110;
assign axi_full_to_host.awburst = 2'b01;
assign axi_full_to_host.awvalid = (~cmd_fifo_empty) & (~pending_writes[3]); // limit operations to 8 pending writes
assign axi_full_to_host.awuser  = '0;

assign axi_full_to_host.wdata   = dt_fifo_data_out.data;
assign axi_full_to_host.wstrb   = 64'hFFFF_FFFF_FFFF_FFFF;
assign axi_full_to_host.wlast   = dt_fifo_data_out.last;
assign axi_full_to_host.wvalid  = ~dt_fifo_empty;
assign axi_full_to_host.wuser   = '0;

assign resp_fifo_write = wr_response_received;
assign cmd_fifo_read = axi_full_to_host.awvalid & axi_full_to_host.awready;
assign dt_fifo_read = axi_full_to_host.wvalid & axi_full_to_host.wready;

assign metadata_fifo_in.axi_id = cmd_fifo_data_out.axi_id;
assign metadata_fifo_in.axi_user = cmd_fifo_data_out.axi_user;
assign metadata_fifo_in.cmd_metadata = cmd_fifo_data_out.cmd_metadata;

assign resp_fifo_data_in.axi_id = metadata_fifo_out.axi_id;
assign resp_fifo_data_in.axi_user = metadata_fifo_out.axi_user;
assign resp_fifo_data_in.cmd_metadata = metadata_fifo_out.cmd_metadata;
assign resp_fifo_data_in.axi_resp = latched_resp_value;

always_ff @(posedge axif_clk) begin
      if(axif_reset) begin
         pending_writes <= '0;
         wr_response_received <= '0;
      end else begin
         pending_writes <= (cmd_fifo_read & ~resp_fifo_write)? pending_writes + 1'b1:
                          (resp_fifo_write & ~cmd_fifo_read)? pending_writes - 1'b1 : pending_writes;
         wr_response_received <= axi_full_to_host.bready & axi_full_to_host.bvalid;
      end
      latched_resp_value <= axi_full_to_host.bresp;
end

//###################################################################
//######################## Error detection logic ####################
//###################################################################

xpm_cdc_single #(.DEST_SYNC_FF(2)) xpm_cdc_single_inst
(
   .dest_out(reached_write_error_state),
   .dest_clk(axif_clk),
   .src_clk(axis_clk),
   .src_in((write_state==ST_W_ERROR))
);


assign status[0] =  reached_write_error_state;
assign status[1] =  unexpected_pending_writes;
assign status[2] =  command_backpressure_timeout[15];
assign status[3] =  response_timeout[15];
assign status[15:4] =  '0; // more error detection to be added later
assign status[31:16] =  wresp_error_count;

always_ff @(posedge axif_clk) begin
   if(axif_reset) begin
      unexpected_pending_writes <= '0;
      command_backpressure_timeout <= '0;
      response_timeout <= '0;
      wresp_error_count <= '0;
   end else begin
      unexpected_pending_writes <= unexpected_pending_writes | (pending_writes[3] & (|pending_writes[2:0]));
      command_backpressure_timeout <= (command_backpressure_timeout[15])? command_backpressure_timeout:
                                      (axi_full_to_host.awvalid & ~axi_full_to_host.awready)? command_backpressure_timeout + 1'b1 : '0;
      response_timeout <= (response_timeout[15])? response_timeout:
                          (axi_full_to_host.bready & ~axi_full_to_host.bvalid)? response_timeout + 1'b1 : '0;
      wresp_error_count <= wresp_error_count + (axi_full_to_host.bready & axi_full_to_host.bvalid & axi_full_to_host.bresp[1]);
   end
end
//###################################################################
xpm_fifo_async #(
   .FIFO_MEMORY_TYPE("block"),
   .FIFO_READ_LATENCY(0),
   .FIFO_WRITE_DEPTH(512),
   .PROG_FULL_THRESH(500),
   .RD_DATA_COUNT_WIDTH(1),
   .READ_DATA_WIDTH($size(axif_wdata_t)),
   .READ_MODE("fwft"),
   .USE_ADV_FEATURES("0003"),
   .WRITE_DATA_WIDTH($size(axif_wdata_t))
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
   .rst(reset_axis_side),
   .sleep(1'b0),
   .wr_clk(axis_clk),
   .rd_clk(axif_clk),
   .wr_en(dt_fifo_write)
);


xpm_fifo_async #(
   .FIFO_MEMORY_TYPE("auto"),
   .FIFO_READ_LATENCY(0),
   .FIFO_WRITE_DEPTH(32),
   .PROG_FULL_THRESH(26),
   .RD_DATA_COUNT_WIDTH(1),
   .READ_DATA_WIDTH($size(axif_command_t)),
   .READ_MODE("fwft"),
   .USE_ADV_FEATURES("0003"),
   .WRITE_DATA_WIDTH($size(axif_command_t))
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
   .rst(reset_axis_side),
   .sleep(1'b0),
   .wr_clk(axis_clk),
   .rd_clk(axif_clk),
   .wr_en(cmd_fifo_write)
);


xpm_fifo_async #(
   .FIFO_MEMORY_TYPE("auto"),
   .FIFO_READ_LATENCY(0),
   .FIFO_WRITE_DEPTH(32),
   .PROG_FULL_THRESH(26),
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
   .rst(axif_reset),
   .sleep(1'b0),
   .wr_clk(axif_clk),
   .rd_clk(axis_clk),
   .wr_en(resp_fifo_write)
);

 xpm_fifo_sync #(
   .FIFO_MEMORY_TYPE("auto"),
   .FIFO_READ_LATENCY(0),
   .FIFO_WRITE_DEPTH(16),
   .PROG_FULL_THRESH(8),
   .RD_DATA_COUNT_WIDTH(1),
   .READ_DATA_WIDTH($size(write_metadata_t)),
   .READ_MODE("fwft"),
   .USE_ADV_FEATURES("0003"),
   .WRITE_DATA_WIDTH($size(write_metadata_t))
)
metadata_fifo (
   .almost_empty(),
   .almost_full(),
   .data_valid(),
   .dbiterr(),
   .dout(metadata_fifo_out),
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
   .wr_rst_busy(),
   .din(metadata_fifo_in),
   .injectdbiterr(1'b0),
   .injectsbiterr(1'b0),
   .rd_en(resp_fifo_write),
   .rst(axif_reset),
   .sleep(1'b0),
   .wr_clk(axif_clk),
   .wr_en(cmd_fifo_read)
);

endmodule
