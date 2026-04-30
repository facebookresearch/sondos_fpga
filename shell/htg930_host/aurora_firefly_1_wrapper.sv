// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.
module aurora_firefly_1_wrapper
(
  so_axi4s_if.slave     tx,
  so_axi4s_if.master    rx,
  so_axi4s_if.slave     user_k_tx,
  so_axi4s_if.master    user_k_rx,
  input     [3:0]       ff1_rx_p,
  input     [3:0]       ff1_rx_n,
  output    [3:0]       ff1_tx_p,
  output    [3:0]       ff1_tx_n,
  input                 ff1_refclk_p,
  input                 ff1_refclk_n,

  output logic [31:0]   hard_err_counter,
  output logic [31:0]   soft_err_counter,
  output logic [31:0]   crc_pass_fail_n_counter,

  output [3:0]          lane_up, // reversal is per Xilinx
  output                channel_up         ,
  output                sys_reset_out      ,
  output                gt_pll_lock        ,
  output                user_clk_out       ,
  output                mmcm_not_locked_out,
  input                 sys_reset_n,
  input                 user_reset,
  input                 init_clk
);

   typedef enum logic [2:0] {
      ST_POWER_ON   = 3'b000,
      ST_USER_RESET = 3'b001, // wait 256 cycles
      ST_PMA_INIT   = 3'b010, // wait until (2^27) cycles ~1 second
      ST_PB_RESET_AFTER_INIT = 3'b011, // wait 128 cycles
      ST_NORMAL_OP  = 3'b100

   } reset_state_t;


logic [26:0] clk_counter = '1;
logic counter_done;
logic pma_init;
logic reset_pb;

reset_state_t reset_state = ST_POWER_ON;
reset_state_t reset_next_state;

// The User-K channel is split as 64 bits per channel. There are 4 channels in our Aurora lin.
// Each 64-bit channel is 56 bits of data, 4 bits of block number (currently unused), and 4 bits of zeros.
typedef struct packed { // User K bus is 256-bit, but only 224-bit is data, 16-bit is control, 16-bit zeros
   logic [55:0] user_k_data_3; // 56 bits
   logic [3:0] zeros_3;        // 4 bits
   logic [3:0] user_k_blk_3;   // 4 bits
   logic [55:0] user_k_data_2; // 56 bits
   logic [3:0] zeros_2;        // 4 bits
   logic [3:0] user_k_blk_2;   // 4 bits
   logic [55:0] user_k_data_1; // 56 bits
   logic [3:0] zeros_1;        // 4 bits
   logic [3:0] user_k_blk_1;   // 4 bits
   logic [55:0] user_k_data_0; // 56 bits
   logic [3:0] zeros_0;        // 4 bits
   logic [3:0] user_k_blk_0;   // 4 bits
} user_k_tdata_t;

user_k_tdata_t s_axi_user_k_tx_tdata;
user_k_tdata_t m_axi_rx_user_k_tdata;

