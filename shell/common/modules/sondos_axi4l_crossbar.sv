// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
// Title:  AXI4-Lite Crossbar (1:N)
//-----------------------------------------------------------------------------
// Description: A simple 1:N AXI4-Lite crossbar.
//-----------------------------------------------------------------------------

module sondos_axi4l_crossbar
import so_axi4l_if_pkg::*;
#(
   parameter int P_NUM_LEAFS  = 2
)(
   input wire                 aclk,
   input wire                 aresetn,
   input wire [P_NUM_LEAFS-1:0][1:0][63:0] map,
   so_axi4l_if.slave          trunk_bus,
   so_axi4l_if.master         leaf_bus [P_NUM_LEAFS-1:0]
);

//==========================================================
// Declarations
//==========================================================
localparam int P_TRUNK_ADDR_WIDTH   = $size(trunk_bus.awaddr);
localparam int P_LEAF_ADDR_WIDTH    = $size(leaf_bus[0].awaddr);
localparam int P_DATA_WIDTH         = $size(trunk_bus.wdata);
localparam int P_NUM_LEAFS_NBITS    = $clog2(P_NUM_LEAFS);

typedef enum logic [3:0] {
   STATE_W_IDLE,
   STATE_W_TRUNK_DATA_RX,
   STATE_W_TRUNK_ADDR_RX,
   STATE_W_BAD_ADDR,
   STATE_W_INITIATED,
   STATE_W_LEAF_DATA_TX,
   STATE_W_LEAF_ADDR_TX,
   STATE_W_LEAF_RESP_RX,
   STATE_W_TRUNK_RESP_PEND
} state_w_t;

state_w_t state_w;
state_w_t state_w_next;

typedef enum logic [2:0] {
   STATE_R_IDLE,
   STATE_R_BAD_ADDR,
   STATE_R_INITIATED,
   STATE_R_LEAF_ADDR_TX,
   STATE_R_LEAF_DATA_RX,
   STATE_R_TRUNK_DATA_TX
} state_r_t;

state_r_t state_r;
state_r_t state_r_next;

logic [P_NUM_LEAFS_NBITS-1:0] write_sel;           // Write request to send write to
logic [P_NUM_LEAFS_NBITS-1:0] write_sel_pre;
logic [P_NUM_LEAFS_NBITS-1:0] write_sel_next;
logic                         write_valid;         // Write request matches a leaf address range
logic                         write_valid_pre;
logic                         write_valid_next;
logic [P_LEAF_ADDR_WIDTH-1:0] awaddr;              // awaddr from trunk to leaf
logic [P_LEAF_ADDR_WIDTH-1:0] awaddr_next;
logic                         l_awvalid;
logic                         l_wvalid;
logic                         l_bready;
logic [P_DATA_WIDTH-1:0]      wdata;               // awaddr from trunk to leaf
logic [P_DATA_WIDTH-1:0]      wdata_next;
logic [1:0]                   bresp_i[P_NUM_LEAFS];// bresp from leaf to trunk
logic [1:0]                   bresp;               // bresp from leaf to trunk
logic                         trunk_awaddr_shake;  // indicates awaddr handshake
logic                         trunk_wdata_shake;   // indicates wdata  handshake
logic                         trunk_bresp_shake;   // indicates bresp  handshake
logic [P_NUM_LEAFS-1:0]       leaf_awaddr_shake;   // indicates awaddr handshake
logic [P_NUM_LEAFS-1:0]       leaf_wdata_shake;    // indicates wdata  handshake
logic [P_NUM_LEAFS-1:0]       leaf_bresp_shake;    // indicates bresp  handshake

logic [P_NUM_LEAFS_NBITS-1:0] read_sel;            // Read request to send read to
logic [P_NUM_LEAFS_NBITS-1:0] read_sel_pre;
logic [P_NUM_LEAFS_NBITS-1:0] read_sel_next;
logic                         read_valid;          // Read request matches a leaf address range
logic                         read_valid_pre;
logic                         read_valid_next;
logic [P_LEAF_ADDR_WIDTH-1:0] araddr;              // araddr from trunk to leaf
logic [P_LEAF_ADDR_WIDTH-1:0] araddr_next;
logic                         l_arvalid;
logic                         l_rready;
logic [P_DATA_WIDTH-1:0]      rdata_i[P_NUM_LEAFS];// combinational read data
logic [P_DATA_WIDTH-1:0]      rdata;               // rdata from leaf to trunk
logic [1:0]                   rresp_i[P_NUM_LEAFS];// combinational read resp
logic [1:0]                   rresp;               // rresp from leaf to trunk
logic                         trunk_araddr_shake;  // indicates awaddr handshake
logic                         trunk_rdata_shake;   // indicates wdata  handshake
logic [P_NUM_LEAFS-1:0]       leaf_araddr_shake;   // indicates awaddr handshake
logic [P_NUM_LEAFS-1:0]       leaf_rdata_shake;    // indicates wdata  handshake

