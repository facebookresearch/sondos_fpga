// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.


module sondos_shell_flash_axi_fsm(
   input clk,
   input reset,
   so_axi4_if.master axi_full_flash,

   input start_reading,
   input start_writing,
   input add_phy_page,
   input enable_memory_access,
   input [31:0] new_phy_page_address,

   output [31:0] axi_pipeline_state,
   output [31:0] time_since_last_op,
   output [15:0] pending_pages,
   output logic [31:0] read_word_count,
   output logic [31:0] write_word_count,

   input data_from_controller_valid,
   input [255:0] data_from_controller,
   input data_to_controller_taken,
   output [255:0] data_to_controller

);

typedef enum logic [2:0] {
   ST_IDLE           = 3'd0,
   ST_DISABLED       = 3'd1,
   ST_AXI_READ_CMD   = 3'd2,
   ST_AXI_READ_DATA  = 3'd3,
   ST_AXI_WRITE_CMD  = 3'd4,
   ST_AXI_WRITE_DATA = 3'd5,
   ST_ERROR          = 3'd7
} axi_state_t;


typedef struct packed {
   logic data_fifo_overflow;
   logic data_fifo_underflow;
   logic page_fifo_overflow;
   logic page_fifo_underflow;
   logic impropper_read_start;
   logic impropper_write_start;
   logic axi_read_resp_error;
   logic axi_write_resp_error;
} fsm_error_vector_t;


axi_state_t current_state;
axi_state_t next_state;

fsm_error_vector_t error_vector;

logic state_is_writing;
logic increment_data_pages;
logic decrement_data_pages;
logic increment_address_pages;
logic decrement_address_pages;
logic [3:0] available_data_pages;
logic [9:0] available_address_pages;
logic axi_read_data_taken;
logic axi_partial_data_valid;
logic [255:0] hold_partial_axi_data;

logic [255:0] dt_fifo_data_in;
logic [255:0] dt_fifo_data_out;
logic dt_fifo_write;
logic dt_fifo_read;
logic dt_fifo_rd_rst_busy;
logic dt_fifo_wr_rst_busy;
logic dt_fifo_full;
logic dt_fifo_empty;

logic [31:0] page_fifo_data_in;
logic [31:0] page_fifo_data_out;
logic page_fifo_write;
logic page_fifo_read;
logic page_fifo_rd_rst_busy;
logic page_fifo_wr_rst_busy;
logic page_fifo_full;
logic page_fifo_empty;

////////////////////////////////////////////////////////////////////
/////////////// Registers always blocks ////////////////////////////
////////////////////////////////////////////////////////////////////