always_comb begin
   // Distribute the 192 bits of tdata across the sparse USER-K data blocks
   s_axi_user_k_tx_tdata.user_k_data_3 = {32'd0, user_k_tx.tdata[191:168]};
   s_axi_user_k_tx_tdata.zeros_3 = 4'd0;
   s_axi_user_k_tx_tdata.user_k_blk_3 = 4'd0;
   s_axi_user_k_tx_tdata.user_k_data_2 = user_k_tx.tdata[167:112];
   s_axi_user_k_tx_tdata.zeros_2 = 4'd0;
   s_axi_user_k_tx_tdata.user_k_blk_2 = 4'd0;
   s_axi_user_k_tx_tdata.user_k_data_1 = user_k_tx.tdata[111:56];
   s_axi_user_k_tx_tdata.zeros_1 = 4'd0;
   s_axi_user_k_tx_tdata.user_k_blk_1 = 4'd0;
   s_axi_user_k_tx_tdata.user_k_data_0 = user_k_tx.tdata[55:0];
   s_axi_user_k_tx_tdata.zeros_0 = 4'd0;
   s_axi_user_k_tx_tdata.user_k_blk_0 = 4'd0;
   user_k_rx.tdata[255:192] = '0; // 32 MSBs are unused
   user_k_rx.tdata[191:168] = m_axi_rx_user_k_tdata.user_k_data_3[23:0];
   user_k_rx.tdata[167:112] = m_axi_rx_user_k_tdata.user_k_data_2[55:0];
   user_k_rx.tdata[111:56]  = m_axi_rx_user_k_tdata.user_k_data_1[55:0];
   user_k_rx.tdata[55:0]    = m_axi_rx_user_k_tdata.user_k_data_0[55:0];
   user_k_rx.tlast          = 1'b1;
end

logic soft_err;
logic hard_err;
logic crc_pass_fail_n;
logic crc_valid;

aurora_firefly_1 inst_aurora (
   .s_axi_tx_tdata             (tx.tdata           ),
   .s_axi_tx_tlast             (tx.tlast           ),
   .s_axi_tx_tkeep             (tx.tkeep           ),
   .s_axi_tx_tvalid            (tx.tvalid          ),
   .s_axi_tx_tready            (tx.tready          ),
   .m_axi_rx_tdata             (rx.tdata           ),
   .m_axi_rx_tlast             (rx.tlast           ),
   .m_axi_rx_tkeep             (rx.tkeep           ),
   .m_axi_rx_tvalid            (rx.tvalid          ),
   .s_axi_user_k_tx_tdata      (s_axi_user_k_tx_tdata),
   .s_axi_user_k_tx_tvalid     (user_k_tx.tvalid   ),
   .s_axi_user_k_tx_tready     (user_k_tx.tready   ),
   .m_axi_rx_user_k_tdata      (m_axi_rx_user_k_tdata),
   .m_axi_rx_user_k_tvalid     (user_k_rx.tvalid   ),
   .rxp                        (ff1_rx_p           ),
   .rxn                        (ff1_rx_n           ),
   .txp                        (ff1_tx_p           ),
   .txn                        (ff1_tx_n           ),
   .gt_refclk1_p               (ff1_refclk_p       ),
   .gt_refclk1_n               (ff1_refclk_n       ),
   .gt_refclk1_out             (                   ),
   .hard_err                   (hard_err           ),
   .soft_err                   (soft_err           ),
   .channel_up                 (channel_up         ),
   .lane_up                    (lane_up            ),
   .crc_pass_fail_n            (crc_pass_fail_n    ),
   .crc_valid                  (crc_valid          ),
   .mmcm_not_locked_out        (mmcm_not_locked_out),
   .user_clk_out               (user_clk_out       ),
   .sync_clk_out               (                   ),
   .reset_pb                   (reset_pb           ),
   .gt_rxcdrovrden_in          (1'b0               ),
   .power_down                 (1'b0               ),
   .loopback                   (3'b000             ),
   .pma_init                   (pma_init           ),
   .gt_pll_lock                (gt_pll_lock        ),
   .gt_qpllclk_quad1_out       (                   ),
   .gt_qpllrefclk_quad1_out    (                   ),
   .gt_qplllock_quad1_out      (                   ),
   .gt_qpllrefclklost_quad1_out(                   ),
   // AXI4-Lite Control Interface (unused)
   .s_axi_awaddr               (32'b0              ),
   .s_axi_awvalid              (1'b0               ),
   .s_axi_awready              (                   ),
   .s_axi_wdata                (32'b0              ),
   .s_axi_wstrb                (4'b0               ),
   .s_axi_wvalid               (1'b0               ),
   .s_axi_wready               (                   ),
   .s_axi_bvalid               (                   ),
   .s_axi_bresp                (                   ),
   .s_axi_bready               (1'b0               ),
   .s_axi_araddr               (32'b0              ),
   .s_axi_arvalid              (1'b0               ),
   .s_axi_arready              (                   ),
   .s_axi_rdata                (                   ),
   .s_axi_rvalid               (                   ),
   .s_axi_rresp                (                   ),
   .s_axi_rready               (1'b0               ),
   .s_axi_awaddr_lane1         (32'b0              ),
   .s_axi_awvalid_lane1        (1'b0               ),
   .s_axi_awready_lane1        (                   ),
   .s_axi_wdata_lane1          (32'b0              ),
   .s_axi_wstrb_lane1          (4'b0               ),
   .s_axi_wvalid_lane1         (1'b0               ),
   .s_axi_wready_lane1         (                   ),
   .s_axi_bvalid_lane1         (                   ),
   .s_axi_bresp_lane1          (                   ),
   .s_axi_bready_lane1         (1'b0               ),
   .s_axi_araddr_lane1         (32'b0              ),
   .s_axi_arvalid_lane1        (1'b0               ),
   .s_axi_arready_lane1        (                   ),
   .s_axi_rdata_lane1          (                   ),
   .s_axi_rvalid_lane1         (                   ),
   .s_axi_rresp_lane1          (                   ),
   .s_axi_rready_lane1         (1'b0               ),
   .s_axi_awaddr_lane2         (32'b0              ),
   .s_axi_awvalid_lane2        (1'b0               ),
   .s_axi_awready_lane2        (                   ),
   .s_axi_wdata_lane2          (32'b0              ),
   .s_axi_wstrb_lane2          (4'b0               ),
   .s_axi_wvalid_lane2         (1'b0               ),
   .s_axi_wready_lane2         (                   ),
   .s_axi_bvalid_lane2         (                   ),
   .s_axi_bresp_lane2          (                   ),
   .s_axi_bready_lane2         (1'b0               ),
   .s_axi_araddr_lane2         (32'b0              ),
   .s_axi_arvalid_lane2        (1'b0               ),
   .s_axi_arready_lane2        (                   ),
   .s_axi_rdata_lane2          (                   ),
   .s_axi_rvalid_lane2         (                   ),
   .s_axi_rresp_lane2          (                   ),
   .s_axi_rready_lane2         (1'b0               ),
   .s_axi_awaddr_lane3         (32'b0              ),
   .s_axi_awvalid_lane3        (1'b0               ),
   .s_axi_awready_lane3        (                   ),
   .s_axi_wdata_lane3          (32'b0              ),
   .s_axi_wstrb_lane3          (4'b0               ),
   .s_axi_wvalid_lane3         (1'b0               ),
   .s_axi_wready_lane3         (                   ),
   .s_axi_bvalid_lane3         (                   ),
   .s_axi_bresp_lane3          (                   ),
   .s_axi_bready_lane3         (1'b0               ),
   .s_axi_araddr_lane3         (32'b0              ),
   .s_axi_arvalid_lane3        (1'b0               ),
   .s_axi_arready_lane3        (                   ),
   .s_axi_rdata_lane3          (                   ),
   .s_axi_rvalid_lane3         (                   ),
   .s_axi_rresp_lane3          (                   ),
   .s_axi_rready_lane3         (1'b0               ),
   .gt_reset_out               (                   ),
   .gt_powergood               (                   ),
   .link_reset_out             (                   ),
   .sys_reset_out              (sys_reset_out      ),
   .tx_out_clk                 (                   ),
   .init_clk
);

always @(posedge user_clk_out) begin
    if(sys_reset_out) begin
        soft_err_counter <= '0;
        hard_err_counter <= '0;
        crc_pass_fail_n_counter <= '0;
    end else begin
        if(soft_err) soft_err_counter <= soft_err_counter + 1;
        if(hard_err) hard_err_counter <= hard_err_counter + 1;
        if(crc_valid & ~crc_pass_fail_n) crc_pass_fail_n_counter <= crc_pass_fail_n_counter + 1;
    end
end

 always_ff @(posedge init_clk) begin
    if(~sys_reset_n) begin
        reset_state <= ST_POWER_ON;
        clk_counter <= '1;
    end else begin
        reset_state <= reset_next_state;
        clk_counter <= (user_reset)? 27'd256:
                       (|clk_counter)? clk_counter - 1'b1:
                       (reset_state==ST_USER_RESET)? '1:
                       (reset_state==ST_PMA_INIT)? 27'd32 : '0;
    end
 end

 assign counter_done = ~(|clk_counter);


assign pma_init = (reset_state==ST_PMA_INIT) | (reset_state==ST_POWER_ON);
assign reset_pb = (reset_state==ST_USER_RESET) |  (reset_state==ST_PMA_INIT) | (reset_state==ST_POWER_ON) | (reset_state==ST_PB_RESET_AFTER_INIT);


   always_comb begin
      case(reset_state)
         ST_NORMAL_OP           :   if(user_reset) reset_next_state = ST_USER_RESET;
                                    else reset_next_state = ST_NORMAL_OP;

         ST_POWER_ON            :   reset_next_state = ST_PMA_INIT;

         ST_USER_RESET          :   if(counter_done) reset_next_state = ST_PMA_INIT;
                                    else reset_next_state = ST_USER_RESET;

         ST_PMA_INIT            :   if(counter_done) reset_next_state = ST_PB_RESET_AFTER_INIT;
                                    else reset_next_state = ST_PMA_INIT;

         ST_PB_RESET_AFTER_INIT :   if(counter_done) reset_next_state = ST_NORMAL_OP;
                                    else reset_next_state = ST_PB_RESET_AFTER_INIT;

         default                :   reset_next_state = ST_POWER_ON;
      endcase
   end

endmodule