//==========================================================
// Logic
//==========================================================

//========================================================
// Write side
//========================================================

always_comb begin
   write_sel_pre           = 0;
   write_valid_pre         = 1'b0;

   for (int i=0; i<P_NUM_LEAFS; i++) begin
      if ((trunk_bus.awaddr[P_TRUNK_ADDR_WIDTH-1:0] <= map[i][1][P_TRUNK_ADDR_WIDTH-1:0]) &&
          (trunk_bus.awaddr[P_TRUNK_ADDR_WIDTH-1:0] >= map[i][0][P_TRUNK_ADDR_WIDTH-1:0])) begin
         write_sel_pre     = i;
         write_valid_pre   = 1'b1;
      end
   end

   // Convenience Handshakes
   trunk_awaddr_shake = trunk_bus.awready & trunk_bus.awvalid;
   trunk_wdata_shake  = trunk_bus.wready  & trunk_bus.wvalid;
   trunk_bresp_shake  = trunk_bus.bready  & trunk_bus.bvalid;

   // Update AWADDR and WDATA on Successful Handshakes
   awaddr_next = (trunk_awaddr_shake) ? trunk_bus.awaddr : awaddr;
   wdata_next  = (trunk_wdata_shake)  ? trunk_bus.wdata  : wdata;

   if (!aresetn) begin
      trunk_bus.awready    = 1'b0;
      trunk_bus.wready     = 1'b0;
      trunk_bus.bvalid     = 1'b0;
      trunk_bus.bresp      = C_SO_AXI4L_RESP_OKAY;
      l_awvalid            = 1'b0;
      l_wvalid             = 1'b0;
      l_bready             = 1'b0;
      write_sel_next       = '0;
      write_valid_next     = 1'b0;
      state_w_next         = STATE_W_IDLE;
   end else begin
      case (state_w)
         STATE_W_IDLE: begin
            trunk_bus.awready    = 1'b1;
            trunk_bus.wready     = 1'b1;
            trunk_bus.bvalid     = 1'b0;
            trunk_bus.bresp      = C_SO_AXI4L_RESP_OKAY;
            l_awvalid            = 1'b0;
            l_wvalid             = 1'b0;
            l_bready             = 1'b0;

            // Got Valid Address and Data
            if (trunk_awaddr_shake && write_valid_pre && trunk_wdata_shake) begin
               write_sel_next    = write_sel_pre;
               write_valid_next  = write_valid_pre;
               state_w_next      = STATE_W_INITIATED;
            // Got Invalid Address and Data
            end else if (trunk_awaddr_shake && !write_valid_pre && trunk_wdata_shake) begin
               write_sel_next    = write_sel_pre;
               write_valid_next  = write_valid_pre;
               state_w_next      = STATE_W_BAD_ADDR;
            // Got an Address but not Data
            end else if (trunk_awaddr_shake && !trunk_wdata_shake) begin
               write_sel_next    = write_sel_pre;
               write_valid_next  = write_valid_pre;
               state_w_next      = STATE_W_TRUNK_ADDR_RX;
            // Got Data but not Address
            end else if (!trunk_awaddr_shake && trunk_wdata_shake) begin
               write_sel_next    = write_sel;
               write_valid_next  = write_valid;
               state_w_next      = STATE_W_TRUNK_DATA_RX;
            // Got Nothing
            end else begin
               write_sel_next    = write_sel;
               write_valid_next  = write_valid;
               state_w_next      = state_w;
            end
         end
         // Write Transaction, Data Received, Waiting for Addr
         STATE_W_TRUNK_DATA_RX: begin
            trunk_bus.awready    = 1'b1;
            trunk_bus.wready     = 1'b0;
            trunk_bus.bvalid     = 1'b0;
            trunk_bus.bresp      = C_SO_AXI4L_RESP_OKAY;
            l_awvalid            = 1'b0;
            l_wvalid             = 1'b0;
            l_bready             = 1'b0;

            // Got Address and was Valid
            if (trunk_awaddr_shake && write_valid_pre) begin
               write_sel_next    = write_sel_pre;
               write_valid_next  = write_valid_pre;
               state_w_next      = STATE_W_INITIATED;
            // Got Address and was Invalid
            end else if (trunk_awaddr_shake && !write_valid_pre) begin
               write_sel_next    = write_sel_pre;
               write_valid_next  = write_valid_pre;
               state_w_next      = STATE_W_BAD_ADDR;
            // Got Nothing
            end else begin
               write_sel_next    = write_sel;
               write_valid_next  = write_valid;
               state_w_next      = state_w;
            end
         end
         // Write Transaction, Address Received, Waiting for Data
         STATE_W_TRUNK_ADDR_RX: begin
            trunk_bus.awready    = 1'b0;
            trunk_bus.wready     = 1'b1;
            trunk_bus.bvalid     = 1'b0;
            trunk_bus.bresp      = C_SO_AXI4L_RESP_OKAY;
            l_awvalid            = 1'b0;
            l_wvalid             = 1'b0;
            l_bready             = 1'b0;
            write_sel_next       = write_sel;
            write_valid_next     = write_valid;

            // Got Data, Address was Valid
            if (trunk_wdata_shake && write_valid) begin
               state_w_next      = STATE_W_INITIATED;
            // Got Data, Address was Invalid
            end else if (trunk_wdata_shake && !write_valid) begin
               state_w_next      = STATE_W_BAD_ADDR;
            // Got Nothing
            end else begin
               state_w_next      = state_w;
            end
         end
         // Complete Write Transaction, Address Was Invalid
         STATE_W_BAD_ADDR: begin
            trunk_bus.awready    = 1'b0;
            trunk_bus.wready     = 1'b0;
            trunk_bus.bvalid     = 1'b1;
            trunk_bus.bresp      = C_SO_AXI4L_RESP_DECERR;
            l_awvalid            = 1'b0;
            l_wvalid             = 1'b0;
            l_bready             = 1'b0;
            write_sel_next       = write_sel;
            write_valid_next     = write_valid;

            if (trunk_bresp_shake) begin
               state_w_next      = STATE_W_IDLE;
            end else begin
               state_w_next      = state_w;
            end
         end
         // Complete Write Transaction, Address was Valid
         STATE_W_INITIATED: begin
            trunk_bus.awready    = 1'b0;
            trunk_bus.wready     = 1'b0;
            trunk_bus.bvalid     = 1'b0;
            trunk_bus.bresp      = C_SO_AXI4L_RESP_OKAY;
            l_awvalid            = 1'b1;
            l_wvalid             = 1'b1;
            l_bready             = 1'b0;
            write_sel_next       = write_sel;
            write_valid_next     = write_valid;

            // Leaf Accepted both Address and Data
            if (leaf_awaddr_shake[write_sel] && leaf_wdata_shake[write_sel]) begin
               state_w_next      = STATE_W_LEAF_RESP_RX;
            // Leaf accepted Address but Not Data
            end else if (leaf_awaddr_shake[write_sel] && !leaf_wdata_shake[write_sel]) begin
               state_w_next      = STATE_W_LEAF_ADDR_TX;
            // Leaf accepted Data but Not Address
            end else if (!leaf_awaddr_shake[write_sel] && leaf_wdata_shake[write_sel]) begin
               state_w_next      = STATE_W_LEAF_DATA_TX;
            // Got Nothing
            end else begin
               state_w_next      = state_w;
            end
         end
         // Pass Transaction to Leaf, Data Accepted, Waiting for Address
         STATE_W_LEAF_DATA_TX: begin
            trunk_bus.awready    = 1'b0;
            trunk_bus.wready     = 1'b0;
            trunk_bus.bvalid     = 1'b0;
            trunk_bus.bresp      = C_SO_AXI4L_RESP_OKAY;
            l_awvalid            = 1'b1;
            l_wvalid             = 1'b0;
            l_bready             = 1'b0;
            write_sel_next       = write_sel;
            write_valid_next     = write_valid;

            // Leaf accepted Address
            if (leaf_awaddr_shake[write_sel]) begin
               state_w_next      = STATE_W_LEAF_RESP_RX;
            // Got Nothing
            end else begin
               state_w_next      = state_w;
            end
         end
         // Pass Transaction to Leaf, Address Accepted, Waiting for Data
         STATE_W_LEAF_ADDR_TX: begin
            trunk_bus.awready    = 1'b0;
            trunk_bus.wready     = 1'b0;
            trunk_bus.bvalid     = 1'b0;
            trunk_bus.bresp      = C_SO_AXI4L_RESP_OKAY;
            l_awvalid            = 1'b0;
            l_wvalid             = 1'b1;
            l_bready             = 1'b0;
            write_sel_next       = write_sel;
            write_valid_next     = write_valid;

            // Leaf accepted Data
            if (leaf_wdata_shake[write_sel]) begin
               state_w_next      = STATE_W_LEAF_RESP_RX;
            // Got Nothing
            end else begin
               state_w_next      = state_w;
            end
         end
         // Pass Transaction to Leaf. Waiting for BRESP
         STATE_W_LEAF_RESP_RX: begin
            trunk_bus.awready    = 1'b0;
            trunk_bus.wready     = 1'b0;
            trunk_bus.bvalid     = 1'b0;
            trunk_bus.bresp      = C_SO_AXI4L_RESP_OKAY;
            l_awvalid            = 1'b0;
            l_wvalid             = 1'b0;
            l_bready             = 1'b1;
            write_sel_next       = write_sel;
            write_valid_next     = write_valid;

            if (leaf_bresp_shake[write_sel]) begin
               state_w_next      = STATE_W_TRUNK_RESP_PEND;
            end else begin
               state_w_next      = state_w;
            end
         end
         // Return BRESP to Trunk
         STATE_W_TRUNK_RESP_PEND: begin
            trunk_bus.awready    = 1'b0;
            trunk_bus.wready     = 1'b0;
            trunk_bus.bvalid     = 1'b1;
            trunk_bus.bresp      = bresp;
            l_awvalid            = 1'b0;
            l_wvalid             = 1'b0;
            l_bready             = 1'b0;
            write_sel_next       = write_sel;
            write_valid_next     = write_valid;

            if (trunk_bresp_shake) begin
               state_w_next      = STATE_W_IDLE;
            end else begin
               state_w_next      = state_w;
            end
         end
         default: begin
            trunk_bus.awready    = 1'b0;
            trunk_bus.wready     = 1'b0;
            trunk_bus.bvalid     = 1'b0;
            trunk_bus.bresp      = C_SO_AXI4L_RESP_OKAY;
            l_awvalid            = 1'b0;
            l_wvalid             = 1'b0;
            l_bready             = 1'b0;
            write_sel_next       = '0;
            write_valid_next     = 1'b0;
            state_w_next         = STATE_W_IDLE;
         end
      endcase
   end