always_ff @(posedge clk) begin
   if(reset) begin
      current_state <= ST_IDLE;
      increment_data_pages <= 1'b0;
      decrement_data_pages <= 1'b0;
      increment_address_pages <= 1'b0;
      decrement_address_pages <= 1'b0;
      error_vector <= '0;
      axi_read_data_taken <= 1'b0;
      axi_partial_data_valid <= 1'b0;
      read_word_count <= '0;
      write_word_count <= '0;
      available_data_pages <= '0;
      available_address_pages <= '0;
   end else begin
      current_state <= next_state;
      increment_data_pages <= (state_is_writing)? (&write_word_count[6:0]) & dt_fifo_write : axi_full_flash.arvalid & axi_full_flash.arready;
      decrement_data_pages <= (state_is_writing)? axi_full_flash.awvalid & axi_full_flash.awready : (&read_word_count[6:0]) & dt_fifo_read;
      increment_address_pages <= page_fifo_write;
      decrement_address_pages <= page_fifo_read;
      error_vector.data_fifo_overflow <= error_vector.data_fifo_overflow | (dt_fifo_full & dt_fifo_write);
      error_vector.data_fifo_underflow <= error_vector.data_fifo_underflow | (dt_fifo_empty & dt_fifo_read);
      error_vector.page_fifo_overflow <= error_vector.page_fifo_overflow | (page_fifo_full & page_fifo_write);
      error_vector.page_fifo_underflow <= error_vector.page_fifo_underflow | (page_fifo_empty & page_fifo_read);
      error_vector.impropper_read_start <= error_vector.impropper_read_start | (start_reading & ~(current_state == ST_IDLE));
      error_vector.impropper_write_start <= error_vector.impropper_write_start | (start_writing & ~(current_state == ST_IDLE));
      error_vector.axi_read_resp_error <= error_vector.axi_read_resp_error | (axi_full_flash.rvalid & axi_full_flash.rresp[1]);
      error_vector.axi_write_resp_error <= error_vector.axi_write_resp_error | (axi_full_flash.bvalid & axi_full_flash.bresp[1]);
      axi_read_data_taken <= axi_full_flash.rready & axi_full_flash.rvalid;
      axi_partial_data_valid <= (axi_partial_data_valid)? ~axi_full_flash.wready : (current_state==ST_AXI_WRITE_DATA);
      read_word_count <= read_word_count + dt_fifo_read;
      write_word_count <= write_word_count + dt_fifo_write;
      available_data_pages <= (increment_data_pages & ~decrement_data_pages)? available_data_pages + 1'b1 :
                              (decrement_data_pages & ~increment_data_pages)? available_data_pages - 1'b1 :available_data_pages;
      available_address_pages <= (increment_address_pages & ~decrement_address_pages)? available_address_pages + 1'b1 :
                                 (decrement_address_pages & ~increment_address_pages)? available_address_pages - 1'b1 :available_address_pages;
   end
   hold_partial_axi_data <= ((current_state==ST_AXI_WRITE_DATA) & dt_fifo_read)? dt_fifo_data_out :
                            (current_state==ST_AXI_WRITE_DATA)? hold_partial_axi_data : axi_full_flash.rdata[511:256];

end


////////////////////////////////////////////////////////////////////
/////////////// FSM case statement /////////////////////////////////
////////////////////////////////////////////////////////////////////

always_comb begin
   case(current_state)
      ST_IDLE           :  if(~enable_memory_access) next_state = ST_DISABLED;
                           else if(start_reading) next_state = ST_AXI_READ_CMD;
                           else if(start_writing) next_state = ST_AXI_WRITE_CMD;
                           else next_state = ST_IDLE;

      ST_AXI_READ_CMD   :  if(|error_vector) next_state = ST_ERROR;
                           else if(~enable_memory_access) next_state = ST_DISABLED;
                           else if(page_fifo_read) next_state = ST_AXI_READ_DATA;
                           else next_state = ST_AXI_READ_CMD;

      ST_AXI_READ_DATA  :  if(|error_vector) next_state = ST_ERROR;
                           else if(~enable_memory_access) next_state = ST_DISABLED;
                           else if(axi_full_flash.rvalid & axi_full_flash.rlast) next_state = ST_AXI_READ_CMD;
                           else next_state = ST_AXI_READ_DATA;

      ST_AXI_WRITE_CMD  :  if(|error_vector) next_state = ST_ERROR;
                           else if(~enable_memory_access) next_state = ST_DISABLED;
                           else if(page_fifo_read) next_state = ST_AXI_WRITE_DATA;
                           else next_state = ST_AXI_WRITE_CMD;

      ST_AXI_WRITE_DATA :  if(axi_full_flash.wvalid & axi_full_flash.wready & axi_full_flash.wlast) next_state = ST_AXI_WRITE_CMD;
                           else next_state = ST_AXI_WRITE_DATA;

      ST_DISABLED :  next_state = ST_DISABLED;
      default:       next_state = ST_ERROR;
   endcase
end

////////////////////////////////////////////////////////////////////
/////////////////    Control Signals    ////////////////////////////
////////////////////////////////////////////////////////////////////

assign axi_pipeline_state = {current_state,error_vector};
assign pending_pages = {available_address_pages,available_data_pages};

assign state_is_writing = (current_state == ST_AXI_WRITE_CMD) | (current_state == ST_AXI_WRITE_DATA);

assign axi_full_flash.rready = ~axi_read_data_taken;
assign axi_full_flash.bready = 1'b1;

