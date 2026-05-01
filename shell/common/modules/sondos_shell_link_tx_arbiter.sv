// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

module sondos_shell_link_tx_arbiter
#(
   parameter int P_NUM_CH  = 2
)(
   input clk,
   input reset,
   so_axi4s_if.slave axi_stream_from_channels [P_NUM_CH-1:0],
   so_axi4s_if.master axi_stream_to_link
);

localparam int SEL_WIDTH = $clog2(P_NUM_CH);

typedef struct packed {
      logic tlast;
      logic [31:0] tkeep;
      logic [255:0] tdata;
} axis_data_t;

axis_data_t buf_0;
axis_data_t buf_1;
logic buf_0_valid;
logic buf_1_valid;

logic multiword_streaming;
logic [SEL_WIDTH-1:0] current_channel;
logic [SEL_WIDTH-1:0] next_channel;
axis_data_t selected_data;
logic [P_NUM_CH-1:0] tvalid_array;
logic [P_NUM_CH-1:0] tlast_array;
logic [P_NUM_CH-1:0][31:0] tkeep_array;
logic [P_NUM_CH-1:0][255:0] tdata_array;
logic [P_NUM_CH-1:0] tvalid_mask;

genvar gen_i;
generate
   for (gen_i=0;gen_i<P_NUM_CH;gen_i = gen_i+1) begin : gen_axis_input_handling
      assign tvalid_array[gen_i] = axi_stream_from_channels[gen_i].tvalid;
      assign tlast_array[gen_i] = axi_stream_from_channels[gen_i].tlast;
      assign tkeep_array[gen_i] = axi_stream_from_channels[gen_i].tkeep;
      assign tdata_array[gen_i] = axi_stream_from_channels[gen_i].tdata;
      assign axi_stream_from_channels[gen_i].tready = (current_channel==gen_i) & ~(buf_1_valid);
   end
endgenerate

// channels are not allowed to bring down tvalid in the middle of a stream
// this module will auto-insert a tlast and switch the channel immediately
assign selected_data.tlast = tlast_array[current_channel] | (multiword_streaming & ~tvalid_array[current_channel]);
assign selected_data.tkeep = tkeep_array[current_channel];
assign selected_data.tdata = tdata_array[current_channel];

assign selected_valid = tvalid_array[current_channel] | multiword_streaming;

assign axi_stream_to_link.tvalid = buf_0_valid;
assign axi_stream_to_link.tlast = buf_0.tlast;
assign axi_stream_to_link.tkeep = buf_0.tkeep;
assign axi_stream_to_link.tdata = buf_0.tdata;

////////////////
/// next channel calculation
////////////////
always_comb begin
   // Create a mask of all channel tready bits other than the current channel
   tvalid_mask = '1;
   tvalid_mask[current_channel] = 0;
   // Increment the round robin channel index ONLY if a different channel has data to send
   // Since the AXI-Lite bus (index 0) is less frequently used, skip over it if it doesn't have data to send
   next_channel = (|(tvalid_array & tvalid_mask))? ((current_channel==(P_NUM_CH-1))? ((tvalid_array[0] == 1)? '0 : 1) : current_channel+1) : current_channel;
end
///////////////


always_ff @(posedge clk) begin
   if(reset) begin
      buf_0_valid <= 1'b0;
      buf_1_valid <= 1'b0;
      current_channel <= '0;
      multiword_streaming <= '0;
   end else begin
      buf_0_valid <= (buf_0_valid)? (selected_valid | buf_1_valid | ~axi_stream_to_link.tready) : selected_valid;
      buf_1_valid <= (buf_1_valid)? ~axi_stream_to_link.tready : buf_0_valid & selected_valid & ~axi_stream_to_link.tready;
      current_channel <= ((~selected_valid) | (selected_data.tlast & ~buf_1_valid))? next_channel : current_channel;
      multiword_streaming <= tvalid_array[current_channel] & ~tlast_array[current_channel];
   end
   buf_0 <= (buf_0_valid & ~axi_stream_to_link.tready)? buf_0:
            (buf_1_valid)? buf_1 : selected_data;
   buf_1 <= (buf_1_valid & ~axi_stream_to_link.tready)? buf_1 : selected_data;
end

endmodule