end



//============================
// write state machine
always @(posedge aclk) begin
   if (!aresetn) begin
      write_sel            <= 0;
      write_valid          <= 1'b0;
      awaddr               <= '0;
      wdata                <= '0;
      state_w              <= STATE_W_IDLE;
   end else begin
      write_sel            <= write_sel_next;
      write_valid          <= write_valid_next;
      awaddr               <= awaddr_next;
      wdata                <= wdata_next;
      state_w              <= state_w_next;
   end
end

//============================
// leaf side write buses
//============================
for (genvar ii=0; ii<P_NUM_LEAFS; ii++) begin: g_leaf_wr_bus
   assign leaf_awaddr_shake[ii] = leaf_bus[ii].awvalid & leaf_bus[ii].awready;
   assign leaf_wdata_shake [ii] = leaf_bus[ii].wvalid  & leaf_bus[ii].wready;
   assign leaf_bresp_shake [ii] = leaf_bus[ii].bvalid  & leaf_bus[ii].bready;

   // Unused Signals
   assign leaf_bus[ii].awid   = '0;
   assign leaf_bus[ii].awprot = '0;
   assign leaf_bus[ii].awuser = '0;
   assign leaf_bus[ii].wstrb  = '1;
   assign leaf_bus[ii].wuser  = '0;

   // Static Signals
   assign leaf_bus[ii].awaddr  = awaddr;
   assign leaf_bus[ii].awvalid = (write_sel == ii) ? l_awvalid          : 1'b0;
   assign leaf_bus[ii].wdata   = wdata;
   assign leaf_bus[ii].wvalid  = (write_sel == ii) ? l_wvalid           : 1'b0;
   assign leaf_bus[ii].bready  = (write_sel == ii) ? l_bready           : 1'b0;
   assign bresp_i [ii]         = (write_sel == ii) ? leaf_bus[ii].bresp : '0;
