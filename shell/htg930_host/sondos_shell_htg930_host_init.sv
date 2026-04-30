// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

module sondos_shell_htg930_host_init (
        input           clk_i,
        input           reset_i,
        input           main_i2c_core_start_i,
        input           ff0_i2c_core_start_i,
        input           ff1_i2c_core_start_i,
        input [31:0]    si5341_reg_i,
        input [31:0]    ff0_reg_i,
        input [31:0]    ff1_reg_i,
        output          si5341_init_busy_o,
        output [31:0]   si5341_init_status_code_reg_0_o,
        output [31:0]   si5341_init_status_code_reg_1_o,
        output [31:0]   ff0_init_status_code_o,
        output [31:0]   ff1_init_status_code_o,
        output          ff0_init_reset_firefly_n_o,
        output          ff1_init_reset_firefly_n_o,
        input [31:0]    ff_init_por_wait_i,
        input [31:0]    ff_init_inter_transfer_wait_i,

        input [31:0]    si5341_init_por_wait_i,
        input [31:0]    si5341_init_inter_transfer_wait_i,
        input [31:0]    si5341_init_post_preamble_wait_i,
        input [31:0]    si5341_init_post_config_wait_i,

        output [31:0]   main_i2c_read_data_o,
        output          main_i2c_core_ready_o,
        output [4:0]    main_i2c_core_acks_o,

        output [31:0]   ff0_i2c_read_data_o,
        output          ff0_i2c_core_ready_o,
        output [4:0]    ff0_i2c_core_acks_o,

        output [31:0]   ff1_i2c_read_data_o,
        output          ff1_i2c_core_ready_o,
        output [4:0]    ff1_i2c_core_acks_o,

        input           ff0_iic_scl_i,
        output          ff0_iic_scl_o,
        output          ff0_iic_scl_t,
        input           ff0_iic_sda_i,
        output          ff0_iic_sda_o,
        output          ff0_iic_sda_t,

        input           ff1_iic_scl_i,
        output          ff1_iic_scl_o,
        output          ff1_iic_scl_t,
        input           ff1_iic_sda_i,
        output          ff1_iic_sda_o,
        output          ff1_iic_sda_t,

        input           main_iic_scl_i,
        output          main_iic_scl_o,
        output          main_iic_scl_t,
        input           main_iic_sda_i,
        output          main_iic_sda_o,
        output          main_iic_sda_t

    );

    logic           si5341_init_start_new_command;
    logic [15:0]    si5341_init_data_out;
    logic [6:0]     si5341_init_dev_address;
    logic           si5341_init_rd_wrb;
    logic [3:0]     si5341_init_num_write_data_bytes;
    logic [3:0]     si5341_init_num_read_data_bytes;

    logic           main_start_new_command;
    logic [15:0]    main_data_in;
    logic [6:0]     main_dev_address;
    logic [3:0]     main_num_write_data_bytes;
    logic [3:0]     main_num_read_data_bytes;


    htg930_si5341_init htg930_si5341_init_inst (
        .clk_i                  (clk_i),
        .reset_i                (reset_i),
        .data_ready_i           (main_i2c_core_ready_o),
        .run_i                  (1'b1), // Debug signal. Causes the state machine to run through all of its states
        .send_next_i            (1'b0), // Debug signal. Steps through each I2C transaction individually
        .ack_vector_i           (main_i2c_core_acks_o),
        .por_wait_i             (si5341_init_por_wait_i),
        .inter_transfer_wait_i  (si5341_init_inter_transfer_wait_i),
        .post_preamble_wait_i   (si5341_init_post_preamble_wait_i),
        .post_config_wait_i     (si5341_init_post_config_wait_i),
        .start_new_command_o    (si5341_init_start_new_command),
        .data_out_o             (si5341_init_data_out),
        .dev_address_o          (si5341_init_dev_address),
        .rd_wrb_o               (si5341_init_rd_wrb),
        .num_write_data_bytes_o (si5341_init_num_write_data_bytes),
        .num_read_data_bytes_o  (si5341_init_num_read_data_bytes),
        .busy_o                 (si5341_init_busy_o),
        .status_code_reg0_o     (si5341_init_status_code_reg_0_o),
        .status_code_reg1_o     (si5341_init_status_code_reg_1_o)
    );

    assign main_start_new_command       = si5341_init_busy_o ? si5341_init_start_new_command : main_i2c_core_start_i;
    assign main_data_in                 = si5341_init_busy_o ? si5341_init_data_out : si5341_reg_i[15:0];
    assign main_dev_address             = si5341_init_busy_o ? si5341_init_dev_address : si5341_reg_i[30:24];
    assign main_rd_wrb                  = si5341_init_busy_o ? si5341_init_rd_wrb : si5341_reg_i[31];
    assign main_num_write_data_bytes    = si5341_init_busy_o ? si5341_init_num_write_data_bytes : si5341_reg_i[19:16];
    assign main_num_read_data_bytes     = si5341_init_busy_o ? si5341_init_num_read_data_bytes : si5341_reg_i[23:20];

    sondos_i2c_master_core #(.MAX_DATA_BYTES(2)) main_i2c_core_inst(
        .clk                    (clk_i),
        .reset                  (reset_i),
        .clocks_per_event       (1500),
        .i2c_scl_i              (main_iic_scl_i),
        .i2c_scl_o              (main_iic_scl_o),
        .i2c_scl_t              (main_iic_scl_t),
        .i2c_sda_i              (main_iic_sda_i),
        .i2c_sda_o              (main_iic_sda_o),
        .i2c_sda_t              (main_iic_sda_t),
        .data_in                (main_data_in),
        .data_out               (main_i2c_read_data_o),
        .num_write_data_bytes   (main_num_write_data_bytes),
        .num_read_data_bytes    (main_num_read_data_bytes),
        .dev_address            (main_dev_address),
        .rd_wrb                 (main_rd_wrb),
        .start_new_command      (main_start_new_command),
        .data_ready             (main_i2c_core_ready_o),
        .ack_vector             (main_i2c_core_acks_o)
    );

    // ============================== //
    //          Firefly I2C
    // ============================== //

    logic           ff0_init_start_new_command;
    logic [15:0]    ff0_init_data_out;
    logic [6:0]     ff0_init_dev_address;
    logic           ff0_init_rd_wrb;
    logic [3:0]     ff0_init_num_write_data_bytes;
    logic [3:0]     ff0_init_num_read_data_bytes;

    logic           ff0_start_new_command;
    logic [15:0]    ff0_data_in;
    logic [6:0]     ff0_dev_address;
    logic           ff0_rd_wrb;
    logic [3:0]     ff0_num_write_data_bytes;
    logic [3:0]     ff0_num_read_data_bytes;
    logic           ff0_init_busy;

    htg930_firefly_init htg930_firefly_init_ff0 (
        .clk_i                  (clk_i),
        .reset_i                (reset_i),
        .data_ready_i           (ff0_i2c_core_ready_o),
        .ack_vector_i           (ff0_i2c_core_acks_o),
        .por_wait_i             (ff_init_por_wait_i),
        .inter_transfer_wait_i  (ff_init_inter_transfer_wait_i),
        .start_new_command_o    (ff0_init_start_new_command),
        .data_out_o             (ff0_init_data_out),
        .dev_address_o          (ff0_init_dev_address),
        .rd_wrb_o               (ff0_init_rd_wrb),
        .num_write_data_bytes_o (ff0_init_num_write_data_bytes),
        .num_read_data_bytes_o  (ff0_init_num_read_data_bytes),
        .busy_o                 (ff0_init_busy),
        .status_code_o          (ff0_init_status_code_o),
        .reset_firefly_n_o      (ff0_init_reset_firefly_n_o)
    );

    assign ff0_start_new_command    = ff0_init_busy ? ff0_init_start_new_command : ff0_i2c_core_start_i;
    assign ff0_data_in              = ff0_init_busy ? ff0_init_data_out : ff0_reg_i[15:0];
    assign ff0_dev_address          = ff0_init_busy ? ff0_init_dev_address : ff0_reg_i[30:24];
    assign ff0_rd_wrb               = ff0_init_busy ? ff0_init_rd_wrb : ff0_reg_i[31];
    assign ff0_num_write_data_bytes = ff0_init_busy ? ff0_init_num_write_data_bytes : ff0_reg_i[19:16];
    assign ff0_num_read_data_bytes  = ff0_init_busy ? ff0_init_num_read_data_bytes : ff0_reg_i[23:20];

    sondos_i2c_master_core #(.MAX_DATA_BYTES(2)) ff0_i2c_core_inst(
        .clk                    (clk_i),
        .reset                  (reset_i),
        .clocks_per_event       (1500),
        .i2c_scl_i              (ff0_iic_scl_i),
        .i2c_scl_o              (ff0_iic_scl_o),
        .i2c_scl_t              (ff0_iic_scl_t),
        .i2c_sda_i              (ff0_iic_sda_i),
        .i2c_sda_o              (ff0_iic_sda_o),
        .i2c_sda_t              (ff0_iic_sda_t),
        .data_in                (ff0_data_in),
        .data_out               (ff0_i2c_read_data_o),
        .num_write_data_bytes   (ff0_num_write_data_bytes),
        .num_read_data_bytes    (ff0_num_read_data_bytes),
        .dev_address            (ff0_dev_address),
        .rd_wrb                 (ff0_rd_wrb),
        .start_new_command      (ff0_start_new_command),
        .data_ready             (ff0_i2c_core_ready_o),
        .ack_vector             (ff0_i2c_core_acks_o)
    );

    logic           ff1_init_start_new_command;
    logic [15:0]    ff1_init_data_out;
    logic [6:0]     ff1_init_dev_address;
    logic           ff1_init_rd_wrb;
    logic [3:0]     ff1_init_num_write_data_bytes;
    logic [3:0]     ff1_init_num_read_data_bytes;

    logic           ff1_start_new_command;
    logic [15:0]    ff1_data_in;
    logic [6:0]     ff1_dev_address;
    logic           ff1_rd_wrb;
    logic [3:0]     ff1_num_write_data_bytes;
    logic [3:0]     ff1_num_read_data_bytes;
    logic           ff1_init_busy;
    logic [4:0]     ff1_ack_vector;

    htg930_firefly_init htg930_firefly_init_ff1 (
        .clk_i                  (clk_i),
        .reset_i                (reset_i),
        .data_ready_i           (ff1_i2c_core_ready_o),
        .ack_vector_i           (ff1_i2c_core_acks_o),
        .por_wait_i             (ff_init_por_wait_i),
        .inter_transfer_wait_i  (ff_init_inter_transfer_wait_i),
        .start_new_command_o    (ff1_init_start_new_command),
        .data_out_o             (ff1_init_data_out),
        .dev_address_o          (ff1_init_dev_address),
        .rd_wrb_o               (ff1_init_rd_wrb),
        .num_write_data_bytes_o (ff1_init_num_write_data_bytes),
        .num_read_data_bytes_o  (ff1_init_num_read_data_bytes),
        .busy_o                 (ff1_init_busy),
        .status_code_o          (ff1_init_status_code_o),
        .reset_firefly_n_o      (ff1_init_reset_firefly_n_o)
    );

    assign ff1_start_new_command    = ff1_init_busy ? ff1_init_start_new_command : ff1_i2c_core_start_i;
    assign ff1_data_in              = ff1_init_busy ? ff1_init_data_out : ff1_reg_i[15:0];
    assign ff1_dev_address          = ff1_init_busy ? ff1_init_dev_address : ff1_reg_i[30:24];
    assign ff1_rd_wrb               = ff1_init_busy ? ff1_init_rd_wrb : ff1_reg_i[31];
    assign ff1_num_write_data_bytes = ff1_init_busy ? ff1_init_num_write_data_bytes : ff1_reg_i[19:16];
    assign ff1_num_read_data_bytes  = ff1_init_busy ? ff1_init_num_read_data_bytes : ff1_reg_i[23:20];

    sondos_i2c_master_core #(.MAX_DATA_BYTES(2)) ff1_i2c_core_inst(
        .clk                    (clk_i),
        .reset                  (reset_i),
        .clocks_per_event       (1500),
        .i2c_scl_i              (ff1_iic_scl_i),
        .i2c_scl_o              (ff1_iic_scl_o),
        .i2c_scl_t              (ff1_iic_scl_t),
        .i2c_sda_i              (ff1_iic_sda_i),
        .i2c_sda_o              (ff1_iic_sda_o),
        .i2c_sda_t              (ff1_iic_sda_t),
        .data_in                (ff1_data_in),
        .data_out               (ff1_i2c_read_data_o),
        .num_write_data_bytes   (ff1_num_write_data_bytes),
        .num_read_data_bytes    (ff1_num_read_data_bytes),
        .dev_address            (ff1_dev_address),
        .rd_wrb                 (ff1_rd_wrb),
        .start_new_command      (ff1_start_new_command),
        .data_ready             (ff1_i2c_core_ready_o),
        .ack_vector             (ff1_i2c_core_acks_o)
    );

endmodule
