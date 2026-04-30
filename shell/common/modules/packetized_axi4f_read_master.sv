// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

module packetized_axi4f_read_master
  (
    input axif_clk,
    input axis_clk,
    input axif_reset,
    output [31:0] status,
    so_axi4_if.master_read axi_full_to_host,

    so_axi4s_if.master axi_stream_to_link,
    so_axi4s_if.slave axi_stream_from_link
 );

parameter logic [7:0] AXI4F_READ_SIGNATURE = 8'h77;
localparam logic [47:0] MAGIC_WORD = 48'hFACEB00CBABE;


typedef enum logic [7:0] {
      AXI4F_CMD_RD_ADDR             = 8'h70,
      AXI4F_CMD_RD_DATA_RESP        = 8'h71
} axi4f_cmd_t;

typedef enum logic [1:0] {
      ST_HEADER   = 2'd0,
      ST_DATA_LSB = 2'd1,
      ST_DATA_MSB = 2'd2,
      ST_ERROR    = 2'd3
} axis_response_state_t;

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
      logic [63:0] address;
      logic [7:0] axi_len;
} axif_command_t;

typedef struct packed {
      logic [7:0] axi_id;
      logic [7:0] axi_user;
      logic [1:0] axi_resp;
      logic [8:0] num_words;
      logic [15:0] cmd_metadata;
} resp_info_t;

typedef struct packed {
      logic [7:0] axi_id;
      logic [7:0] axi_user;
      logic [15:0] cmd_metadata;
} metadata_info_t;

logic reset_axis_side;
logic axis_fifos_are_ready;
logic received_new_command;
logic axis_data_taken;
logic [8:0] axis_words_in_this_packet;

axif_command_t cmd_fifo_data_in;
axif_command_t cmd_fifo_data_out;
logic cmd_fifo_write;
logic cmd_fifo_read;
logic cmd_fifo_wr_rst_busy;
logic cmd_fifo_rd_rst_busy;
logic cmd_fifo_full;
logic cmd_fifo_empty;


logic axif_fifos_are_ready;
logic new_command_is_ready;
logic have_enough_credit_for_command;
logic [9:0] pending_read_data;
logic [9:0] total_credit_check;

axis_response_state_t axis_response_state;
axis_response_state_t axis_response_next_state;

metadata_info_t metadata_fifo_data_in;
metadata_info_t metadata_fifo_data_out;
logic metadata_fifo_empty;
logic metadata_fifo_full;
logic metadata_fifo_read;
logic metadata_fifo_write;
logic metadata_fifo_wr_rst_busy;
logic metadata_fifo_rd_rst_busy;


resp_info_t resp_info_fifo_data_in;
resp_info_t resp_info_fifo_data_out;
logic resp_info_fifo_wr_rst_busy;
logic resp_info_fifo_rd_rst_busy;
logic resp_info_fifo_empty;
logic resp_info_fifo_full;
logic resp_info_fifo_write;
logic resp_info_fifo_read;

logic [8:0] axif_words_in_this_packet;
logic [7:0] axif_command_word_count;
logic axif_end_of_command;
logic [1:0] latched_resp_value;


logic [511:0] dt_fifo_data_out;
logic dt_fifo_read;
logic dt_fifo_wr_rst_busy;
logic dt_fifo_rd_rst_busy;
logic dt_fifo_full;
logic dt_fifo_empty;
logic [9:0] dt_fifo_wr_data_count;

axi4f_packet_header_t read_resp_header;
axi4f_packet_header_t command_packet;

//////////////////////
logic response_underflow;
logic data_fifo_overflow;
logic axif_command_timout;
logic [20:0] axif_command_timout_counter;
logic axif_response_timeout;
logic [20:0] axif_response_timeout_counter;


logic axis_command_overflow;
logic axis_timeout;
logic [20:0] axis_timeout_counter;


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


assign axi_stream_from_link.tready = 1'b1; // back pressure is not allowed on aurora
assign command_packet = axi_stream_from_link.tdata;

assign cmd_fifo_data_in.address        = command_packet.address;
assign cmd_fifo_data_in.axi_len        = command_packet.axi_len;

assign metadata_fifo_data_in.cmd_metadata   = command_packet.cmd_metadata;
assign metadata_fifo_data_in.axi_id         = command_packet.axi_id;
assign metadata_fifo_data_in.axi_user       = command_packet.axi_user;