end

// wire or of bresp
logic tmp_bresp;

always_comb begin
   tmp_bresp = 0;
   for (int jj=0; jj<P_NUM_LEAFS; jj++) begin
      tmp_bresp = tmp_bresp | bresp_i[jj];
   end
end

always @(posedge aclk) begin
   if (!aresetn) begin
      bresp <= 0;
   end else begin
      bresp <= tmp_bresp;
   end
end


//========================================================
// Read side
//========================================================
assign trunk_araddr_shake = trunk_bus.arready & trunk_bus.arvalid;
assign trunk_rdata_shake  = trunk_bus.rready & trunk_bus.rvalid;

always_comb begin
   read_sel_pre         = 0;
   read_valid_pre       = 1'b0;
   for (int i=0; i<P_NUM_LEAFS; i++) begin
      if ((trunk_bus.araddr[P_TRUNK_ADDR_WIDTH-1:0] <= map[i][1][P_TRUNK_ADDR_WIDTH-1:0]) &&
          (trunk_bus.araddr[P_TRUNK_ADDR_WIDTH-1:0] >= map[i][0][P_TRUNK_ADDR_WIDTH-1:0])) begin
         read_sel_pre   = i;
         read_valid_pre = 1'b1;
      end
   end

   araddr_next = (trunk_araddr_shake) ? trunk_bus.araddr : araddr;

   if (!aresetn) begin
      trunk_bus.arready    = 1'b0;
      trunk_bus.rvalid     = 1'b0;
      trunk_bus.rresp      = C_SO_AXI4L_RESP_OKAY;
      trunk_bus.rdata      = 0;
      l_arvalid            = 1'b0;
      l_rready             = 1'b0;
      read_sel_next        = 0;
      read_valid_next      = 1'b0;
      state_r_next         = STATE_R_IDLE;
   end else begin
      case (state_r)
         STATE_R_IDLE: begin
            trunk_bus.arready    = 1'b1;
            trunk_bus.rvalid     = 1'b0;
            trunk_bus.rresp      = C_SO_AXI4L_RESP_OKAY;
            trunk_bus.rdata      = 0;
            l_arvalid            = 1'b0;
            l_rready             = 1'b0;

            // Received Address and its Valid
            if (trunk_araddr_shake && read_valid_pre) begin
               read_sel_next     = read_sel_pre;
               read_valid_next   = read_valid_pre;
               state_r_next      = STATE_R_INITIATED;
            // Received Address and its Invalid
            end else if (trunk_araddr_shake && !read_valid_pre) begin
               read_sel_next     = read_sel_pre;
               read_valid_next   = read_valid_pre;
               state_r_next      = STATE_R_BAD_ADDR;
            // Got Nothing
            end else begin
               read_sel_next     = read_sel;
               read_valid_next   = read_valid;
               state_r_next      = state_r;
            end
         end
         // Complete Read Transaction, Address was Invalid
         STATE_R_BAD_ADDR: begin
            trunk_bus.arready    = 1'b0;
            trunk_bus.rvalid     = 1'b1;
            trunk_bus.rresp      = C_SO_AXI4L_RESP_DECERR;
            trunk_bus.rdata      = 'h0DEC_C0DE;
            l_arvalid            = 1'b0;
            l_rready             = 1'b0;
            read_sel_next        = read_sel;
            read_valid_next      = read_valid;

            if (trunk_rdata_shake) begin
               state_r_next      = STATE_R_IDLE;
            end else begin
               state_r_next      = state_r;
            end
         end
         // Complete Read Transaction, Address was Valid
         STATE_R_INITIATED: begin
            trunk_bus.arready    = 1'b0;
            trunk_bus.rvalid     = 1'b0;
            trunk_bus.rresp      = C_SO_AXI4L_RESP_OKAY;
            trunk_bus.rdata      = '0;
            l_arvalid            = 1'b1;
            l_rready             = 1'b1;
            read_sel_next        = read_sel;
            read_valid_next      = read_valid;

            // Leaf accepts address and returns data
            if (leaf_araddr_shake[read_sel] && leaf_rdata_shake[read_sel]) begin
               state_r_next      = STATE_R_TRUNK_DATA_TX;
            // Leaf accepts address but no data
            end else if (leaf_araddr_shake[read_sel] && !leaf_rdata_shake[read_sel]) begin
               state_r_next      = STATE_R_LEAF_ADDR_TX;
            // Got Nothing
            end else begin
               state_r_next      = state_r;
            end
         end
         // Pass Transaction to Leaf, Address was Accepted
         STATE_R_LEAF_ADDR_TX: begin
            trunk_bus.arready    = 1'b0;
            trunk_bus.rvalid     = 1'b0;
            trunk_bus.rresp      = C_SO_AXI4L_RESP_OKAY;
            trunk_bus.rdata      = '0;
            l_arvalid            = 1'b0;
            l_rready             = 1'b1;
            read_sel_next        = read_sel;
            read_valid_next      = read_valid;

            if (leaf_rdata_shake[read_sel]) begin
               state_r_next      = STATE_R_TRUNK_DATA_TX;
            end else begin
               state_r_next      = state_r;
            end
         end
         // Return Data to Trunk
         STATE_R_TRUNK_DATA_TX: begin
            trunk_bus.arready    = 1'b0;
            trunk_bus.rvalid     = 1'b1;
            trunk_bus.rresp      = rresp;
            trunk_bus.rdata      = rdata;
            l_arvalid            = 1'b0;
            l_rready             = 1'b0;
            read_sel_next        = read_sel;
            read_valid_next      = read_valid;

            if (trunk_rdata_shake) begin
               state_r_next      = STATE_R_IDLE;
            end else begin
               state_r_next      = state_r;
            end
         end
         default: begin
            trunk_bus.arready    = 1'b1;
            trunk_bus.rvalid     = 1'b0;
            trunk_bus.rresp      = C_SO_AXI4L_RESP_OKAY;
            trunk_bus.rdata      = 0;
            l_arvalid            = 1'b0;
            l_rready             = 1'b0;
            read_sel_next        = 0;
            read_valid_next      = 1'b0;
            state_r_next         = STATE_R_IDLE;
         end
      endcase
   end
