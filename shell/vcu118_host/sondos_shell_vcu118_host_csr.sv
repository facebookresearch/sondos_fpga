// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

`include "sondos_ver.svh"

module sondos_shell_vcu118_host_csr (
    input           clk,
    input           reset,

    so_axi4l_if.slave axi_lite_user,

    input  iic_scl_i,
    output  iic_scl_o,
    output  iic_scl_t,
    input  iic_sda_i,
    output  iic_sda_o,
    output  iic_sda_t,

    input [31:0] remote0_axi4f_write_master_status,
    input [31:0] remote1_axi4f_write_master_status,
    input [31:0] remote0_axi4f_read_master_status,
    input [31:0] remote1_axi4f_read_master_status,

    input [31:0] ff0_hard_err_counter,
    input [31:0] ff0_soft_err_counter,
    input [31:0] ff0_crc_pass_fail_n_counter,

    output aurora_reset,

    output logic spi_reset,
    output [7:0] read_reg_command,
    output spi_fsm_start,
    output [7:0] spi_fsm_command,
    output [31:0] spi_starting_address,
    output [31:0] spi_ending_address,
    input [31:0] spi_current_address,
    input [7:0] spi_state

    );

    logic [31:0] my_reg_array[0:70];

    logic [5:0]  read_address;
    logic [5:0]  write_address;
    logic [31:0] write_data;
    logic write_enable;
    logic read_req;
    logic read_data_valid;
    logic [31:0] read_data;



    assign axi_lite_user.awready = 1'b1;
    assign axi_lite_user.wready = 1'b1;
    assign axi_lite_user.bid = '0;
    assign axi_lite_user.bresp = '0;
    assign axi_lite_user.buser = '0;
    assign axi_lite_user.bvalid = 1'b1;
    assign axi_lite_user.arready = 1'b1;
    assign axi_lite_user.rid = '0;
    assign axi_lite_user.rdata = read_data;
    assign axi_lite_user.rresp = '0;
    assign axi_lite_user.ruser = '0;
    assign axi_lite_user.rvalid = read_data_valid;



    assign spi_fsm_start = my_reg_array[1][8];
    assign spi_fsm_command = my_reg_array[1][7:0];
    assign spi_starting_address = my_reg_array[2];
    assign spi_ending_address = my_reg_array[3];
    assign read_reg_command = my_reg_array[4][7:0];

    always_ff @(posedge clk) begin
        if(reset) begin
            spi_reset <= 1'b1;
        end else begin
            spi_reset <= my_reg_array[1][31];
        end
    end

    assign iic_sda_o = my_reg_array[7][0];
    assign iic_sda_t = my_reg_array[7][1];
    assign iic_scl_o = my_reg_array[7][2];
    assign iic_scl_t = my_reg_array[7][3];

    assign aurora_reset = my_reg_array[9][0];

    always_ff @(posedge clk) begin
        if(reset) begin
            write_enable <= 1'b0;
        end else begin
            write_enable <= axi_lite_user.wvalid;
        end
        write_data <= axi_lite_user.wdata;
        write_address <= (axi_lite_user.awvalid)? axi_lite_user.awaddr[7:2] : write_address;
        read_address <= (axi_lite_user.arvalid)? axi_lite_user.araddr[7:2] : read_address;
        read_req <= axi_lite_user.arvalid;
        read_data_valid <= read_req;
        read_data <= my_reg_array[read_address];
    end



    always_ff @(posedge clk) begin
            my_reg_array[0]<= 32'h50D058E1;
        if(reset) begin
            my_reg_array[1] <= '0;
            my_reg_array[2] <= '0;
            my_reg_array[7] <= '1;
            my_reg_array[9] <= '0;
        end else begin
            my_reg_array[1] <= (write_enable & (write_address==6'd1))? write_data : '0;
            my_reg_array[2] <= (write_enable & (write_address==6'd2))? write_data : my_reg_array[2];
            my_reg_array[3] <= (write_enable & (write_address==6'd3))? write_data : my_reg_array[3];
            my_reg_array[4] <= (write_enable & (write_address==6'd4))? write_data : my_reg_array[4];
            my_reg_array[7] <= (write_enable & (write_address==6'd7))? write_data : my_reg_array[7];
            my_reg_array[9] <= (write_enable & (write_address==6'd9))? write_data : my_reg_array[9];
        end

        my_reg_array[5] <= spi_current_address;
        my_reg_array[6] <= spi_state;
        my_reg_array[8] <= {iic_scl_i,iic_sda_i};

        for(int jj=10;jj<50;jj=jj+1) begin
            my_reg_array[jj] <= (write_enable & (write_address==jj))? write_data : my_reg_array[jj];
        end

        my_reg_array[50] <= remote0_axi4f_read_master_status;
        my_reg_array[51] <= remote1_axi4f_read_master_status;
        my_reg_array[52] <= remote0_axi4f_write_master_status;
        my_reg_array[53] <= remote1_axi4f_write_master_status;

        // Reserved for future version info registers
        for(int jj=54;jj<62;jj=jj+1) begin
            my_reg_array[jj] <= 0;
        end

        my_reg_array[62] <= {`C_SONDOS_HW_REV, `C_SONDOS_SW_MAJOR, `C_SONDOS_SW_MINOR, `C_SONDOS_SW_PATCH};
        my_reg_array[63] <= 32'h0CB0CEFA;

        for(int jj=64;jj<68;jj=jj+1) begin
            my_reg_array[jj] <= 0;
        end

        my_reg_array[68] <= ff0_soft_err_counter;
        my_reg_array[69] <= ff0_hard_err_counter;
        my_reg_array[70] <= ff0_crc_pass_fail_n_counter;
    end

endmodule
