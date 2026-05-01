// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

module packetized_axi4l_slave
  (
    input host_clk,
    input user_clk,
    input reset,
    so_axi4l_if.slave axi_lite_from_host,

    so_axi4s_if.master axi_stream_to_link,
    so_axi4s_if.slave axi_stream_from_link
 );

parameter logic [7:0] AXI4L_SIGNATURE = 8'h99;

localparam int AXIS_DATAWIDTH = $size(axi_stream_to_link.tdata);
localparam int TKEEP_WIDTH = $clog2(AXIS_DATAWIDTH);
localparam logic [47:0] MAGIC_WORD = 48'hFACEB00CBABE;

typedef enum logic [7:0] {
      AXI4L_CMD_WR_ADDR_DATA    = 8'h90,
      AXI4L_CMD_WR_RESP         = 8'h91,
      AXI4L_CMD_RD_ADDR         = 8'h92,
      AXI4L_CMD_RD_DATA_RESP    = 8'h93
} axi4l_cmd_t;

typedef struct packed { // 192 bits packet over a 256-bits axis, tkeep is set accordingly
      logic [63:0] dummy_2;     // 64 bits
      logic [7:0] axi_region;   // 8 bits
      logic [7:0] axi_id;      // 8 bits
      logic [7:0] axi_user;     // 8 bits
      logic [1:0] dummy_1;      // 2 bits
      logic [1:0] resp;         // 2 bits
      logic [3:0] strb;         // 4 bits
      logic [31:0] data;        // 32 bits
      logic [31:0] address;     // 32 bits
      logic [31:0] cmd_id;      // 32 bits
      logic [47:0] magic_word;  // 48 bits
      axi4l_cmd_t axi4l_cmd;    // 8 bits
      logic [7:0] signature;     // 8 bits
} axi4l_packet_t;

typedef enum logic [2:0] {
      ST_W_READY                = 3'b000,
      ST_W_GET_DATA             = 3'b001,
      ST_W_GET_ADDRESS          = 3'b010,
      ST_W_SEND_ADDRESS_DATA    = 3'b011,
      ST_W_GET_ACK              = 3'b100,
      ST_W_SEND_ACK             = 3'b101
   } w_state_t;

typedef enum logic [1:0] {
      ST_R_READY        = 2'b00,
      ST_R_SEND_ADDRESS = 2'b01,
      ST_R_GET_DATA     = 2'b10,
      ST_R_SEND_DATA    = 2'b11
   } r_state_t;

w_state_t write_state;
w_state_t write_next_state;
r_state_t read_state;
r_state_t read_next_state;

axi4l_packet_t read_command_packet;
axi4l_packet_t write_command_packet;
axi4l_packet_t response_packet;
axi4l_packet_t response_packet_sync;
axi4l_packet_t selected_packet;
axi4l_packet_t selected_packet_sync;

logic [18:0] write_timer;
logic write_timeout_error;
logic [18:0] read_timer;
logic read_timeout_error;

logic read_address_sent;
logic write_address_data_sent;
logic received_read_data;
logic received_write_ack;
logic write_id_mismatch;
logic read_id_mismatch;

logic write_op_complete;
logic read_op_complete;

logic [31:0] read_data;
logic [1:0] read_resp;
logic [7:0] read_resp_user;
logic [7:0] read_resp_id;
logic [1:0] write_resp;
logic [7:0] write_resp_user;
logic [7:0] write_resp_id;

logic user_reset;
logic c2h_sync_handshake_req;
logic c2h_sync_handshake_resp;
logic c2h_sync_data_valid;

logic h2c_sync_handshake_host_req;
logic h2c_sync_handshake_host_resp;
logic h2c_sync_handshake_user_req;
logic h2c_sync_handshake_user_resp;

//////////////////////////////////////////////////////////////////////////////
assign axi_stream_to_link.tlast = 1'b1;
assign axi_stream_to_link.tkeep = 32'h00FFFFFF;
assign axi_stream_to_link.tvalid = h2c_sync_handshake_user_req & ~h2c_sync_handshake_user_resp;
assign axi_stream_to_link.tdata = selected_packet_sync;

