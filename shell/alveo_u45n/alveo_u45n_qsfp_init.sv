// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.
// Copyright (c) Meta Platforms, Inc. and affiliates.
//-----------------------------------------------------------------------------
// Title: QSFP Initialization block for the Alveo U45N FPGA Board
//-----------------------------------------------------------------------------
// Description: Each QSFP needs to have its CDR disabled to function correctly
//  at 64Gbps. This must be done through the Alveo CMS interface.
//  See the AMD PG348 product guide and SFF-8636 for more information.
//-----------------------------------------------------------------------------

module alveo_u45n_qsfp_init
#(
   parameter int P_NUM_QSFP = 2
)(
   input wire clk,
   input wire reset,
   input wire config_start,

   so_axi4l_if.master axi_lite_to_cms,
   (*mark_debug="true",keep="true"*) output logic config_done,
   (*mark_debug="true",keep="true"*) output logic [P_NUM_QSFP-1:0] config_status
);

   // CMS Mailbox registers used during QSFP config
   localparam logic [19:0] C_MB_RESETN_REG = 20'h20000;
   localparam logic [19:0] C_CMS_ID_REG = 20'h28000;
   localparam logic [19:0] C_CMS_CONTROL_REG = 20'h28018;
   localparam logic [19:0] C_HOST_MSG_ERROR_REG = 20'h28304;
   localparam logic [19:0] C_MAILBOX_HEADER_REG = 20'h29000;
   localparam logic [19:0] C_MAILBOX_CAGE_SEL_REG = 20'h29004;
   localparam logic [19:0] C_MAILBOX_PAGE_SEL_REG = 20'h29008;
   localparam logic [19:0] C_MAILBOX_EXTD_PAGE_SEL_REG = 20'h2900C;
   localparam logic [19:0] C_MAILBOX_PAGE_BYTE_OFFSET_REG = 20'h29010;
   localparam logic [19:0] C_MAILBOX_DATA_REG = 20'h29014;

   // Take the CMS Microblaze out of reset
   localparam logic [31:0] C_MB_RESET_INACTIVE = 32'h0000_0001;

   // Register Map ID from CMS product specification
   localparam logic [31:0] C_REG_MAP_ID = 32'h74736574;

   // The CMS Mailbox protocol uses bit 5 to start/end message transactions
   localparam logic [31:0] C_MAILBOX_MSG_STATUS_MASK = 32'h0000_0020;

   // Header has opcode 0x10 and the rest of the header is 0's
   localparam logic [31:0] C_BYTE_WRITE_HEADER = 32'h1000_0000;
   // The CDR register is in Page 0
   localparam logic [31:0] C_PAGE_0 = 32'h0000_0000;
   // The CDR register is in the lower half of the page (so LSB = 0)
   localparam logic [31:0] C_LOWER_PAGE = 32'h0000_0000;
   // The CDR register offset within Page 0
   localparam logic [31:0] C_CDR_REGISTER = 32'h0000_0062;
   // The value to disable CDR (bits 7:0 = 0x00)
   localparam logic [31:0] C_DISABLE_CDR = 32'h0000_0000;
   // The value to report "Write success"
   localparam logic [31:0] C_NO_ERROR = 32'h0000_0000;

   // Count which QSFP is being written to
   (*mark_debug="true",keep="true"*) logic [$clog2(P_NUM_QSFP)-1:0] qsfp_sel;

   // State machine
   typedef enum logic[3:0] {
      STATE_IDLE,
      STATE_EXIT_RESET,
      STATE_VERIFY_DEVICE_ID,
      STATE_CHECK_MAILBOX_IDLE,
      STATE_SET_HEADER,
      STATE_SET_CAGE_SEL,
      STATE_SET_PAGE,
      STATE_SET_LOW_PAGE,
      STATE_SET_REG,
      STATE_SET_DATA,
      STATE_SEND_MSG,
      STATE_WAIT_DONE,
      STATE_CHECK_RESULT,
      STATE_DONE
   } curr_state_t;
   (*fsm_safe_state="reset_state",mark_debug="true",keep="true"*) curr_state_t curr_state;

   always @(posedge clk) begin
      if (reset) begin
         config_done <= 0;
         config_status <= 0;
         axi_lite_to_cms.arvalid <= 0;
         axi_lite_to_cms.rready <= 0;
         axi_lite_to_cms.awvalid <= 0;
         axi_lite_to_cms.wvalid <= 0;
         axi_lite_to_cms.bready <= 1;
         qsfp_sel <= 0;
         curr_state <= STATE_IDLE;
      end else begin
         case (curr_state)
            // Have the CMS microblaze exit reset before starting a mailbox transaction
            STATE_EXIT_RESET: begin
               if (axi_lite_to_cms.wvalid && axi_lite_to_cms.wready) begin
                  axi_lite_to_cms.wvalid <= 0;
                  axi_lite_to_cms.arvalid <= 1;
                  axi_lite_to_cms.araddr <= C_CMS_ID_REG;
                  curr_state <= STATE_VERIFY_DEVICE_ID;
               end else if (axi_lite_to_cms.awvalid && axi_lite_to_cms.awready) begin
                  axi_lite_to_cms.awvalid <= 0;
                  axi_lite_to_cms.wvalid <= 1;
               end
            end

            // Read the device ID register to ensure we're out of reset
            STATE_VERIFY_DEVICE_ID: begin
               if (axi_lite_to_cms.rvalid && axi_lite_to_cms.rready) begin
                  axi_lite_to_cms.rready <= 0;
                  // Verify that we read the register map ID successfully
                  if (axi_lite_to_cms.rdata == C_REG_MAP_ID) begin
                     axi_lite_to_cms.arvalid <= 1;
                     axi_lite_to_cms.araddr <= C_CMS_CONTROL_REG;
                     curr_state <= STATE_CHECK_MAILBOX_IDLE;
                  end else begin // reset is not complete, try exiting reset again...
                     axi_lite_to_cms.awvalid <= 1;
                     axi_lite_to_cms.awaddr <= C_MB_RESETN_REG;
                     axi_lite_to_cms.wdata <= C_MB_RESET_INACTIVE;
                     curr_state <= STATE_EXIT_RESET;
                  end
               end else if (axi_lite_to_cms.arready && axi_lite_to_cms.arvalid) begin
                  axi_lite_to_cms.arvalid <= 0;
                  axi_lite_to_cms.rready <= 1;
               end
            end

            // Check that the mailbox is idle before starting a transaction
            STATE_CHECK_MAILBOX_IDLE: begin
               if (axi_lite_to_cms.rvalid && axi_lite_to_cms.rready) begin
                  // Check to see if mailbox is ready for a new message
                  if ((axi_lite_to_cms.rdata & C_MAILBOX_MSG_STATUS_MASK) == 0) begin
                     axi_lite_to_cms.rready <= 0;
                     axi_lite_to_cms.awvalid <= 1;
                     axi_lite_to_cms.awaddr <= C_MAILBOX_HEADER_REG;
                     axi_lite_to_cms.wdata <= C_BYTE_WRITE_HEADER;
                     axi_lite_to_cms.wstrb <= '1;
                     curr_state <= STATE_SET_HEADER;
                  end else begin // Mailbox status is not ready
                     axi_lite_to_cms.rready <= 0;
                     axi_lite_to_cms.arvalid <= 1;
                  end
               end else if (axi_lite_to_cms.arready && axi_lite_to_cms.arvalid) begin
                  axi_lite_to_cms.arvalid <= 0;
                  axi_lite_to_cms.rready <= 1;
               end
            end

            // Wait for the mailbox message header to be set
            STATE_SET_HEADER : begin
               if (axi_lite_to_cms.awready && axi_lite_to_cms.awvalid) begin
                  axi_lite_to_cms.awvalid <= 0;
                  axi_lite_to_cms.wvalid <= 1;
               end else if (axi_lite_to_cms.wready && axi_lite_to_cms.wvalid) begin // write accepted
                  axi_lite_to_cms.awvalid <= 1;
                  axi_lite_to_cms.awaddr <= C_MAILBOX_CAGE_SEL_REG;
                  axi_lite_to_cms.wdata <= 32'h0000_0000 + qsfp_sel;
                  axi_lite_to_cms.wstrb <= '1;
                  curr_state <= STATE_SET_CAGE_SEL;
               end
            end

            //  Wait for the QSFP Cage Select to be written
            STATE_SET_CAGE_SEL: begin
               if (axi_lite_to_cms.wready && axi_lite_to_cms.wvalid) begin // write accepted
                  axi_lite_to_cms.awvalid <= 1;
                  axi_lite_to_cms.awaddr <= C_MAILBOX_PAGE_SEL_REG;
                  axi_lite_to_cms.wdata <= C_PAGE_0;
                  axi_lite_to_cms.wstrb <= '1;
                  curr_state <= STATE_SET_PAGE;
               end else if (axi_lite_to_cms.awready && axi_lite_to_cms.awvalid) begin
                  axi_lite_to_cms.awvalid <= 0;
                  axi_lite_to_cms.wvalid <= 1;
               end
            end

            //  Wait for the QSFP Page Select to be written
            STATE_SET_PAGE: begin
               if (axi_lite_to_cms.wready && axi_lite_to_cms.wvalid) begin // write accepted
                  axi_lite_to_cms.awvalid <= 1;
                  axi_lite_to_cms.awaddr <= C_MAILBOX_EXTD_PAGE_SEL_REG;
                  axi_lite_to_cms.wdata <= C_LOWER_PAGE;
                  axi_lite_to_cms.wstrb <= '1;
                  curr_state <= STATE_SET_LOW_PAGE;
               end else if (axi_lite_to_cms.awready && axi_lite_to_cms.awvalid) begin
                  axi_lite_to_cms.awvalid <= 0;
                  axi_lite_to_cms.wvalid <= 1;
               end
            end

            //  Wait for the QSFP Lower Page Select to be written
            STATE_SET_LOW_PAGE: begin
               if (axi_lite_to_cms.wready && axi_lite_to_cms.wvalid) begin // write accepted
                  axi_lite_to_cms.awvalid <= 1;
                  axi_lite_to_cms.awaddr <= C_MAILBOX_PAGE_BYTE_OFFSET_REG;
                  axi_lite_to_cms.wdata <= C_CDR_REGISTER;
                  axi_lite_to_cms.wstrb <= '1;
                  curr_state <= STATE_SET_REG;
               end else if (axi_lite_to_cms.awready && axi_lite_to_cms.awvalid) begin
                  axi_lite_to_cms.awvalid <= 0;
                  axi_lite_to_cms.wvalid <= 1;
               end
            end

            //  Wait for the QSFP Register within the Page to be written
            STATE_SET_REG: begin
               if (axi_lite_to_cms.wready && axi_lite_to_cms.wvalid) begin // write accepted
                  axi_lite_to_cms.awvalid <= 1;
                  axi_lite_to_cms.awaddr <= C_MAILBOX_DATA_REG;
                  axi_lite_to_cms.wdata <= C_DISABLE_CDR;
                  axi_lite_to_cms.wstrb <= '1;
                  curr_state <= STATE_SET_DATA;
               end else if (axi_lite_to_cms.awready && axi_lite_to_cms.awvalid) begin
                  axi_lite_to_cms.awvalid <= 0;
                  axi_lite_to_cms.wvalid <= 1;
               end
            end

            //  Wait for the QSFP Register Data to be written
            STATE_SET_DATA: begin
               if (axi_lite_to_cms.wready && axi_lite_to_cms.wvalid) begin // write accepted
                  axi_lite_to_cms.awvalid <= 1;
                  axi_lite_to_cms.awaddr <= C_CMS_CONTROL_REG;
                  axi_lite_to_cms.wdata <= C_MAILBOX_MSG_STATUS_MASK;
                  axi_lite_to_cms.wstrb <= '1;
                  curr_state <= STATE_WAIT_DONE;
               end else if (axi_lite_to_cms.awready && axi_lite_to_cms.awvalid) begin
                  axi_lite_to_cms.awvalid <= 0;
                  axi_lite_to_cms.wvalid <= 1;
               end
            end

            // Wait for mailbox start transaction to finish, then poll that register continuously
            // until it returns a done condition.
            STATE_WAIT_DONE: begin
               if (axi_lite_to_cms.awready && axi_lite_to_cms.awvalid) begin
                  axi_lite_to_cms.awvalid <= 0;
                  axi_lite_to_cms.wvalid <= 1;
               end else if (axi_lite_to_cms.wready && axi_lite_to_cms.wvalid) begin // write accepted
                  axi_lite_to_cms.wvalid <= 0;
                  axi_lite_to_cms.wstrb <= 0;
                  axi_lite_to_cms.arvalid <= 1;
                  axi_lite_to_cms.araddr <= C_CMS_CONTROL_REG;
               end else if (axi_lite_to_cms.arready && axi_lite_to_cms.arvalid) begin
                  axi_lite_to_cms.arvalid <= 0;
                  axi_lite_to_cms.rready <= 1;
               end else if (axi_lite_to_cms.rready && axi_lite_to_cms.rvalid) begin
                  axi_lite_to_cms.arvalid <= 1;
                  axi_lite_to_cms.rready <= 0;
                  if ((axi_lite_to_cms.rdata & C_MAILBOX_MSG_STATUS_MASK) == 0) begin
                     axi_lite_to_cms.araddr <= C_HOST_MSG_ERROR_REG;
                     curr_state <= STATE_CHECK_RESULT;
                  end
               end
            end

            // Wait to check the result bits to verify the write succeeded
            // Once received, update result status bit and either switch to the next QSFP to check or be done
            STATE_CHECK_RESULT : begin
               if (axi_lite_to_cms.arready && axi_lite_to_cms.arvalid) begin
                  axi_lite_to_cms.arvalid <= 0;
                  axi_lite_to_cms.rready <= 1;
               end else if (axi_lite_to_cms.rready && axi_lite_to_cms.rvalid) begin
                  axi_lite_to_cms.rready <= 0;
                  config_status[qsfp_sel] <= (axi_lite_to_cms.rdata == C_NO_ERROR);
                  if (qsfp_sel >= P_NUM_QSFP-1) begin // last QSFP cage, so be done!
                     curr_state <= STATE_DONE;
                  end else begin
                     qsfp_sel <= qsfp_sel + 1;
                     axi_lite_to_cms.awvalid <= 1;
                     axi_lite_to_cms.awaddr <= C_MAILBOX_HEADER_REG;
                     axi_lite_to_cms.wdata <= C_BYTE_WRITE_HEADER;
                     axi_lite_to_cms.wstrb <= '1;
                     curr_state <= STATE_SET_HEADER;
                  end
               end
            end

            // When all done, just sit idle
            STATE_DONE : begin
               if (config_start) begin
                  config_done <= 0;
                  axi_lite_to_cms.awvalid <= 1;
                  axi_lite_to_cms.awaddr <= C_MB_RESETN_REG;
                  axi_lite_to_cms.wdata <= C_MB_RESET_INACTIVE;
                  curr_state <= STATE_EXIT_RESET;
               end else begin
                  config_done <= 1;
                  curr_state <= STATE_DONE;
               end
            end

            // Sit idle until a configration start is pulsed
            default: begin // STATE_IDLE
               if (config_start) begin
                  axi_lite_to_cms.awvalid <= 1;
                  axi_lite_to_cms.awaddr <= C_MB_RESETN_REG;
                  axi_lite_to_cms.wdata <= C_MB_RESET_INACTIVE;
                  curr_state <= STATE_EXIT_RESET;
               end
               config_done <= 0;
               config_status <= 0;
               qsfp_sel <= 0;
            end
         endcase
      end
   end


endmodule