assign received_new_command= axi_stream_from_link.tvalid & (command_packet.magic_word==MAGIC_WORD) &
                        (command_packet.axi4f_cmd==AXI4F_CMD_RD_ADDR) & (command_packet.signature==AXI4F_READ_SIGNATURE);

assign cmd_fifo_write = received_new_command & axis_fifos_are_ready & ~metadata_fifo_full;
assign metadata_fifo_write = cmd_fifo_write;

assign read_resp_header.axi_id        = resp_info_fifo_data_out.axi_id;
assign read_resp_header.axi_user      = resp_info_fifo_data_out.axi_user;
assign read_resp_header.cmd_metadata  = resp_info_fifo_data_out.cmd_metadata;
assign read_resp_header.axi_resp      = resp_info_fifo_data_out.axi_resp;
assign read_resp_header.magic_word    = MAGIC_WORD;
assign read_resp_header.axi4f_cmd     = AXI4F_CMD_RD_DATA_RESP;
assign read_resp_header.signature     = AXI4F_READ_SIGNATURE;


assign axi_stream_to_link.tlast = (axis_response_state == ST_DATA_MSB) & (axis_words_in_this_packet == resp_info_fifo_data_out.num_words);
assign axi_stream_to_link.tkeep = 32'hFFFFFFFF;
assign axi_stream_to_link.tvalid = axis_fifos_are_ready & ~resp_info_fifo_empty;
assign axi_stream_to_link.tdata = (axis_response_state == ST_DATA_LSB)? dt_fifo_data_out[255:0] :
                                  (axis_response_state == ST_DATA_MSB)? dt_fifo_data_out[511:256] : read_resp_header;

assign axis_data_taken = axi_stream_to_link.tvalid & axi_stream_to_link.tready;
assign resp_info_fifo_read = axis_data_taken & axi_stream_to_link.tlast;
assign dt_fifo_read = axis_data_taken & (axis_response_state == ST_DATA_MSB);

always_ff @(posedge axis_clk) begin
      if(reset_axis_side | ~axis_fifos_are_ready) begin
        axis_response_state <= ST_HEADER;
        axis_words_in_this_packet <= 1;
      end else begin
        axis_response_state <= axis_response_next_state;
        axis_words_in_this_packet <= (resp_info_fifo_read)? 1:
                                     (dt_fifo_read)? axis_words_in_this_packet + 1'b1 : axis_words_in_this_packet;
      end
      axis_fifos_are_ready <= ~(reset_axis_side | cmd_fifo_wr_rst_busy | metadata_fifo_wr_rst_busy | dt_fifo_rd_rst_busy | resp_info_fifo_rd_rst_busy);
end

always_comb begin
   case (axis_response_state)
      ST_HEADER:     if(axis_data_taken) axis_response_next_state = ST_DATA_LSB;
                     else axis_response_next_state = ST_HEADER;

      ST_DATA_LSB:   if(axis_data_taken) axis_response_next_state = ST_DATA_MSB;
                     else axis_response_next_state = ST_DATA_LSB;

      ST_DATA_MSB:   if(resp_info_fifo_read) axis_response_next_state = ST_HEADER;
                     else if(axis_data_taken) axis_response_next_state = ST_DATA_LSB;
                     else axis_response_next_state = ST_DATA_MSB;

      default:       axis_response_next_state = ST_ERROR;
   endcase
end
//###################################################################
//######################## AXI-F side logic #########################
//###################################################################

assign axi_full_to_host.rready = 1'b1;

assign axi_full_to_host.arid    = '0;
assign axi_full_to_host.araddr  = cmd_fifo_data_out.address;
assign axi_full_to_host.arregion= '0;
assign axi_full_to_host.arlen   = cmd_fifo_data_out.axi_len;
assign axi_full_to_host.arsize  = 3'b110;
assign axi_full_to_host.arburst = 2'b01;
assign axi_full_to_host.arvalid = new_command_is_ready;
assign axi_full_to_host.aruser  = '0;

assign cmd_fifo_read = axi_full_to_host.arvalid & axi_full_to_host.arready;
assign resp_info_fifo_write = axi_full_to_host.rvalid & axif_end_of_command;
assign metadata_fifo_read = axi_full_to_host.rvalid & axif_end_of_command;