assign selected_packet = (read_state==ST_R_SEND_ADDRESS)? read_command_packet : write_command_packet;

xpm_cdc_handshake #(
   .DEST_EXT_HSK(1),
   .DEST_SYNC_FF(3),
   .SRC_SYNC_FF(3),
   .WIDTH($bits(response_packet))
)
xpm_cdc_handshake_h2c_inst (
   .dest_out(selected_packet_sync),
   .dest_req(h2c_sync_handshake_user_req),
   .src_rcv(h2c_sync_handshake_host_resp),
   .dest_ack(h2c_sync_handshake_user_resp),
   .dest_clk(user_clk),
   .src_clk(host_clk),
   .src_in(selected_packet),
   .src_send(h2c_sync_handshake_host_req)
);

always_ff @(posedge user_clk) begin
    if(user_reset) begin
        h2c_sync_handshake_user_resp <= 1'b0;
    end else begin
        h2c_sync_handshake_user_resp <= (h2c_sync_handshake_user_resp)? h2c_sync_handshake_user_req : h2c_sync_handshake_user_req & axi_stream_to_link.tready;
    end
end

always_ff @(posedge host_clk) begin
    if(reset) begin
        h2c_sync_handshake_host_req <= 1'b0;
    end else begin
        h2c_sync_handshake_host_req <= (h2c_sync_handshake_host_req)? ~h2c_sync_handshake_host_resp :
                                            ((write_state==ST_W_SEND_ADDRESS_DATA) | (read_state==ST_R_SEND_ADDRESS)) & ~h2c_sync_handshake_host_resp;
    end
end

///////////////////////////////////////////////////////////////////////////////////////////////
assign axi_stream_from_link.tready = 1'b1;

xpm_cdc_sync_rst #(
   .DEST_SYNC_FF(4),   // DECIMAL; range: 2-10
   .INIT(1))
xpm_cdc_sync_rst_inst (
   .dest_rst(user_reset),
   .dest_clk(user_clk),
   .src_rst(reset)
);

xpm_cdc_handshake #(
   .DEST_EXT_HSK(0),
   .DEST_SYNC_FF(3),
   .SRC_SYNC_FF(3),
   .WIDTH($bits(response_packet))
)
xpm_cdc_handshake_c2h_inst (
   .dest_out(response_packet_sync),
   .dest_req(c2h_sync_data_valid),
   .src_rcv(c2h_sync_handshake_resp),
   .dest_ack(),
   .dest_clk(host_clk),
   .src_clk(user_clk),
   .src_in(response_packet),
   .src_send(c2h_sync_handshake_req)
);

always_ff @(posedge user_clk) begin
    if(user_reset) begin
        c2h_sync_handshake_req <= 1'b0;
    end else begin
        c2h_sync_handshake_req <= (c2h_sync_handshake_req)? ~c2h_sync_handshake_resp : axi_stream_from_link.tvalid;
    end
    response_packet <= (axi_stream_from_link.tvalid)? axi_stream_from_link.tdata : response_packet;
end
///////////////////////////////////////////////////////////////////////////////////////////////

assign write_timeout_error  = write_timer[18];
assign read_timeout_error  = read_timer[18];

assign read_address_sent = h2c_sync_handshake_host_req & h2c_sync_handshake_host_resp & (read_state==ST_R_SEND_ADDRESS);
assign write_address_data_sent = h2c_sync_handshake_host_req & h2c_sync_handshake_host_resp &
                                 (write_state==ST_W_SEND_ADDRESS_DATA) & ~(read_state==ST_R_SEND_ADDRESS);

assign received_read_data = c2h_sync_data_valid &
                            (response_packet_sync.signature == AXI4L_SIGNATURE) &
                            (response_packet_sync.axi4l_cmd == AXI4L_CMD_RD_DATA_RESP) &
                            (response_packet_sync.magic_word== MAGIC_WORD) &
                            (response_packet_sync.cmd_id    == read_command_packet.cmd_id);


