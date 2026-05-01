// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

`include "sondos_ver.svh"

module sondos_shell_u45n_host_csr (
    input           clk,
    input           reset,

    so_axi4l_if.slave axi_lite_user,

    input [31:0] remote0_axi4f_write_master_status,
    input [31:0] remote0_axi4f_read_master_status,

    input [5:0] ff0_status,

    input [31:0] ff0_hard_err_counter,
    input [31:0] ff0_soft_err_counter,
    input [31:0] ff0_crc_pass_fail_n_counter,

    output logic qsfp_config_start,
    input logic qsfp_config_done,
    input logic [1:0] qsfp_config_status

    );

    logic [31:0] my_reg_array[0:63];

    logic received_write_address;
    logic [5:0]  read_address;
    logic [5:0]  write_address;
    logic [31:0] write_data;
    logic write_enable;
    logic write_resp_valid;
    logic read_resp_valid;
    logic read_req;
    logic read_data_valid;
    logic [31:0] read_data;

    assign axi_lite_user.awready = ~received_write_address;
    assign axi_lite_user.wready = received_write_address;
    assign axi_lite_user.bid = '0;
    assign axi_lite_user.bresp = '0;
    assign axi_lite_user.buser = '0;
    assign axi_lite_user.bvalid = write_resp_valid;
    assign axi_lite_user.arready = ~(read_req | read_resp_valid);
    assign axi_lite_user.rid = '0;
    assign axi_lite_user.rdata = read_data;
    assign axi_lite_user.rresp = '0;
    assign axi_lite_user.ruser = '0;
    assign axi_lite_user.rvalid = read_resp_valid;


    always_ff @(posedge clk) begin
        if(reset) begin
            write_enable <= 1'b0;
            received_write_address <= 1'b0;
            write_resp_valid <= 1'b0;
            read_resp_valid <= 1'b0;
            read_req <= 1'b0;
        end else begin
            write_enable <= received_write_address & axi_lite_user.wvalid;
            received_write_address <= (received_write_address)? ~axi_lite_user.wvalid : axi_lite_user.awvalid;
            write_resp_valid <= (write_resp_valid)? ~axi_lite_user.bready : write_enable;
            read_resp_valid <= (read_resp_valid)? ~axi_lite_user.rready : read_req;
            read_req <= axi_lite_user.arvalid;
        end
        write_data <= axi_lite_user.wdata;
        write_address <= (axi_lite_user.awvalid)? axi_lite_user.awaddr[8:2] : write_address;
        read_address <= (axi_lite_user.arvalid)? axi_lite_user.araddr[8:2] : read_address;
        read_data <= my_reg_array[read_address];
    end


    always_ff @(posedge clk) begin
        my_reg_array[0]<= 32'h50D058E1;

        my_reg_array[1] <= ff0_status;
        my_reg_array[2] <= 32'd0;
        my_reg_array[3] <= {28'd0, qsfp_config_done, 1'b0, qsfp_config_status};

        qsfp_config_start <= (write_enable & (write_address==3))? write_data[2] : 0;

        for(int jj=4;jj<32;jj=jj+1) begin
            my_reg_array[jj] <= (write_enable & (write_address==jj))? write_data : my_reg_array[jj];
        end

        for(int jj=32;jj<40;jj=jj+1) begin // 32 to 39 are reserved for SW scratch
            my_reg_array[jj] <= (write_enable & (write_address==jj))? write_data : my_reg_array[jj];
        end

        for(int jj=40;jj<50;jj=jj+1) begin
            my_reg_array[jj] <= (write_enable & (write_address==jj))? write_data : my_reg_array[jj];
        end

        my_reg_array[50] <= remote0_axi4f_read_master_status;
        my_reg_array[51] <= 32'd0; // No Remote1
        my_reg_array[52] <= remote0_axi4f_write_master_status;
        my_reg_array[53] <= 32'd0; // No Remote1

        // Reserved for future version info registers
        for(int jj=54;jj<62;jj=jj+1) begin
            my_reg_array[jj] <= 0;
        end

        my_reg_array[62] <= {`C_SONDOS_HW_REV, `C_SONDOS_SW_MAJOR, `C_SONDOS_SW_MINOR, `C_SONDOS_SW_PATCH};
        my_reg_array[63] <= 32'h0CB0CEFA;

        my_reg_array[68] <= ff0_soft_err_counter;
        my_reg_array[69] <= ff0_hard_err_counter;
        my_reg_array[70] <= ff0_crc_pass_fail_n_counter;
    end

endmodule