end

//============================
// read state machine
always @(posedge aclk) begin
   if (!aresetn) begin
      read_sel    <= 0;
      read_valid  <= 1'b0;
      araddr      <= '0;
      state_r     <= STATE_R_IDLE;
   end else begin
      read_sel    <= read_sel_next;
      read_valid  <= read_valid_next;
      araddr      <= araddr_next;
      state_r     <= state_r_next;
   end
end

//============================
// leaf side read buses
//============================
for (genvar ii=0; ii<P_NUM_LEAFS; ii++) begin: g_leaf_rd_bus
   // Handhskae Signals
   assign leaf_araddr_shake[ii] = leaf_bus[ii].arvalid & leaf_bus[ii].arready;
   assign leaf_rdata_shake [ii] = leaf_bus[ii].rvalid  & leaf_bus[ii].rready;

   // Unused Signals
   assign leaf_bus[ii].arid   = '0;
   assign leaf_bus[ii].arprot = '0;
   assign leaf_bus[ii].aruser = '0;

   // Dynamic Signals
   assign leaf_bus[ii].araddr    = araddr;
   assign leaf_bus[ii].arvalid   = (read_sel == ii) ? l_arvalid          : 1'b0;
   assign leaf_bus[ii].rready    = (read_sel == ii) ? l_rready           : 1'b0;
   assign rdata_i [ii]           = (read_sel == ii) ? leaf_bus[ii].rdata : '0;
   assign rresp_i [ii]           = (read_sel == ii) ? leaf_bus[ii].rresp : '0;
end

// The read data from all leaves are OR'd together
logic [P_DATA_WIDTH-1:0]   tmp_rdata;
logic [1:0]                tmp_rresp;

always_comb begin
   tmp_rdata   = 0;
   tmp_rresp   = 0;

   for (int jj=0; jj<P_NUM_LEAFS; jj++) begin
      tmp_rdata   = tmp_rdata | rdata_i[jj];
      tmp_rresp   = tmp_rresp | rresp_i[jj];
   end
end

always @(posedge aclk) begin
   if (!aresetn) begin
      rdata    <= 0;
      rresp    <= 0;
   end else begin
      rdata    <= tmp_rdata;
      rresp    <= tmp_rresp;
   end
end

endmodule