assign received_write_ack = c2h_sync_data_valid &
                            (response_packet_sync.signature == AXI4L_SIGNATURE) &
                            (response_packet_sync.axi4l_cmd == AXI4L_CMD_WR_RESP) &
                            (response_packet_sync.magic_word== MAGIC_WORD) &
                            (response_packet_sync.cmd_id    == write_command_packet.cmd_id);

assign write_id_mismatch = ~(response_packet_sync.cmd_id == write_command_packet.cmd_id);
assign read_id_mismatch  = ~(response_packet_sync.cmd_id == read_command_packet.cmd_id);

assign axi_lite_from_host.awready = (write_state == ST_W_READY) | (write_state == ST_W_GET_ADDRESS);

assign axi_lite_from_host.wready = (write_state == ST_W_READY) | (write_state == ST_W_GET_DATA);

assign axi_lite_from_host.bid = write_command_packet.axi_id;
assign axi_lite_from_host.bresp = write_resp;
assign axi_lite_from_host.buser = write_command_packet.axi_user;
assign axi_lite_from_host.bvalid = (write_state == ST_W_SEND_ACK);

assign axi_lite_from_host.arready = (read_state == ST_R_READY);

assign axi_lite_from_host.rid = read_command_packet.axi_id;
assign axi_lite_from_host.rdata = read_data;
assign axi_lite_from_host.rresp = read_resp;
assign axi_lite_from_host.ruser = read_command_packet.axi_user;
assign axi_lite_from_host.rvalid = (read_state == ST_R_SEND_DATA);


