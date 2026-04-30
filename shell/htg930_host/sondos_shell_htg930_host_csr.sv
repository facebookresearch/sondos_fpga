// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

`include "sondos_ver.svh"

module sondos_shell_htg930_host_csr (
    input           clk,
    input           reset,

    so_axi4l_if.slave axi_lite_user,

    input   ff0_iic_scl_i,
    output  ff0_iic_scl_o,
    output  ff0_iic_scl_t,
    input   ff0_iic_sda_i,
    output  ff0_iic_sda_o,
    output  ff0_iic_sda_t,

    input   ff1_iic_scl_i,
    output  ff1_iic_scl_o,
    output  ff1_iic_scl_t,
    input   ff1_iic_sda_i,
    output  ff1_iic_sda_o,
    output  ff1_iic_sda_t,

    input   main_iic_scl_i,
    output  main_iic_scl_o,
    output  main_iic_scl_t,
    input   main_iic_sda_i,
    output  main_iic_sda_o,
    output  main_iic_sda_t,

    output [7:0] fan_speed,
    input [31:0] remote0_axi4f_write_master_status,
    input [31:0] remote1_axi4f_write_master_status,
    input [31:0] remote0_axi4f_read_master_status,
    input [31:0] remote1_axi4f_read_master_status,

    input [5:0] ff0_status,
    input [5:0] ff1_status,

    input [31:0] ff0_hard_err_counter,
    input [31:0] ff0_soft_err_counter,
    input [31:0] ff0_crc_pass_fail_n_counter,

    input [31:0] ff1_hard_err_counter,
    input [31:0] ff1_soft_err_counter,
    input [31:0] ff1_crc_pass_fail_n_counter,

    input ff0_soft_error,
    input ff0_hard_error,
    input ff0_crc_pass_fail_n,
    input ff0_crc_valid,

    input ff1_soft_error,
    input ff1_hard_error,
    input ff1_crc_pass_fail_n,
    input ff1_crc_valid,

    output main_iic_resetn,
    output main_iic_si_clk1_resetn,
    output main_iic_si_clk2_resetn,
    output aurora_reset,
    output ff0_reset_b,
    output ff0_modsel_b,
    output ff1_reset_b,
    output ff1_modsel_b,
    input [2:0] ff_present_b,

    output logic spi_reset,
    output [7:0] read_reg_command,
    output spi_fsm_start,
    output [7:0] spi_fsm_command,
    output [31:0] spi_starting_address,
    output [31:0] spi_ending_address,
    input [31:0] spi_current_address,
    input [7:0] spi_state

    );

    localparam logic [7:0] INITIAL_FAN_SPEED = 8'h50;

    logic [31:0] my_reg_array[0:73];

    logic received_write_address;
    logic [6:0]  read_address;
    logic [6:0]  write_address;
    logic [31:0] write_data;
    logic write_enable;
    logic write_resp_valid;
    logic read_resp_valid;
    logic read_req;
    logic read_data_valid;
    logic [31:0] read_data;

    logic [31:0]    main_i2c_read_data;
    logic           main_i2c_core_ready;
    logic [4:0]     main_i2c_core_acks;

    logic [31:0]    ff0_i2c_read_data;
    logic           ff0_i2c_core_ready;
    logic [4:0]     ff0_i2c_core_acks;

    logic [31:0]    ff1_i2c_read_data;
    logic           ff1_i2c_core_ready;
    logic [4:0]     ff1_i2c_core_acks;

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

    logic aurora_reset_gen;
    logic soft_reset;
    logic ff0_init_reset_firefly_n;
    logic ff1_init_reset_firefly_n;

    logic si5341_init_busy;
    assign aurora_reset             = si5341_init_busy | my_reg_array[11][0];
    assign main_iic_resetn          = 1'b0;
    assign main_iic_si_clk1_resetn  = 1'b1;
    assign main_iic_si_clk2_resetn  = 1'b1;
    assign ff0_reset_b              = ff0_init_reset_firefly_n;
    assign ff0_modsel_b             = 1'b0;
    assign ff1_reset_b              = ff1_init_reset_firefly_n;
    assign ff1_modsel_b             = 1'b0;
    assign soft_reset               = my_reg_array[11][8];

    assign fan_speed = my_reg_array[12][7:0];

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


    logic [31:0] si5341_init_status_code_reg_0;
    logic [31:0] si5341_init_status_code_reg_1;
    logic [31:0] ff0_init_status_code;
    logic [31:0] ff1_init_status_code;

    always_ff @(posedge clk) begin
        my_reg_array[0]<= 32'h50D058E1;
        if(reset) begin
            my_reg_array[1] <= '0;
            my_reg_array[2] <= '0;
            my_reg_array[7] <= '1;
            my_reg_array[9] <= '1;
            my_reg_array[11] <= '0;
            my_reg_array[12] <= INITIAL_FAN_SPEED;
            my_reg_array[13] <= '0;
            my_reg_array[64] <= '0;
            my_reg_array[65] <= '0;
            my_reg_array[66] <= '0;
            my_reg_array[67] <= '0;
        end else begin
            my_reg_array[1 ] <= (write_enable & (write_address==6'd1 ))? write_data : '0;
            my_reg_array[2 ] <= (write_enable & (write_address==6'd2 ))? write_data : my_reg_array[2];
            my_reg_array[3 ] <= (write_enable & (write_address==6'd3 ))? write_data : my_reg_array[3];
            my_reg_array[4 ] <= (write_enable & (write_address==6'd4 ))? write_data : my_reg_array[4];
            my_reg_array[7 ] <= (write_enable & (write_address==6'd7 ))? write_data : my_reg_array[7];
            my_reg_array[9 ] <= (write_enable & (write_address==6'd9 ))? write_data : my_reg_array[9];
            my_reg_array[11] <= (write_enable & (write_address==6'd11))? write_data : my_reg_array[11];
            my_reg_array[12] <= (write_enable & (write_address==6'd12))? write_data : my_reg_array[12];
            my_reg_array[13] <= (write_enable & (write_address==6'd13))? write_data : my_reg_array[13];
            my_reg_array[68] <= (write_enable & (write_address==7'd68))? write_data : my_reg_array[68];
            my_reg_array[69] <= (write_enable & (write_address==7'd69))? write_data : my_reg_array[69];
            my_reg_array[70] <= (write_enable & (write_address==7'd70))? write_data : my_reg_array[70];
            my_reg_array[71] <= (write_enable & (write_address==7'd71))? write_data : my_reg_array[71];
            my_reg_array[72] <= (write_enable & (write_address==7'd72))? write_data : my_reg_array[72];
            my_reg_array[73] <= (write_enable & (write_address==7'd73))? write_data : my_reg_array[73];
        end

        my_reg_array[5] <= spi_current_address;
        my_reg_array[6] <= spi_state;
        my_reg_array[8] <= {ff0_iic_scl_i,ff0_iic_sda_i};
        my_reg_array[10] <= {main_iic_scl_i,main_iic_sda_i};
        my_reg_array[14] <= {ff1_iic_scl_i,ff1_iic_sda_i};
        my_reg_array[15] <= ff0_status;
        my_reg_array[16] <= ff1_status;
        my_reg_array[17] <= {~ff_present_b};

        for(int jj=18;jj<32;jj=jj+1) begin
            my_reg_array[jj] <= (write_enable & (write_address==jj))? write_data : my_reg_array[jj];
        end

        for(int jj=32;jj<40;jj=jj+1) begin // 32 to 39 are reserved for SW scratch
            my_reg_array[jj] <= (write_enable & (write_address==jj))? write_data : my_reg_array[jj];
        end

        my_reg_array[40] <= 32'h12C012C0; // temporaty version register until we add version tracking in shell
        my_reg_array[41] <= (write_enable & (write_address==41))? write_data : my_reg_array[41]; // main i2c write reg
        my_reg_array[42] <= main_i2c_read_data;
        my_reg_array[43] <= {main_i2c_core_acks,main_i2c_core_ready};
        my_reg_array[44] <= (write_enable & (write_address==44))? write_data : my_reg_array[44]; // ff0 i2c write reg
        my_reg_array[45] <= ff0_i2c_read_data;
        my_reg_array[46] <= {ff0_i2c_core_acks,ff0_i2c_core_ready};
        my_reg_array[47] <= (write_enable & (write_address==47))? write_data : my_reg_array[47]; // ff1 i2c write reg
        my_reg_array[48] <= ff1_i2c_read_data;
        my_reg_array[49] <= {ff1_i2c_core_acks,ff1_i2c_core_ready};
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
        my_reg_array[64] <= si5341_init_status_code_reg_0;
        my_reg_array[65] <= si5341_init_status_code_reg_1;
        my_reg_array[66] <= ff0_init_status_code;
        my_reg_array[67] <= ff1_init_status_code;

        my_reg_array[68] <= ff0_soft_err_counter;
        my_reg_array[69] <= ff0_hard_err_counter;
        my_reg_array[70] <= ff0_crc_pass_fail_n_counter;

        my_reg_array[71] <= ff1_soft_err_counter;
        my_reg_array[72] <= ff1_hard_err_counter;
        my_reg_array[73] <= ff1_crc_pass_fail_n_counter;
    end

    logic main_i2c_core_start;
    logic ff0_i2c_core_start;
    logic ff1_i2c_core_start;

    always_ff @(posedge clk) begin
        main_i2c_core_start <= (write_enable & (write_address==41));
        ff0_i2c_core_start <= (write_enable & (write_address==44));
        ff1_i2c_core_start <= (write_enable & (write_address==47));
    end

    logic [31:0] firefly_init_por_wait;
    logic [31:0] firefly_init_inter_transfer_wait;
    logic [31:0] si5341_init_por_wait;

    logic [31:0] si5341_init_inter_transfer_wait;
    logic [31:0] si5341_init_post_preamble_wait;
    logic [31:0] si5341_init_post_config_wait;

    assign firefly_init_por_wait            = 'd250_000_000; // 1s
    assign firefly_init_inter_transfer_wait = 'd10_000;
    assign si5341_init_por_wait             = 'd250_000_000; // 1s
    assign si5341_init_inter_transfer_wait  = 'd10_000;
    assign si5341_init_post_preamble_wait   = 'd250_000_000; // 1s
    assign si5341_init_post_config_wait     = 'd250_000_000; // 1s

    sondos_shell_htg930_host_init sondos_shell_htg930_host_init_inst (
        .clk_i                              (clk),
        .reset_i                            (reset | soft_reset),
        .main_i2c_core_start_i              (main_i2c_core_start),
        .ff0_i2c_core_start_i               (ff0_i2c_core_start),
        .ff1_i2c_core_start_i               (ff1_i2c_core_start),
        .si5341_reg_i                       (my_reg_array[41]),
        .ff0_reg_i                          (my_reg_array[44]),
        .ff1_reg_i                          (my_reg_array[47]),
        .si5341_init_busy_o                 (si5341_init_busy),

        .si5341_init_status_code_reg_0_o    (si5341_init_status_code_reg_0),
        .si5341_init_status_code_reg_1_o    (si5341_init_status_code_reg_1),
        .ff0_init_status_code_o             (ff0_init_status_code),
        .ff1_init_status_code_o             (ff1_init_status_code),
        .ff0_init_reset_firefly_n_o         (ff0_init_reset_firefly_n),
        .ff1_init_reset_firefly_n_o         (ff1_init_reset_firefly_n),

        .main_i2c_read_data_o               (main_i2c_read_data),
        .main_i2c_core_ready_o              (main_i2c_core_ready),
        .main_i2c_core_acks_o               (main_i2c_core_acks),

        .ff0_i2c_read_data_o                (ff0_i2c_read_data),
        .ff0_i2c_core_ready_o               (ff0_i2c_core_ready),
        .ff0_i2c_core_acks_o                (ff0_i2c_core_acks),

        .ff1_i2c_read_data_o                (ff1_i2c_read_data),
        .ff1_i2c_core_ready_o               (ff1_i2c_core_ready),
        .ff1_i2c_core_acks_o                (ff1_i2c_core_acks),

        .ff_init_por_wait_i                 (firefly_init_por_wait),
        .ff_init_inter_transfer_wait_i      (firefly_init_inter_transfer_wait),
        .si5341_init_por_wait_i             (si5341_init_por_wait),
        .si5341_init_inter_transfer_wait_i  (si5341_init_inter_transfer_wait),
        .si5341_init_post_preamble_wait_i   (si5341_init_post_preamble_wait),
        .si5341_init_post_config_wait_i     (si5341_init_post_config_wait),

        .ff0_iic_scl_i                      (ff0_iic_scl_i),
        .ff0_iic_scl_o                      (ff0_iic_scl_o),
        .ff0_iic_scl_t                      (ff0_iic_scl_t),
        .ff0_iic_sda_i                      (ff0_iic_sda_i),
        .ff0_iic_sda_o                      (ff0_iic_sda_o),
        .ff0_iic_sda_t                      (ff0_iic_sda_t),

        .ff1_iic_scl_i                      (ff1_iic_scl_i),
        .ff1_iic_scl_o                      (ff1_iic_scl_o),
        .ff1_iic_scl_t                      (ff1_iic_scl_t),
        .ff1_iic_sda_i                      (ff1_iic_sda_i),
        .ff1_iic_sda_o                      (ff1_iic_sda_o),
        .ff1_iic_sda_t                      (ff1_iic_sda_t),

        .main_iic_scl_i                     (main_iic_scl_i),
        .main_iic_scl_o                     (main_iic_scl_o),
        .main_iic_scl_t                     (main_iic_scl_t),
        .main_iic_sda_i                     (main_iic_sda_i),
        .main_iic_sda_o                     (main_iic_sda_o),
        .main_iic_sda_t                     (main_iic_sda_t)

    );

endmodule
