// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

module sondos_shell_htg930_remote_init (
    input           clk,
    input           reset,

    input   ff0_iic_scl_i,
    output  ff0_iic_scl_o,
    output  ff0_iic_scl_t,
    input   ff0_iic_sda_i,
    output  ff0_iic_sda_o,
    output  ff0_iic_sda_t,

    input   main_iic_scl_i,
    output  main_iic_scl_o,
    output  main_iic_scl_t,
    input   main_iic_sda_i,
    output  main_iic_sda_o,
    output  main_iic_sda_t,

    output main_iic_resetn,
    output main_iic_si_clk1_resetn,
    output main_iic_si_clk2_resetn,
    output aurora_reset_n,
    output ff0_reset_b,
    output ff0_modsel_b
);

localparam logic [31:0] LONG_WAIT = 32'd250_000_000;
localparam logic [31:0] SHORT_WAIT = 32'd10_000;

logic [31:0] main_i2c_read_data;
logic main_i2c_core_ready;
logic [4:0] main_i2c_core_acks;
logic main_i2c_core_start;

logic [31:0] ff0_i2c_read_data;
logic ff0_i2c_core_ready;
logic [4:0] ff0_i2c_core_acks;
logic ff0_i2c_core_start;

logic           si5341_init_start_new_command;
logic [15:0]    si5341_init_data_out;
logic [6:0]     si5341_init_dev_address;
logic           si5341_init_rd_wrb;
logic [3:0]     si5341_init_num_write_data_bytes;
logic [3:0]     si5341_init_num_read_data_bytes;
logic [4:0]     si5341_init_ack_vector;
logic           si5341_init_busy;

logic           ff_init_start_new_command;
logic [15:0]    ff_init_data_out;
logic [7:0]     ff_init_dev_address;
logic           ff_init_rd_wrb;
logic [3:0]     ff_init_num_write_data_bytes;
logic [3:0]     ff_init_num_read_data_bytes;
logic           ff_init_busy;
logic           ff_init_reset_firefly_n;


assign aurora_reset_n           = ~(reset | si5341_init_busy);
assign main_iic_resetn          = 1'b0;
assign main_iic_si_clk1_resetn  = 1'b1;
assign main_iic_si_clk2_resetn  = 1'b1;
assign ff0_reset_b              = ff_init_reset_firefly_n;
assign ff0_modsel_b             = 1'b0;




// ============================== //
//      Clock Generator I2C
// ============================== //

htg930_si5341_init htg930_si5341_init_inst (
    .clk_i                  (clk),
    .reset_i                (reset),
    .data_ready_i           (main_i2c_core_ready),
    .run_i                  (1'b1), // Debug signal. Causes the state machine to run through all of its states
    .send_next_i            (1'b0), // Debug signal. Steps through each I2C transaction individually

    .ack_vector_i           (main_i2c_core_acks),
    .por_wait_i             (LONG_WAIT),
    .inter_transfer_wait_i  (SHORT_WAIT),
    .post_preamble_wait_i   (LONG_WAIT),
    .post_config_wait_i     (LONG_WAIT),

    .start_new_command_o    (si5341_init_start_new_command),
    .data_out_o             (si5341_init_data_out),
    .dev_address_o          (si5341_init_dev_address),
    .rd_wrb_o               (si5341_init_rd_wrb),
    .num_write_data_bytes_o (si5341_init_num_write_data_bytes),
    .num_read_data_bytes_o  (si5341_init_num_read_data_bytes),
    .busy_o                 (si5341_init_busy),

    .status_code_reg0_o     (),
    .status_code_reg1_o     ()
);

sondos_i2c_master_core #(.MAX_DATA_BYTES(2)) main_i2c_core_inst(
    .clk,
    .reset,
    .clocks_per_event       (1500),
    .i2c_scl_i              (main_iic_scl_i),
    .i2c_scl_o              (main_iic_scl_o),
    .i2c_scl_t              (main_iic_scl_t),
    .i2c_sda_i              (main_iic_sda_i),
    .i2c_sda_o              (main_iic_sda_o),
    .i2c_sda_t              (main_iic_sda_t),
    .data_in                (si5341_init_data_out),
    .data_out               (main_i2c_read_data),
    .num_write_data_bytes   (si5341_init_num_write_data_bytes),
    .num_read_data_bytes    (si5341_init_num_read_data_bytes),
    .dev_address            (si5341_init_dev_address),
    .rd_wrb                 (si5341_init_rd_wrb),
    .start_new_command      (si5341_init_start_new_command),
    .data_ready             (main_i2c_core_ready),
    .ack_vector             (main_i2c_core_acks)
);

// ============================== //
//          Firefly I2C
// ============================== //


htg930_firefly_init htg930_firefly_init_inst (
    .clk_i                  (clk),
    .reset_i                (reset),
    .data_ready_i           (ff0_i2c_core_ready),
    .start_new_command_o    (ff_init_start_new_command),
    .data_out_o             (ff_init_data_out),
    .dev_address_o          (ff_init_dev_address),
    .rd_wrb_o               (ff_init_rd_wrb),
    .num_write_data_bytes_o (ff_init_num_write_data_bytes),
    .num_read_data_bytes_o  (ff_init_num_read_data_bytes),
    .busy_o                 (ff_init_busy),
    .ack_vector_i           (ff0_i2c_core_acks),
    .por_wait_i             (LONG_WAIT),
    .inter_transfer_wait_i  (SHORT_WAIT),
    .status_code_o          (),
    .reset_firefly_n_o      (ff_init_reset_firefly_n)
);

sondos_i2c_master_core #(.MAX_DATA_BYTES(2)) ff0_i2c_core_inst(
    .clk,
    .reset,
    .clocks_per_event       (1500),
    .i2c_scl_i              (ff0_iic_scl_i),
    .i2c_scl_o              (ff0_iic_scl_o),
    .i2c_scl_t              (ff0_iic_scl_t),
    .i2c_sda_i              (ff0_iic_sda_i),
    .i2c_sda_o              (ff0_iic_sda_o),
    .i2c_sda_t              (ff0_iic_sda_t),
    .data_in                (ff_init_data_out),
    .data_out               (ff0_i2c_read_data),
    .num_write_data_bytes   (ff_init_num_write_data_bytes),
    .num_read_data_bytes    (ff_init_num_read_data_bytes),
    .dev_address            (ff_init_dev_address),
    .rd_wrb                 (ff_init_rd_wrb),
    .start_new_command      (ff_init_start_new_command),
    .data_ready             (ff0_i2c_core_ready),
    .ack_vector             (ff0_i2c_core_acks)
);

endmodule
