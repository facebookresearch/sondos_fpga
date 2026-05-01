# SPDX-License-Identifier: MIT
# (c) Meta Platforms, Inc. and affiliates.

import sondos.sondos as sondos

ReadyAckRegOffset = 8
ReadDataRegOffset = 4
WriteCmdDataRegOffset = 0


class SondosI2C(object):
    def __init__(self, BaseRegAddress, max_num_retries=10):
        self.hal = sondos.SondosHAL()
        self.iface = self.hal.iface
        self.base_reg_address = BaseRegAddress
        self.error_detected = False
        self.max_retry = max_num_retries

    def get_ready_bit(self):
        ready = (
            self.iface.read_register(self.base_reg_address + ReadyAckRegOffset) & 0x1
        )
        return ready

    def get_ack_bits(self):
        ack_bits = (
            self.iface.read_register(self.base_reg_address + ReadyAckRegOffset) >> 1
        )
        return ack_bits

    def prepare_command(
        self, rd_wrb, dev_address, num_read_bytes, num_write_bytes, write_data
    ):
        command = (
            ((rd_wrb & 0x1) << 31)
            + ((dev_address & 0x7F) << 24)
            + ((num_read_bytes & 0xF) << 20)
            + ((num_write_bytes & 0xF) << 16)
            + (write_data & 0xFFFF)
        )
        return command

    def write_command(self, command):
        self.iface.write_register(
            self.base_reg_address + WriteCmdDataRegOffset, command
        )

    def get_read_data(self):
        data = self.iface.read_register(self.base_reg_address + ReadDataRegOffset)
        return data

    # read a single byte from device
    def read_i2c_D8(self, dev_address):
        if self.get_ready_bit() == 0:
            print("Error Device is not ready at start of read_i2c_D8 function")
            self.error_detected = True
            return 0
        command = self.prepare_command(
            rd_wrb=1,
            dev_address=dev_address,
            num_read_bytes=1,
            num_write_bytes=0,
            write_data=0,
        )
        self.write_command(command)
        num_trials = 0
        while (num_trials < 1000) and (self.get_ready_bit() == 0):
            num_trials = num_trials + 1
        if self.get_ready_bit() == 0:
            print("timed out while waiting for ready bit in read_i2c_D8 function")
            self.error_detected = True
            return 0
        rx_byte = self.get_read_data() & 0xFF
        # since this is a single byte read, we only check the ack for the address which would be at bit 1
        # the data ack at bit 0 will be a NACK
        relevant_acks = self.get_ack_bits() & 0x2
        if relevant_acks != 0:
            print("Error: unexpected ack bits in read_i2c_D8 function")
            self.error_detected = True
        return rx_byte

    # write a single byte to device
    def write_i2c_D8(self, dev_address, data):
        if self.get_ready_bit() == 0:
            print("Error Device is not ready at start of write_i2c_D8 function")
            self.error_detected = True
            return 0

        # shifting single byte data input to be msb aligned
        aligned_data = data << 8
        command = self.prepare_command(
            rd_wrb=0,
            dev_address=dev_address,
            num_read_bytes=0,
            num_write_bytes=1,
            write_data=aligned_data,
        )

        self.write_command(command)
        num_trials = 0
        while (num_trials < 1000) and (self.get_ready_bit() == 0):
            num_trials = num_trials + 1
        if self.get_ready_bit() == 0:
            print("timed out while waiting for ready bit in write_i2c_D8 function")
            self.error_detected = True
            return 0

        # since this is a single byte write, we need to check the ack for the address and write data
        # those are on ack bits 1 and 0
        relevant_acks = self.get_ack_bits() & 0x3
        if relevant_acks != 0:
            print("Error: unexpected ack bits in write_i2c_D8 function")
            self.error_detected = True

    # write 2 bytes to device 1 byte address and 1 byte data
    # this function will call write_i2c_A8D8_basic and retry up to max_retry times
    def write_i2c_A8D8(self, dev_address, address, data, read_verify=True):
        num_retries = 0
        while num_retries < self.max_retry:
            self.error_detected = False
            self.write_i2c_A8D8_basic(dev_address, address, data, read_verify)
            if not self.error_detected:
                break
            num_retries = num_retries + 1
        if self.error_detected:
            print("Error: write_i2c_A8D8 failed after ", num_retries, " retries")
            exit(1)

    # write 2 bytes to device 1 byte address and 1 byte data
    def write_i2c_A8D8_basic(self, dev_address, address, data, read_verify):
        if self.get_ready_bit() == 0:
            print("Error Device is not ready at start of write_i2c_A8D8_basic function")
            self.error_detected = True
            return 0

        # combine address and data to get the aligned write data
        aligned_data = ((address & 0xFF) << 8) + (data & 0xFF)
        command = self.prepare_command(
            rd_wrb=0,
            dev_address=dev_address,
            num_read_bytes=0,
            num_write_bytes=2,
            write_data=aligned_data,
        )

        self.write_command(command)
        num_trials = 0
        while (num_trials < 1000) and (self.get_ready_bit() == 0):
            num_trials = num_trials + 1
        if self.get_ready_bit() == 0:
            print("timed out while waiting for ready bit in write_i2c_A8D8 function")
            self.error_detected = True
            return 0

        # since this is a 2 bytes write operation, we need to check the
        # ack for the address and 2 bytes of data
        # those are on ack bits 0, 1 and 2
        relevant_acks = self.get_ack_bits() & 0x7
        if relevant_acks != 0:
            print("Error: unexpected ack bits in write_i2c_A8D8_basic function")
            self.error_detected = True
        if read_verify:  # read back and verify
            self.write_i2c_D8(dev_address, address)
            rx_byte = self.read_i2c_D8(dev_address)
            if rx_byte != data:
                print("Error: read back data does not match written data")
                self.error_detected = True

    def clear_error_flag(self):
        self.error_detected = False

    def check_error_flag(self):
        return self.error_detected