assign resp_info_fifo_data_in.axi_id = metadata_fifo_data_out.axi_id;
assign resp_info_fifo_data_in.axi_user = metadata_fifo_data_out.axi_user;
assign resp_info_fifo_data_in.cmd_metadata = metadata_fifo_data_out.cmd_metadata;
assign resp_info_fifo_data_in.num_words = axif_words_in_this_packet;
assign resp_info_fifo_data_in.axi_resp = latched_resp_value | axi_full_to_host.rresp;

assign total_credit_check = pending_read_data[8:0] + dt_fifo_wr_data_count[8:0] + cmd_fifo_data_out.axi_len + 1'b1;

assign axif_end_of_command = axi_full_to_host.rlast;

always_ff @(posedge axif_clk) begin
      if(axif_reset | ~axif_fifos_are_ready) begin
         new_command_is_ready <= '0;
         have_enough_credit_for_command <= '0;
         pending_read_data <= '0;
         axif_words_in_this_packet <= 1;
         axif_command_word_count <= 1;
         latched_resp_value <= '0;
      end else begin
         new_command_is_ready <= (new_command_is_ready)? ~axi_full_to_host.arready : have_enough_credit_for_command;
         have_enough_credit_for_command <= (new_command_is_ready)? 1'b0 : ~(cmd_fifo_empty | total_credit_check[9]);
         pending_read_data <= (cmd_fifo_read)? pending_read_data + cmd_fifo_data_out.axi_len + {~axi_full_to_host.rvalid} :
                                               pending_read_data - axi_full_to_host.rvalid;
         axif_words_in_this_packet <= (resp_info_fifo_write)? 1 :
                                 (axi_full_to_host.rvalid)? axif_words_in_this_packet + 1'b1 : axif_words_in_this_packet;
         axif_command_word_count <= (metadata_fifo_read)? 1 :
                                    (axi_full_to_host.rvalid)? axif_command_word_count + 1'b1 : axif_command_word_count;
         latched_resp_value <= (metadata_fifo_read)? '0 :
                               (axi_full_to_host.rvalid)? latched_resp_value | axi_full_to_host.rresp : latched_resp_value;
      end
      axif_fifos_are_ready <= ~(axif_reset | cmd_fifo_rd_rst_busy | metadata_fifo_rd_rst_busy | dt_fifo_wr_rst_busy | resp_info_fifo_wr_rst_busy);
end
//###################################################################
//###################### Error tracking logic #######################
//###################################################################

assign status[0] = response_underflow;
assign status[1] = data_fifo_overflow;
assign status[2] = axif_command_timout;
assign status[3] = axif_response_timeout;

xpm_cdc_array_single #(
   .DEST_SYNC_FF(2),
   .SRC_INPUT_REG(0),
   .WIDTH(2)
)
axis_status_cdc_inst (
   .dest_out(status[5:4]),
   .dest_clk(axif_clk),
   .src_clk(axis_clk),
   .src_in({axis_timeout,axis_command_overflow})
);

assign status[31:6] = '0;

always_ff @(posedge axif_clk) begin
      if(axif_reset | ~axif_fifos_are_ready) begin
         response_underflow <= 1'b0;
         data_fifo_overflow <= 1'b0;
         axif_command_timout <= 1'b0;
         axif_response_timeout <= 1'b0;
         axif_command_timout_counter <= '0;
         axif_response_timeout_counter <= '0;
      end else begin
         response_underflow <= response_underflow | pending_read_data[9];
         data_fifo_overflow <= data_fifo_overflow | dt_fifo_wr_data_count[9] | (axi_full_to_host.rvalid & dt_fifo_full);
         axif_command_timout <= axif_command_timout | axif_command_timout_counter[20];
         axif_response_timeout <= axif_response_timeout | axif_response_timeout_counter[20];
         axif_command_timout_counter <= (cmd_fifo_read | cmd_fifo_empty)? '0 : axif_command_timout_counter + 1'b1;
         axif_response_timeout_counter <= (axi_full_to_host.rvalid | metadata_fifo_empty)? '0 : axif_response_timeout_counter + 1'b1;
      end
end


always_ff @(posedge axis_clk) begin
      if(reset_axis_side | ~axis_fifos_are_ready) begin
         axis_command_overflow <= 1'b0;
         axis_timeout <= 1'b0;
         axis_timeout_counter <= '0;
      end else begin
         axis_command_overflow <= axis_command_overflow | (received_new_command & metadata_fifo_full);
         axis_timeout <= axis_timeout | axis_timeout_counter[20];
         axis_timeout_counter <= (axi_stream_to_link.tready | resp_info_fifo_empty)? '0 : axis_timeout_counter + 1'b1;
      end
