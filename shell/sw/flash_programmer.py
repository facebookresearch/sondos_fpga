# SPDX-License-Identifier: MIT
# (c) Meta Platforms, Inc. and affiliates.


import ctypes
import os
import sys
import threading
import time

import sondos.sondos as sondos


class FlashInterface(object):
    def __init__(self, BufOffset, file_name):
        self.hal = sondos.SondosHAL()
        self.iface = self.hal.iface
        self.offset = BufOffset
        self.iface_valid = False
        self.file_name = file_name
        if not os.path.isfile(file_name):
            print("Error: File does not exist: ", file_name)
            return
        file_status = os.stat(file_name)
        self.file_size = file_status.st_size
        id_0 = self.iface.read_register(self.offset + 15 * 4)
        id_1 = self.iface.read_register(self.offset + 14 * 4)
        if (id_0 == 0xFFFFFFFF) or (id_1 == 0xFFFFFFFF):
            print("Error: Flash controller not found at offset", hex(self.offset))
            return
        self.dev_name = (
            id_0.to_bytes(4, "big").decode() + id_1.to_bytes(4, "big").decode()
        )
        if self.dev_name == "VCU_118 ":
            print("Detected FPGA Board: VCU118")
        elif self.dev_name == "HTG_930 ":
            print("Detected FPGA Board: HTG930")
        elif self.dev_name == "ALV_U45N":
            print("Detected FPGA Board: ALVEO U45N")
        elif self.dev_name == "ALV_U250":
            print("Detected FPGA Board: ALVEO U250")
        else:
            print("Unknown device name: ", self.dev_name)
            return

        if not self.check_bitfile_device_name():
            return

        self.iface.write_register(self.offset + 12 * 4, 0)
        if self.iface.read_register(self.offset + 13 * 4) != 0:
            print(
                "Error: Flash controller at offset ",
                hex(self.offset),
                " is already in use by another process!",
            )
            return
        self.write_local_reg(11, 0)
        self.iface.write_register(self.offset, (1 << 16))  # reset controller FSM
        self.get_bitfile_marker()
        if (
            (self.data_start1 < 0)
            or (self.data_start1 > 2048)
            or (self.data_start2 > 2048)
        ):
            print("Error finding bitfile markers")
            return
        print("Found bitfile markers at offsets: ", self.data_start1, self.data_start2)
        ret = self.init_buf()
        if ret == 1:
            self.stop = threading.Event()
            self.t = threading.Thread(target=self.loop)
            self.t.start()
            self.iface_valid = True
        else:
            print(
                "Error: Failed to initialize flash controller at offset 0x",
                hex(self.offset),
            )

    def check_bitfile_device_name(self):
        with open(self.file_name, encoding="utf-8", errors="ignore") as f1:
            line = f1.readline()
            if self.dev_name == "VCU_118 ":
                if line.find("xcvu9p-flga2104-2L-e") >= 0:
                    print("File is compatible with VCU118")
                    return True
                else:
                    print("File is not compatible with VCU118")
                    return False
            elif self.dev_name == "HTG_930 ":
                if line.find("xcvu13p-fhgb2104-2L-e") >= 0:
                    print("File is compatible with HTG930")
                    return True
                else:
                    print("Error: File is not compatible with HTG930")
                    return False
            elif self.dev_name == "ALV_U45N":
                if line.find("xcu26-vsva1365-2LV-e") >= 0:
                    print("File is compatible with ALVEO U45N")
                    return True
                else:
                    print("Error: File is not compatible with ALVEO U45N")
                    return False
            elif self.dev_name == "ALV_U250":
                if line.find("xcu250-figd2104-2L-e") >= 0:
                    print("File is compatible with ALVEO U250")
                    return True
                else:
                    print("Error: File is not compatible with ALVEO U250")
                    return False
            else:
                return False

    def init_buf(self) -> ctypes.c_uint64:
        pageSize = 4096
        self.numPages = 128
        self.bufSize = pageSize * self.numPages
        self.bufSize_32 = int(self.bufSize / 4)
        self.buf = self.hal.lib.alloc_aligned(self.bufSize, pageSize)
        self.bufPtr = ctypes.addressof(self.buf)
        self.iface.lock_mem_and_get_phys_addr(self.bufPtr, self.bufSize)
        self.bufU8 = (ctypes.c_uint8 * int(self.bufSize)).from_buffer(self.buf)
        self.bufU32 = (ctypes.c_uint32 * int(self.bufSize / 4)).from_buffer(self.buf)
        self.bufU64 = (ctypes.c_uint64 * int(self.bufSize / 8)).from_buffer(self.buf)
        self.phy_page_array = (ctypes.c_uint32 * self.numPages)(0)
        for i in range(0, self.numPages):
            if self.bufU32[i * 1024] == 0:
                print("Error loading page translation table")
                return 0
            self.phy_page_array[i] = self.bufU32[i * 1024]

        return 1

    def loop(self):
        while not self.stop.is_set():
            self.iface.write_register(self.offset + 12 * 4, 0)
            time.sleep(0.01)

    def disable_buffer(self):
        self.stop.set()
        self.t.join()
        self.iface.unlock_mem(self.bufPtr, self.bufSize)

    def read_local_reg(self, address):
        return self.iface.read_register(self.offset + 4 * address)

    def write_local_reg(self, address, value):
        return self.iface.write_register(self.offset + 4 * address, value)

    def get_bitfile_marker(self):
        byte_indx = 0
        with open(self.file_name, "rb") as f1:
            search_byte = f1.read(1)
            byte_indx = byte_indx + 1
            sync_found = False
            while (not sync_found) and (len(search_byte) > 0):
                search_byte = f1.read(1)
                byte_indx = byte_indx + 1
                if search_byte == b"\xaa":
                    search_byte = f1.read(1)
                    byte_indx = byte_indx + 1
                    if search_byte == b"\x99":
                        search_byte = f1.read(1)
                        byte_indx = byte_indx + 1
                        if search_byte == b"\x55":
                            search_byte = f1.read(1)
                            byte_indx = byte_indx + 1
                            if search_byte == b"\x66":
                                sync_found = True
            self.data_start1 = byte_indx - 84
            search_word = f1.read(4)
            byte_indx = byte_indx + 4
            while (search_word != b"\x30\x00\x80\x01") and (len(search_word) > 0):
                search_word = f1.read(4)
                byte_indx = byte_indx + 4
            search_word = f1.read(4)
            byte_indx = byte_indx + 4
            self.data_start2 = byte_indx

    def check_vcu118_bitfile_start(self):
        with open(self.file_name, "rb") as f1:
            f1.seek(self.data_start1)
            numBytes = self.data_start2 - self.data_start1
            for i in range(0, numBytes):
                tmp_byte = f1.read(1)
                expected_byte = (int.from_bytes(tmp_byte, "little") >> 4) | 0xF0
                if expected_byte != self.bufU8[2 * i]:
                    print("Error at byte: ", hex(self.data_start1 + i))
                    print(
                        "Expected: ",
                        hex(expected_byte),
                        " Actual: ",
                        hex(self.bufU8[2 * i]),
                    )
                    return False
                expected_byte = (int.from_bytes(tmp_byte, "little") & 0x0F) | 0xF0
                if expected_byte != self.bufU8[2 * i + 1]:
                    print("Error at byte: ", hex(self.data_start1 + i))
                    print(
                        "Expected: ",
                        hex(expected_byte),
                        " Actual: ",
                        hex(self.bufU8[2 * i + 1]),
                    )
                    return False
        return True

    def check_bitfile_chunk(self):
        with open(self.file_name, "rb") as f1:
            f1.seek(self.current_file_pointer)
            if self.current_file_pointer + self.bufSize > self.file_size:
                check_size = self.file_size - self.current_file_pointer
            else:
                check_size = self.bufSize
            for i in range(0, int(check_size / 4)):
                tmp_byte = f1.read(4)
                expected_byte = int.from_bytes(tmp_byte, "little")
                if expected_byte != self.bufU32[i]:
                    print("Error at offset: ", i)
                    print("Error at byte: ", hex(self.current_file_pointer + i * 4))
                    print(
                        "Expected: ",
                        hex(expected_byte),
                        " Actual: ",
                        hex(self.bufU32[i]),
                    )
                    for j in range(0, 4):
                        tmp_byte = f1.read(4)
                        expected_byte = int.from_bytes(tmp_byte, "little")
                        print(
                            "Expected: ",
                            hex(expected_byte),
                            " Actual: ",
                            hex(self.bufU32[i + j + 1]),
                        )
                    return False
        return True

    def read_vcu118_bitfile_start(self):
        with open(self.file_name, "rb") as f1:
            f1.seek(self.data_start1)
            numBytes = self.data_start2 - self.data_start1
            for i in range(0, numBytes):
                tmp_byte = f1.read(1)
                self.bufU8[2 * i] = (int.from_bytes(tmp_byte, "little") >> 4) | 0xF0
                self.bufU8[2 * i + 1] = (
                    int.from_bytes(tmp_byte, "little") & 0x0F
                ) | 0xF0
            for i in range(int(numBytes / 2), int(self.bufSize / 4)):
                tmp_byte = f1.read(4)
                self.bufU32[i] = int.from_bytes(tmp_byte, "little")
        pass

    def read_bitfile_chunk(self):
        with open(self.file_name, "rb") as f1:
            f1.seek(self.current_file_pointer)
            if self.current_file_pointer + self.bufSize > self.file_size:
                read_size = self.file_size - self.current_file_pointer
            else:
                read_size = self.bufSize
            for i in range(0, int(read_size / 4)):
                tmp_byte = f1.read(4)
                self.bufU32[i] = int.from_bytes(tmp_byte, "little")
        pass

    def read_flash_chunk(self, pages_to_read):
        for i in range(0, pages_to_read):
            self.write_local_reg(3, self.phy_page_array[i])
        self.write_local_reg(1, self.current_flash_pointer)  # Flash start address
        end_address = self.current_flash_pointer + pages_to_read * 4096 - 1
        self.write_local_reg(2, end_address)  # Flash end address
        self.write_local_reg(0, 0x101)  # Start Flash FSM in read mode
        timeout_count = 3000
        while (self.read_local_reg(5) != 0) and timeout_count > 0:
            time.sleep(0.001)
            timeout_count -= 1
        if timeout_count == 0:
            print("Timeout waiting for flash read operation to complete")
            for i in range(0, 16):
                print("reg[", i, "]=", self.read_local_reg(i))
            return False
        return True

    def write_flash_chunk(self, pages_to_write):
        for i in range(0, pages_to_write):
            self.write_local_reg(3, self.phy_page_array[i])
        self.write_local_reg(1, self.current_flash_pointer)  # Flash start address
        end_address = self.current_flash_pointer + pages_to_write * 4096 - 1
        self.write_local_reg(2, end_address)
        self.write_local_reg(0, 0x102)  # Start Flash FSM in write mode
        timeout_count = 3000
        while (self.read_local_reg(5) != 0) and timeout_count > 0:
            time.sleep(0.001)
            timeout_count -= 1
        if timeout_count == 0:
            print("Timeout waiting for flash write operation to complete")
            for i in range(0, 16):
                print("reg[", i, "]=", self.read_local_reg(i))
            return False
        return True

    def progressBar(self, count_value, total, suffix=""):
        bar_length = 20
        filled_up_Length = int(round(bar_length * count_value / float(total)))
        percentage = round(100.0 * count_value / float(total), 1)
        bar = "=" * filled_up_Length + "-" * (bar_length - filled_up_Length)
        sys.stdout.write("[%s] %s%s ...%s\r" % (bar, percentage, "%", suffix))
        sys.stdout.flush()

    def erase_flash(self, start_addr, end_addr):
        if not self.iface_valid:
            print("Erase failed: Flash interface not initialized")
            return False
        if self.read_local_reg(5) != 0:
            print("Flash is busy")
            return False
        self.write_local_reg(1, start_addr)  # Flash start address
        self.write_local_reg(2, end_addr)  # Flash end address
        self.write_local_reg(0, 0x103)  # Start Flash FSM in erase mode
        timeout_count = 3000
        previous_address = self.read_local_reg(4)
        while (self.read_local_reg(5) != 0) and timeout_count > 0:
            time.sleep(0.001)
            current_address = self.read_local_reg(4)
            self.progressBar(
                (current_address - start_addr), (end_addr - start_addr), "Erasing Flash"
            )
            if current_address == previous_address:
                timeout_count -= 1
            else:
                previous_address = current_address
                timeout_count = 3000
        if timeout_count == 0:
            print("Timeout waiting for flash erase operation to complete")
            for i in range(0, 16):
                print("reg[", i, "]=", self.read_local_reg(i))
            return False
        else:
            self.progressBar(1, 1, "Erasing Flash")
        print("")
        return True

    def test_bitfile(self):
        if not self.iface_valid:
            print("Verification failed: Flash interface not initialized")
            return False
        if self.read_local_reg(5) != 0:
            print("Flash is busy")
            return False
        self.write_local_reg(0, (1 << 16))  # # reset controller FSM
        time.sleep(0.1)
        self.write_local_reg(0, (1 << 10))  # Put AXI FSM in write mode
        self.current_flash_pointer = 0
        if self.dev_name == "ALV_U250":
            self.current_flash_pointer = 0x1002000
        self.current_file_pointer = self.data_start1
        if self.dev_name == "VCU_118 ":
            if not self.read_flash_chunk(1):
                print("Flash read failed")
                return False
            if not self.check_vcu118_bitfile_start():
                print("Bit file header field verification failed")
                return False
            self.current_file_pointer = self.data_start2
            self.current_flash_pointer = (self.data_start2 - self.data_start1) * 2
        while self.current_file_pointer < self.file_size:
            if not self.read_flash_chunk(self.numPages):
                print("Flash read failed")
                return False
            if not self.check_bitfile_chunk():
                print("Bit file chunk verification failed")
                return False
            self.current_file_pointer += self.bufSize
            self.current_flash_pointer += self.bufSize
        return True

    def write_flash(self):
        if not self.iface_valid:
            print("Write failed: Flash interface not initialized")
            return False
        if self.read_local_reg(5) != 0:
            print("Flash is busy")
            return False
        self.write_local_reg(0, (1 << 16))  # # reset controller FSM
        time.sleep(0.1)
        self.current_file_pointer = self.data_start1
        self.current_flash_pointer = 0
        if self.dev_name == "ALV_U250":
            self.current_flash_pointer = 0x1002000
        erase_end_address = self.current_flash_pointer + (
            int((self.file_size / self.bufSize) + 1) * self.bufSize
        )
        if not self.erase_flash(self.current_flash_pointer, erase_end_address):
            print("Flash erase failed")
            return False
        self.write_local_reg(0, (1 << 16))  # # reset controller FSM
        time.sleep(0.1)
        self.write_local_reg(0, (1 << 9))  # Put AXI FSM in read mode
        total_writes = int(self.file_size / self.bufSize)
        itteration = 0
        if self.dev_name == "VCU_118 ":
            self.read_vcu118_bitfile_start()
            if not self.write_flash_chunk(self.numPages):
                print("Flash write failed")
                return False
            self.current_file_pointer += self.bufSize - (
                self.data_start2 - self.data_start1
            )
            self.current_flash_pointer += self.bufSize
            itteration += 1
        while self.current_file_pointer < self.file_size:
            self.read_bitfile_chunk()
            if not self.write_flash_chunk(self.numPages):
                print("Flash write failed")
                return False
            self.current_file_pointer += self.bufSize
            self.current_flash_pointer += self.bufSize
            self.progressBar(itteration, total_writes, "Writing Flash")
            itteration += 1

        print("")
        return True
