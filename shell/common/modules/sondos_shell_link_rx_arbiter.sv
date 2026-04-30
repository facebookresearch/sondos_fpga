// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.


// no backpressure is allowed on any of the channels
module sondos_shell_link_rx_arbiter
#(
   parameter int P_NUM_CH  = 2
)(
   input clk,
   input reset,
   input wire [P_NUM_CH-1:0][7:0] signatures,
   so_axi4s_if.slave axi_stream_from_link,
   so_axi4s_if.master axi_stream_to_channels [P_NUM_CH-1:0]
);


localparam logic [47:0] MAGIC_WORD = 48'hFACEB00CBABE;

typedef enum logic [1:0] {
      ST_HEADER     = 2'b00,
      ST_STREAMING  = 2'b01,
      ST_DROPPING   = 2'b10
   } state_t;

state_t state;
state_t next_state;

logic [P_NUM_CH-1:0] selected_channels;
logic output_tvalid;
logic [255:0] output_tdata;
logic [31:0] output_tkeep;
logic output_tlast;
logic correct_header;

assign axi_stream_from_link.tready = 1'b1;
assign correct_header = (axi_stream_from_link.tdata[63:16]==MAGIC_WORD) & axi_stream_from_link.tvalid;

genvar gen_i;
generate
   for (gen_i=0;gen_i<P_NUM_CH;gen_i = gen_i+1) begin: gen_axis_output_assignment
      assign axi_stream_to_channels[gen_i].tvalid = output_tvalid & selected_channels[gen_i];
      assign axi_stream_to_channels[gen_i].tdata = output_tdata;
      assign axi_stream_to_channels[gen_i].tkeep = output_tkeep;
      assign axi_stream_to_channels[gen_i].tlast = output_tlast;
   end
endgenerate

always_ff @(posedge clk) begin
   if(reset) begin
      state <= ST_HEADER;
      output_tvalid <= '0;
      selected_channels <= '0;
   end else begin
      state <= next_state;
      output_tvalid <= (state==ST_HEADER)? correct_header : (state==ST_STREAMING) & axi_stream_from_link.tvalid;
      for(int ii=0;ii<P_NUM_CH;ii=ii+1)
         selected_channels[ii] <= (state==ST_HEADER)? correct_header & (axi_stream_from_link.tdata[7:0] == signatures[ii]) :
                                                      selected_channels[ii];
   end
   output_tdata <= axi_stream_from_link.tdata;
   output_tkeep <= axi_stream_from_link.tkeep;
   output_tlast <= axi_stream_from_link.tlast;
end

always_comb begin
    case(state)
        ST_HEADER       :   if(correct_header & ~axi_stream_from_link.tlast) next_state = ST_STREAMING;
                            else if(axi_stream_from_link.tvalid & ~axi_stream_from_link.tlast) next_state = ST_DROPPING;
                            else next_state = ST_HEADER;

        ST_STREAMING    :   if(axi_stream_from_link.tvalid & axi_stream_from_link.tlast) next_state = ST_HEADER;
                            else next_state = ST_STREAMING;

        ST_DROPPING     :   if(axi_stream_from_link.tvalid & axi_stream_from_link.tlast) next_state = ST_HEADER;
                            else next_state = ST_DROPPING;

        default         :   next_state = ST_HEADER;
    endcase
end

endmodule
