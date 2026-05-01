// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

`include "sondos_ver.svh"

module sondos_shell_u250_host_csr (
    input           clk,
    input           reset,

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
        write_address <= (axi_lite_user.awvalid)? axi_lite_user.awaddr[8:2] : write_address;
        read_address <= (axi_lite_user.arvalid)? axi_lite_user.araddr[8:2] : read_address;
        read_data <= my_reg_array[read_address];
    end


    always_ff @(posedge clk) begin
        my_reg_array[0]<= 32'h50D058E1;

        for(int jj=1;jj<32;jj=jj+1) begin // general shell use
            my_reg_array[jj] <= (write_enable & (write_address==jj))? write_data : my_reg_array[jj];
        end

        for(int jj=32;jj<40;jj=jj+1) begin // 32 to 39 are reserved for SW scratch
            my_reg_array[jj] <= (write_enable & (write_address==jj))? write_data : my_reg_array[jj];
        end

        for(int jj=40;jj<54;jj=jj+1) begin // general shell use
            my_reg_array[jj] <= (write_enable & (write_address==jj))? write_data : my_reg_array[jj];
        end

        // Reserved for future version info registers
        for(int jj=54;jj<62;jj=jj+1) begin
            my_reg_array[jj] <= 0;
        end

        my_reg_array[62] <= {`C_SONDOS_HW_REV, `C_SONDOS_SW_MAJOR, `C_SONDOS_SW_MINOR, `C_SONDOS_SW_PATCH};
        my_reg_array[63] <= 32'h0CB0CEFA;
    end

endmodule
