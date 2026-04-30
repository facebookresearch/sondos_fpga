// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

module packetized_axi4l_master
  (
    input clk,
    input reset,
    so_axi4l_if.master axi_lite_to_user,

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
      logic [7:0] axi_id;       // 8 bits
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

typedef struct packed {
      logic [7:0] axi_region;
      logic [7:0] axi_id;
      logic [7:0] axi_user;
      logic [3:0] strb;
      logic [31:0] data;
      logic [31:0] address;
      logic [31:0] cmd_id;
} command_info_t;

typedef enum logic [2:0] {
      ST_W_READY                = 3'b000,
      ST_W_SEND_ADDRESS_DATA    = 3'b001,
      ST_W_SEND_DATA            = 3'b010,
      ST_W_SEND_ADDRESS         = 3'b011,
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

command_info_t read_command;
command_info_t write_command;

axi4l_packet_t read_resp_packet;
axi4l_packet_t write_resp_packet;
axi4l_packet_t command_packet;

logic [17:0] write_timer;
logic write_timeout_error;
logic [17:0] read_timer;
logic read_timeout_error;

logic read_data_sent;
logic write_ack_sent;
logic received_read_cmd;
logic received_write_cmd;

logic [31:0] read_data;
logic [1:0] read_resp;
logic [1:0] write_resp;



assign axi_stream_from_link.tready = 1'b1;
assign command_packet = axi_stream_from_link.tdata;

assign write_timeout_error  = write_timer[17];
assign read_timeout_error  = read_timer[17];

assign read_data_sent = axi_stream_to_link.tready & (read_state==ST_R_SEND_DATA);
assign write_ack_sent = axi_stream_to_link.tready & (write_state==ST_W_SEND_ACK) & ~(read_state==ST_R_SEND_DATA);

assign received_read_cmd =  axi_stream_from_link.tvalid &
                            (command_packet.signature == AXI4L_SIGNATURE) &
                            (command_packet.axi4l_cmd == AXI4L_CMD_RD_ADDR) &
                            (command_packet.magic_word== MAGIC_WORD);


assign received_write_cmd = axi_stream_from_link.tvalid &
                            (command_packet.signature == AXI4L_SIGNATURE) &
                            (command_packet.axi4l_cmd == AXI4L_CMD_WR_ADDR_DATA) &
                            (command_packet.magic_word== MAGIC_WORD);


assign write_resp_packet.dummy_2    = '0;
assign write_resp_packet.axi_region = '0;
assign write_resp_packet.axi_id     = write_command.axi_id;
assign write_resp_packet.axi_user   = write_command.axi_user;
assign write_resp_packet.dummy_1    = '0;
assign write_resp_packet.resp       = write_resp;
assign write_resp_packet.strb       = '0;
assign write_resp_packet.data       = '0;
assign write_resp_packet.address    = '0;
assign write_resp_packet.cmd_id     = write_command.cmd_id;
assign write_resp_packet.magic_word = MAGIC_WORD;
assign write_resp_packet.axi4l_cmd  = AXI4L_CMD_WR_RESP;
assign write_resp_packet.signature  = AXI4L_SIGNATURE;

assign read_resp_packet.dummy_2    = '0;
assign read_resp_packet.axi_region = '0;
assign read_resp_packet.axi_id     = read_command.axi_id;
assign read_resp_packet.axi_user   = read_command.axi_user;
assign read_resp_packet.dummy_1    = '0;
assign read_resp_packet.resp       = '0;
assign read_resp_packet.strb       = '0;
assign read_resp_packet.data       = read_data;
assign read_resp_packet.address    = '0;
assign read_resp_packet.cmd_id     = read_command.cmd_id;
assign read_resp_packet.magic_word = MAGIC_WORD;
assign read_resp_packet.axi4l_cmd  = AXI4L_CMD_RD_DATA_RESP;
assign read_resp_packet.signature  = AXI4L_SIGNATURE;


assign axi_stream_to_link.tlast = 1'b1;
assign axi_stream_to_link.tkeep = 32'h00FFFFFF;
assign axi_stream_to_link.tvalid = (write_state==ST_W_SEND_ACK) | (read_state==ST_R_SEND_DATA);
assign axi_stream_to_link.tdata = (read_state==ST_R_SEND_DATA)? read_resp_packet : write_resp_packet;


assign axi_lite_to_user.awid = write_command.axi_id;
assign axi_lite_to_user.awaddr = write_command.address;
assign axi_lite_to_user.awprot = '0;
assign axi_lite_to_user.awqos = '0;
assign axi_lite_to_user.awregion = write_command.axi_region;
assign axi_lite_to_user.awuser = write_command.axi_user;
assign axi_lite_to_user.awvalid = (write_state == ST_W_SEND_ADDRESS_DATA) | (write_state == ST_W_SEND_ADDRESS);

assign axi_lite_to_user.wdata = write_command.data;
assign axi_lite_to_user.wstrb = write_command.strb;
assign axi_lite_to_user.wuser = write_command.axi_user;
assign axi_lite_to_user.wvalid = (write_state == ST_W_SEND_ADDRESS_DATA) | (write_state == ST_W_SEND_DATA);

assign axi_lite_to_user.bready = (write_state == ST_W_GET_ACK);

assign axi_lite_to_user.arid = read_command.axi_id;
assign axi_lite_to_user.araddr = read_command.address;
assign axi_lite_to_user.arprot = '0;
assign axi_lite_to_user.arqos = '0;
assign axi_lite_to_user.arregion = read_command.axi_region;
assign axi_lite_to_user.aruser = read_command.axi_user;
assign axi_lite_to_user.arvalid = (read_state == ST_R_SEND_ADDRESS);

assign axi_lite_to_user.rready = (read_state == ST_R_GET_DATA);



always_ff @(posedge clk) begin
    if(reset) begin
        write_state <= ST_W_READY;
        write_timer <= '0;

        read_state <= ST_R_READY;
        read_timer <= '0;
    end else begin
        write_state <= (write_timeout_error & (write_state == ST_W_GET_ACK))? ST_W_SEND_ACK : write_next_state;
        write_timer <= (write_state == ST_W_READY)? '0 :
                       (write_timeout_error)? write_timer : write_timer + 1'b1;

        read_state <= (read_timeout_error & (read_state == ST_R_GET_DATA))? ST_R_SEND_DATA : read_next_state;
        read_timer <= (read_state == ST_R_READY)? '0 :
                      (read_timeout_error)? read_timer : read_timer + 1'b1;
    end

    write_command.address       <= (write_state == ST_W_READY)? command_packet.address   : write_command.address;
    write_command.axi_region    <= (write_state == ST_W_READY)? command_packet.axi_region: write_command.axi_region;
    write_command.axi_id        <= (write_state == ST_W_READY)? command_packet.axi_id    : write_command.axi_id;
    write_command.axi_user      <= (write_state == ST_W_READY)? command_packet.axi_user  : write_command.axi_user;
    write_command.data          <= (write_state == ST_W_READY)? command_packet.data      : write_command.data;
    write_command.strb          <= (write_state == ST_W_READY)? command_packet.strb      : write_command.strb;
    write_command.cmd_id        <= (write_state == ST_W_READY)? command_packet.cmd_id    : write_command.cmd_id;

    read_command.address        <= (read_state == ST_R_READY)? command_packet.address   : read_command.address;
    read_command.axi_region     <= (read_state == ST_R_READY)? command_packet.axi_region: read_command.axi_region;
    read_command.axi_id         <= (read_state == ST_R_READY)? command_packet.axi_id    : read_command.axi_id;
    read_command.axi_user       <= (read_state == ST_R_READY)? command_packet.axi_user  : read_command.axi_user;
    read_command.cmd_id         <= (read_state == ST_R_READY)? command_packet.cmd_id    : read_command.cmd_id;

    read_data <= (read_timeout_error)? {32'hDEADFEED}:
                 (read_state == ST_R_GET_DATA)? axi_lite_to_user.rdata : read_data;

    read_resp <= (read_timeout_error)? 2'b11:
                 (read_state == ST_R_GET_DATA)? axi_lite_to_user.rresp : read_resp;

    write_resp <= (write_timeout_error)? 2'b11:
                  (write_state == ST_W_GET_ACK)? axi_lite_to_user.bresp : write_resp;

end


always_comb begin
    case(write_state)
        ST_W_READY              :   if(received_write_cmd) write_next_state = ST_W_SEND_ADDRESS_DATA;
                                    else write_next_state = ST_W_READY;

        ST_W_SEND_ADDRESS_DATA  :   if(axi_lite_to_user.awready & axi_lite_to_user.wready) write_next_state = ST_W_GET_ACK;
                                    else if(axi_lite_to_user.awready) write_next_state = ST_W_SEND_DATA;
                                    else if(axi_lite_to_user.wready) write_next_state = ST_W_SEND_ADDRESS;
                                    else write_next_state = ST_W_SEND_ADDRESS_DATA;

        ST_W_SEND_ADDRESS       :   if(axi_lite_to_user.awready) write_next_state = ST_W_GET_ACK;
                                    else write_next_state = ST_W_SEND_ADDRESS;

        ST_W_SEND_DATA          :   if(axi_lite_to_user.wvalid) write_next_state = ST_W_GET_ACK;
                                    else write_next_state = ST_W_SEND_DATA;

        ST_W_GET_ACK            :   if(axi_lite_to_user.bvalid) write_next_state = ST_W_SEND_ACK;
                                    else write_next_state = ST_W_GET_ACK;

        ST_W_SEND_ACK           :   if(write_ack_sent) write_next_state = ST_W_READY;
                                    else write_next_state = ST_W_SEND_ACK;

        default                 :   write_next_state = ST_W_READY;
    endcase
end

always_comb begin
    case(read_state)
        ST_R_READY      :   if(received_read_cmd) read_next_state = ST_R_SEND_ADDRESS;
                            else read_next_state = ST_R_READY;

        ST_R_SEND_ADDRESS:  if(axi_lite_to_user.arready) read_next_state = ST_R_GET_DATA;
                            else read_next_state = ST_R_SEND_ADDRESS;

        ST_R_GET_DATA   :   if(axi_lite_to_user.rvalid) read_next_state = ST_R_SEND_DATA;
                            else read_next_state = ST_R_GET_DATA;

        ST_R_SEND_DATA  :   if(read_data_sent) read_next_state = ST_R_READY;
                            else read_next_state = ST_R_SEND_DATA;

        default         :   read_next_state = ST_R_READY;
    endcase
end

endmodule