always_ff @(posedge host_clk) begin
    if(reset) begin
        write_state <= ST_W_READY;
        write_timer <= '0;
        write_op_complete <= 1'b0;

        read_state <= ST_R_READY;
        read_timer <= '0;
        read_op_complete <= 1'b0;
    end else begin
        write_state <= (write_timeout_error & ((write_state == ST_W_GET_ACK)|(write_state == ST_W_SEND_ADDRESS_DATA)))? ST_W_SEND_ACK : write_next_state;
        write_timer <= (write_state == ST_W_READY)? '0 :
                       (write_timeout_error)? write_timer : write_timer + 1'b1;
        write_op_complete <= axi_lite_from_host.bready & axi_lite_from_host.bvalid;

        read_state <= (read_timeout_error & ((read_state == ST_R_GET_DATA)|(read_state == ST_R_SEND_ADDRESS)))? ST_R_SEND_DATA : read_next_state;
        read_timer <= (read_state == ST_R_READY)? '0 :
                      (read_timeout_error)? read_timer : read_timer + 1'b1;
        read_op_complete <= axi_lite_from_host.rready & axi_lite_from_host.rvalid;
    end

    write_command_packet.dummy_2    <= '0;
    write_command_packet.axi_region <= (axi_lite_from_host.awready)? axi_lite_from_host.awregion : write_command_packet.axi_region;
    write_command_packet.axi_id     <= (axi_lite_from_host.awready)? axi_lite_from_host.awid : write_command_packet.axi_id;
    write_command_packet.axi_user   <= (axi_lite_from_host.awready)? axi_lite_from_host.awuser : write_command_packet.axi_user;
    write_command_packet.dummy_1    <= '0;
    write_command_packet.resp       <= '0;
    write_command_packet.strb       <= (axi_lite_from_host.wready)? axi_lite_from_host.wstrb : write_command_packet.strb;
    write_command_packet.data       <= (axi_lite_from_host.wready)? axi_lite_from_host.wdata : write_command_packet.data;
    write_command_packet.address    <= (axi_lite_from_host.awready)? axi_lite_from_host.awaddr : write_command_packet.address;
    write_command_packet.cmd_id     <= (reset)? '0 : write_command_packet.cmd_id + write_op_complete;
    write_command_packet.magic_word <= MAGIC_WORD;
    write_command_packet.axi4l_cmd  <= AXI4L_CMD_WR_ADDR_DATA;
    write_command_packet.signature  <= AXI4L_SIGNATURE;


    read_command_packet.dummy_2    <= '0;
    read_command_packet.axi_region <= (axi_lite_from_host.arready)? axi_lite_from_host.arregion : read_command_packet.axi_region;
    read_command_packet.axi_id     <= (axi_lite_from_host.arready)? axi_lite_from_host.arid : read_command_packet.axi_id;
    read_command_packet.axi_user   <= (axi_lite_from_host.arready)? axi_lite_from_host.aruser : read_command_packet.axi_user;
    read_command_packet.dummy_1    <= '0;
    read_command_packet.resp       <= '0;
    read_command_packet.strb       <= '0;
    read_command_packet.data       <= '0;
    read_command_packet.address    <= (axi_lite_from_host.arready)? axi_lite_from_host.araddr : read_command_packet.address;
    read_command_packet.cmd_id     <= (reset)? '0 : read_command_packet.cmd_id + read_op_complete;
    read_command_packet.magic_word <= MAGIC_WORD;
    read_command_packet.axi4l_cmd  <= AXI4L_CMD_RD_ADDR;
    read_command_packet.signature  <= AXI4L_SIGNATURE;

    read_data <= (read_timeout_error)? {32'hDEADBEEF}:
                 (read_state == ST_R_GET_DATA)? response_packet_sync.data : read_data;

    read_resp <= (read_timeout_error)? 2'b11:
                 (read_state == ST_R_GET_DATA)? response_packet_sync.resp : read_resp;

    write_resp <= (write_timeout_error)? 2'b11:
                  (write_state == ST_W_GET_ACK)? response_packet_sync.resp : write_resp;

end


always_comb begin
    case(write_state)
        ST_W_READY              :   if(axi_lite_from_host.awvalid & axi_lite_from_host.wvalid) write_next_state = ST_W_SEND_ADDRESS_DATA;
                                    else if(axi_lite_from_host.awvalid) write_next_state = ST_W_GET_DATA;
                                    else if(axi_lite_from_host.wvalid) write_next_state = ST_W_GET_ADDRESS;
                                    else write_next_state = ST_W_READY;

        ST_W_GET_ADDRESS        :   if(axi_lite_from_host.awvalid) write_next_state = ST_W_SEND_ADDRESS_DATA;
                                    else write_next_state = ST_W_GET_ADDRESS;

        ST_W_GET_DATA           :   if(axi_lite_from_host.wvalid) write_next_state = ST_W_SEND_ADDRESS_DATA;
                                    else write_next_state = ST_W_GET_DATA;

        ST_W_SEND_ADDRESS_DATA  :   if(write_address_data_sent) write_next_state = ST_W_GET_ACK;
                                    else write_next_state = ST_W_SEND_ADDRESS_DATA;

        ST_W_GET_ACK            :   if(received_write_ack) write_next_state = ST_W_SEND_ACK;
                                    else write_next_state = ST_W_GET_ACK;

        ST_W_SEND_ACK           :   if(axi_lite_from_host.bready) write_next_state = ST_W_READY;
                                    else write_next_state = ST_W_SEND_ACK;

        default                 :   write_next_state = ST_W_READY;
    endcase
end

always_comb begin
    case(read_state)
        ST_R_READY      :   if(axi_lite_from_host.arvalid) read_next_state = ST_R_SEND_ADDRESS;
                            else read_next_state = ST_R_READY;

        ST_R_SEND_ADDRESS:  if(read_address_sent) read_next_state = ST_R_GET_DATA;
                            else read_next_state = ST_R_SEND_ADDRESS;

        ST_R_GET_DATA   :   if(received_read_data) read_next_state = ST_R_SEND_DATA;
                            else read_next_state = ST_R_GET_DATA;

        ST_R_SEND_DATA  :   if(axi_lite_from_host.rready) read_next_state = ST_R_READY;
                            else read_next_state = ST_R_SEND_DATA;

        default         :   read_next_state = ST_R_READY;
    endcase
end

endmodule
