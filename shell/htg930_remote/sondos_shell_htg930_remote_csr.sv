// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

`include "sondos_ver.svh"

module sondos_shell_htg930_remote_csr (
    input           clk,
    input           reset,
    input [31:0]    hard_err_counter,
    input [31:0]    soft_err_counter,
    input [31:0]    crc_pass_fail_n_counter,
    input logic [9:0] temperature_data,
    input logic [9:0] vccint_data,
    input logic [9:0] vccaux_data,
    input logic [9:0] vccbram_data,
    output logic [31:0] fan_speed,

    so_axi4l_if.slave axi_lite_user
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
        write_address <= (axi_lite_user.awvalid)? axi_lite_user.awaddr[7:2] : write_address;
        read_address <= (axi_lite_user.arvalid)? axi_lite_user.araddr[7:2] : read_address;
        read_data <= my_reg_array[read_address];
    end

    assign fan_speed = my_reg_array[16];

    always_ff @(posedge clk) begin
        my_reg_array[0]<= 32'h50D058E1;

        for(int jj=1;jj<9;jj=jj+1) begin
            my_reg_array[jj] <= (write_enable & (write_address==jj))? write_data : my_reg_array[jj];
        end

        my_reg_array[9] <= soft_err_counter;
        my_reg_array[10] <= hard_err_counter;
        my_reg_array[11] <= crc_pass_fail_n_counter;

        my_reg_array[12] <= {22'd0, temperature_data};
        my_reg_array[13] <= {22'd0, vccint_data};
        my_reg_array[14] <= {22'd0, vccaux_data};
        my_reg_array[15] <= {22'd0, vccbram_data};

        if (reset) begin
            my_reg_array[16] <= 32'h00000020;
        end else begin
            my_reg_array[16] <= (write_enable & (write_address==16))? write_data : my_reg_array[16];
        end

        for(int jj=17;jj<32;jj=jj+1) begin
            my_reg_array[jj] <= (write_enable & (write_address==jj))? write_data : my_reg_array[jj];
        end

        for(int jj=32;jj<40;jj=jj+1) begin // 32 to 39 are reserved for SW scratch
            my_reg_array[jj] <= (write_enable & (write_address==jj))? write_data : my_reg_array[jj];
        end

        my_reg_array[40] <= 0;
        my_reg_array[41] <= 0;
        my_reg_array[42] <= 0;
        my_reg_array[43] <= 0;
        my_reg_array[44] <= 0;
        my_reg_array[45] <= 0;
        my_reg_array[46] <= 0;
        my_reg_array[47] <= 0;
        my_reg_array[48] <= 0;
        my_reg_array[49] <= 0;
        my_reg_array[50] <= 0;
        my_reg_array[51] <= 0;
        my_reg_array[52] <= 0;
        my_reg_array[53] <= 0;

        // Reserved for future version info registers
        for(int jj=54;jj<62;jj=jj+1) begin
            my_reg_array[jj] <= 0;
        end

        my_reg_array[62] <= {`C_SONDOS_HW_REV, `C_SONDOS_SW_MAJOR, `C_SONDOS_SW_MINOR, `C_SONDOS_SW_PATCH};
        my_reg_array[63] <= 32'h0CB0CEFA;
    end


endmodule