end

//###################################################################

xpm_fifo_async #(
   .FIFO_MEMORY_TYPE("auto"),
   .FIFO_READ_LATENCY(0),
   .FIFO_WRITE_DEPTH(512),
   .READ_DATA_WIDTH($size(axif_command_t)),
   .READ_MODE("fwft"),
   .USE_ADV_FEATURES("0000"),
   .WRITE_DATA_WIDTH($size(axif_command_t))
)
command_fifo
(
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
   .FIFO_WRITE_DEPTH(512),
   .READ_DATA_WIDTH(512),
   .READ_MODE("fwft"),
   .USE_ADV_FEATURES("0004"), // using write data count only
   .WR_DATA_COUNT_WIDTH(10),
   .WRITE_DATA_WIDTH(512)
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
   .rd_rst_busy(dt_fifo_rd_rst_busy),
   .sbiterr(),
   .underflow(),
   .wr_ack(),
   .wr_data_count(dt_fifo_wr_data_count),
   .wr_rst_busy(dt_fifo_wr_rst_busy),
   .din(axi_full_to_host.rdata),
   .injectdbiterr(1'b0),
   .injectsbiterr(1'b0),
   .rd_en(dt_fifo_read),
   .rst(axif_reset),
   .sleep(1'b0),
   .wr_clk(axif_clk),
   .rd_clk(axis_clk),
   .wr_en(axi_full_to_host.rvalid)
);


xpm_fifo_async #(
   .FIFO_MEMORY_TYPE("auto"),
   .FIFO_READ_LATENCY(0),
   .FIFO_WRITE_DEPTH(512),
   .READ_DATA_WIDTH($size(metadata_info_t)),
   .READ_MODE("fwft"),
   .USE_ADV_FEATURES("0000"),
   .WRITE_DATA_WIDTH($size(metadata_info_t))
)
metadata_header_fifo
(
   .almost_empty(),
   .almost_full(),
   .data_valid(),
   .dbiterr(),
   .dout(metadata_fifo_data_out),
   .empty(metadata_fifo_empty),
   .full(metadata_fifo_full),
   .overflow(),
   .prog_empty(),
   .prog_full(),
   .rd_data_count(),
   .rd_rst_busy(metadata_fifo_rd_rst_busy),
   .sbiterr(),
   .underflow(),
   .wr_ack(),
   .wr_data_count(),
   .wr_rst_busy(metadata_fifo_wr_rst_busy),
   .din(metadata_fifo_data_in),
   .injectdbiterr(1'b0),
   .injectsbiterr(1'b0),
   .rd_en(metadata_fifo_read),
   .rst(reset_axis_side),
   .sleep(1'b0),
   .wr_clk(axis_clk),
   .rd_clk(axif_clk),
   .wr_en(metadata_fifo_write)
);


xpm_fifo_async #(
   .FIFO_MEMORY_TYPE("auto"),
   .FIFO_READ_LATENCY(0),
   .FIFO_WRITE_DEPTH(512),
   .READ_DATA_WIDTH($size(resp_info_t)),
   .READ_MODE("fwft"),
   .USE_ADV_FEATURES("0000"),
   .WRITE_DATA_WIDTH($size(resp_info_t))
)
resp_info_fifo
(
   .almost_empty(),
   .almost_full(),
   .data_valid(),
   .dbiterr(),
   .dout(resp_info_fifo_data_out),
   .empty(resp_info_fifo_empty),
   .full(resp_info_fifo_full),
   .overflow(),
   .prog_empty(),
   .prog_full(),
   .rd_data_count(),
   .rd_rst_busy(resp_info_fifo_rd_rst_busy),
   .sbiterr(),
   .underflow(),
   .wr_ack(),
   .wr_data_count(),
   .wr_rst_busy(resp_info_fifo_wr_rst_busy),
   .din(resp_info_fifo_data_in),
   .injectdbiterr(1'b0),
   .injectsbiterr(1'b0),
   .rd_en(resp_info_fifo_read),
   .rst(axif_reset),
   .sleep(1'b0),
   .wr_clk(axif_clk),
   .rd_clk(axis_clk),
   .wr_en(resp_info_fifo_write)
);

endmodule