assign axi_full_flash.awid    = '0;
assign axi_full_flash.awaddr  = {page_fifo_data_out,12'd0};
assign axi_full_flash.awregion= '0;
assign axi_full_flash.awlen   = 8'd63;
assign axi_full_flash.awsize  = 3'b110;
assign axi_full_flash.awburst = 2'b01;
assign axi_full_flash.awuser  = '0;
assign axi_full_flash.awvalid = (current_state==ST_AXI_WRITE_CMD) & (|available_address_pages) & (|available_data_pages);

assign axi_full_flash.arid    = '0;
assign axi_full_flash.araddr  = {page_fifo_data_out,12'd0};
assign axi_full_flash.arregion= '0;
assign axi_full_flash.arlen   = 8'd63;
assign axi_full_flash.arsize  = 3'b110;
assign axi_full_flash.arburst = 2'b01;
assign axi_full_flash.aruser  = '0;
assign axi_full_flash.arvalid = (current_state==ST_AXI_READ_CMD) & (|available_address_pages) & ~(available_data_pages[1:0] == 2'b11);

assign axi_full_flash.wdata   = {dt_fifo_data_out,hold_partial_axi_data};
assign axi_full_flash.wstrb   = 64'hFFFFFFFFFFFFFFFF;
assign axi_full_flash.wlast   = &read_word_count[6:0];
assign axi_full_flash.wvalid  = axi_partial_data_valid;
assign axi_full_flash.wuser   = '0;

assign dt_fifo_data_in = (state_is_writing)? data_from_controller :
                         (axi_read_data_taken)? hold_partial_axi_data : axi_full_flash.rdata[255:0];
assign dt_fifo_write = (state_is_writing)? data_from_controller_valid : axi_full_flash.rvalid | axi_read_data_taken;
assign dt_fifo_read = (current_state==ST_AXI_WRITE_DATA)? axi_full_flash.wready | ~axi_partial_data_valid : data_to_controller_taken;

assign page_fifo_data_in = new_phy_page_address;
assign page_fifo_write = add_phy_page;
assign page_fifo_read = (axi_full_flash.arvalid & axi_full_flash.arready) | (axi_full_flash.awvalid & axi_full_flash.awready);

assign data_to_controller = dt_fifo_data_out;

////////////////////////////////////////////////////////////////////
/////////////// Component Instantiation ////////////////////////////
////////////////////////////////////////////////////////////////////

xpm_fifo_sync #(
   .FIFO_MEMORY_TYPE("block"),
   .FIFO_READ_LATENCY(0),
   .FIFO_WRITE_DEPTH(512),
   .READ_DATA_WIDTH(256),
   .READ_MODE("fwft"),
   .USE_ADV_FEATURES("0000"),
   .WRITE_DATA_WIDTH(256)
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
   .prog_full(),
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
   .FIFO_MEMORY_TYPE("block"),
   .FIFO_READ_LATENCY(0),
   .FIFO_WRITE_DEPTH(512),
   .READ_DATA_WIDTH(32),
   .READ_MODE("fwft"),
   .USE_ADV_FEATURES("0000"),
   .WRITE_DATA_WIDTH(32)
)
page_address_fifo (
   .almost_empty(),
   .almost_full(),
   .data_valid(),
   .dbiterr(),
   .dout(page_fifo_data_out),
   .empty(page_fifo_empty),
   .full(page_fifo_full),
   .overflow(),
   .prog_empty(),
   .prog_full(),
   .rd_data_count(),
   .rd_rst_busy(page_fifo_rd_rst_busy),
   .sbiterr(),
   .underflow(),
   .wr_ack(),
   .wr_data_count(),
   .wr_rst_busy(page_fifo_wr_rst_busy),
   .din(page_fifo_data_in),
   .injectdbiterr(1'b0),
   .injectsbiterr(1'b0),
   .rd_en(page_fifo_read),
   .rst(reset),
   .sleep(1'b0),
   .wr_clk(clk),
   .wr_en(page_fifo_write)
);

endmodule
