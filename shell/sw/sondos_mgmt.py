# SPDX-License-Identifier: MIT
# (c) Meta Platforms, Inc. and affiliates.

import argparse
import json
import time
from pathlib import Path

import flash_programmer
import sondos.sondos as sondos
import sondos_i2c

FF_PRESENT_REG = 0x00F00044
CONFIG_RESET_REG = 0x00F0002C

FF0_I2C_BASE_REG = 0x00F000B0
FF1_I2C_BASE_REG = 0x00F000BC

MAIN_I2C_BASE_REG = 0x00F000A4

TEMP_I2C_VER_REG = 0x00F000A0

SI5341_STATUS_REG0 = 0x00F00100
SI5341_STATUS_REG1 = 0x00F00104
FF0_STATUS_REG = 0x00F00108
FF1_STATUS_REG = 0x00F0010C

HOST_BASE = 0x00000000
HOST_SHELL_COMMON_BASE = HOST_BASE + 0x00F00000
HOST_SHELL_CMS_BASE = HOST_BASE + 0x00F80000
HOST_SHELL_FLASH_BASE = HOST_BASE + 0x00FF0000
REMOTE0_BASE = 0x01000000
REMOTE0_SHELL_COMMON_BASE = REMOTE0_BASE + 0x00FE0000
REMOTE0_SHELL_FLASH_BASE = REMOTE0_BASE + 0x00FF0000
REMOTE1_BASE = 0x02000000
REMOTE1_SHELL_COMMON_BASE = REMOTE1_BASE + 0x00FE0000
REMOTE1_SHELL_FLASH_BASE = REMOTE1_BASE + 0x00FF0000

HOST_AURORA0_SOFT_ERROR_REG = 0x00F00110
HOST_AURORA0_HARD_ERROR_REG = 0x00F00114
HOST_AURORA0_CRC_ERROR_REG = 0x00F00118

HOST_AURORA1_SOFT_ERROR_REG = 0x00F0011C
HOST_AURORA1_HARD_ERROR_REG = 0x00F00120
HOST_AURORA1_CRC_ERROR_REG = 0x00F00124

REMOTE0_AURORA_SOFT_ERROR_REG = REMOTE0_SHELL_COMMON_BASE + 0x00000024
REMOTE0_AURORA_HARD_ERROR_REG = REMOTE0_SHELL_COMMON_BASE + 0x00000028
REMOTE0_AURORA_CRC_ERROR_REG = REMOTE0_SHELL_COMMON_BASE + 0x0000002C
REMOTE0_TEMP_REG = REMOTE0_SHELL_COMMON_BASE + 0x00000030
REMOTE0_VCCINT_REG = REMOTE0_SHELL_COMMON_BASE + 0x00000034
REMOTE0_VCCAUX_REG = REMOTE0_SHELL_COMMON_BASE + 0x00000038
REMOTE0_VCCBRAM_REG = REMOTE0_SHELL_COMMON_BASE + 0x0000003C

REMOTE1_AURORA_SOFT_ERROR_REG = REMOTE1_SHELL_COMMON_BASE + 0x00000024
REMOTE1_AURORA_HARD_ERROR_REG = REMOTE1_SHELL_COMMON_BASE + 0x00000028
REMOTE1_AURORA_CRC_ERROR_REG = REMOTE1_SHELL_COMMON_BASE + 0x0000002C
REMOTE1_TEMP_REG = REMOTE1_SHELL_COMMON_BASE + 0x00000030
REMOTE1_VCCINT_REG = REMOTE1_SHELL_COMMON_BASE + 0x00000034
REMOTE1_VCCAUX_REG = REMOTE1_SHELL_COMMON_BASE + 0x00000038
REMOTE1_VCCBRAM_REG = REMOTE1_SHELL_COMMON_BASE + 0x0000003C

# Alveo-specific status registers (from the CMS)
ALVEO_INIT_REG = HOST_BASE + 0x00F0000C
ALVEO_STATUS_BASE_REG = HOST_SHELL_CMS_BASE + 0x28000
ALVEO_CONTROL_REG = HOST_SHELL_CMS_BASE + 0x28018
ALVEO_HOST_MSG_ERR_REG = HOST_SHELL_CMS_BASE + 0x28304
ALVEO_REG_NAMES = [
    ["VCCINT Average Voltage            ", (ALVEO_STATUS_BASE_REG + 0xE4), "mV"],
    ["VCCINT_I Average Current          ", (ALVEO_STATUS_BASE_REG + 0xF0), "mA"],
    ["FPGA Junction Average Temperature ", (ALVEO_STATUS_BASE_REG + 0xFC), "C"],
    ["CAGE_TEMP0 Average Temperature    ", (ALVEO_STATUS_BASE_REG + 0x174), "C"],
    ["CAGE_TEMP1 Average Temperature    ", (ALVEO_STATUS_BASE_REG + 0x180), "C"],
    ["Ambient FPGA Average Temperature  ", (ALVEO_STATUS_BASE_REG + 0x2D0), "C"],
    ["Ambient Card Average Temperature  ", (ALVEO_STATUS_BASE_REG + 0x144), "C"],
]
ALVEO_CMS_MAILBOX_HEADER_REG = HOST_SHELL_CMS_BASE + 0x29000
ALVEO_CMS_MAILBOX_CAGE_SEL_REG = HOST_SHELL_CMS_BASE + 0x29004
ALVEO_CMS_MAILBOX_PAGE_SEL_REG = HOST_SHELL_CMS_BASE + 0x29008
ALVEO_CMS_MAILBOX_EXTD_I2C_ADDR_REG = HOST_SHELL_CMS_BASE + 0x2900C
ALVEO_CMS_MAILBOX_PAGE_BYTE_OFFSET_REG = HOST_SHELL_CMS_BASE + 0x29010
ALVEO_CMS_MAILBOX_DATA_REG = HOST_SHELL_CMS_BASE + 0x29014

THIS_DIR = Path(__file__).parent.resolve()


def get_device_name(fpga_index):
    if fpga_index == 0:
        address_offset = HOST_SHELL_FLASH_BASE
    elif fpga_index == 1:
        address_offset = REMOTE0_SHELL_FLASH_BASE
    elif fpga_index == 2:
        address_offset = REMOTE1_SHELL_FLASH_BASE
    hal = sondos.SondosHAL()
    dev = hal.iface
    id_0 = dev.read_register(address_offset + 15 * 4)
    id_1 = dev.read_register(address_offset + 14 * 4)
    if (id_0 == 0xFFFFFFFF) or (id_1 == 0xFFFFFFFF):
        print("Error: Flash controller not found at offset", hex(address_offset))
        return
    dev_name = id_0.to_bytes(4, "big").decode() + id_1.to_bytes(4, "big").decode()
    return dev_name


def write_fpga_image(fpga_index, bit_file=None):
    # would add check for supporting different boards later
    if fpga_index == 0:
        address_offset = HOST_SHELL_FLASH_BASE
    elif fpga_index == 1:
        address_offset = REMOTE0_SHELL_FLASH_BASE
    elif fpga_index == 2:
        address_offset = REMOTE1_SHELL_FLASH_BASE

    if bit_file is None:
        print("No bit file provided, please use -bit file argument")
        exit(-1)

    my_flash = flash_programmer.FlashInterface(address_offset, bit_file)
    if not my_flash.iface_valid:
        print("Could not initialize flash interface due to previous errors")
        exit(-1)
    if my_flash.write_flash():
        print("Bitfile Write Passed")
    else:
        print("Bitfile Write Failed")

    if my_flash.test_bitfile():
        print("Bitfile Test Passed")
    else:
        print("Bitfile Test Failed")
    my_flash.disable_buffer()
    pass


def verify_fpga_image(fpga_index, bit_file=None):
    # would add check for supporting different boards later
    if fpga_index == 0:
        address_offset = HOST_SHELL_FLASH_BASE
    elif fpga_index == 1:
        address_offset = REMOTE0_SHELL_FLASH_BASE
    elif fpga_index == 2:
        address_offset = REMOTE1_SHELL_FLASH_BASE

    if bit_file is None:
        print("No bit file provided, please use -bit file argument")
        exit(-1)

    my_flash = flash_programmer.FlashInterface(address_offset, bit_file)
    if not my_flash.iface_valid:
        print("Could not initialize flash interface due to previous errors")
        exit(-1)
    if my_flash.test_bitfile():
        print("Bitfile Verification Passed")
    else:
        print("Bitfile Verification Failed")
    my_flash.disable_buffer()
    pass


# Define a function to reconfigure the device
def reconfig(fpga_index):
    if fpga_index == 0:
        address_offset = HOST_SHELL_FLASH_BASE
    elif fpga_index == 1:
        address_offset = REMOTE0_SHELL_FLASH_BASE
    elif fpga_index == 2:
        address_offset = REMOTE1_SHELL_FLASH_BASE
    hal = sondos.SondosHAL()
    dev = hal.iface
    dev.write_register(address_offset + 12 * 4, 0)
    if dev.read_register(address_offset + 13 * 4) != 0:
        print(
            "Error: Flash controller at offset ",
            hex(address_offset),
            " is already in use by another process!",
        )
        return

    dev.write_register(address_offset, 1 << 16)
    time.sleep(0.1)
    dev.write_register(address_offset, 0x107)
    print("FPGA Reconfiguration Done")
    if fpga_index > 0:  # only able to run on remote devices
        time.sleep(3)  # wait for device to boot
        dev_list()
    pass


def init_htg_status():
    hal = sondos.SondosHAL()
    dev = hal.iface
    status_reg = dev.read_register(SI5341_STATUS_REG0)
    if status_reg & (0x1 << 2):
        print("\nClock generators: Initialization successful.")
    else:
        status_reg = dev.read_register(SI5341_STATUS_REG1)
        print("\nClock generators: Initialization failed.")
        print("Failing Transaction:")
        print(f"\tI2C Data:{hex((status_reg & 0xFF))}")
        print(f"\tDevice Address:{hex((status_reg >> 16) & 0x7F)}")
        print(f"\tACKs Received:{hex((status_reg >> 23) & 0x1F)}")
        print(f"\tNum Bytes Written:{hex((status_reg >> 28) & 0xF)}")

    ff_present = dev.read_register(FF_PRESENT_REG)
    if (ff_present & 0x1) != 0:
        status_reg = dev.read_register(FF0_STATUS_REG)
        if status_reg & (0x1 << 29):
            print("Firefly 0: Present. Initialization successful.")
        else:
            print("Firefly 0: Present. Initialization failed.")
            print("Failing Transaction:")
            print(f"\tI2C Data:{hex(status_reg & 0xFF)}")
            print(f"\tDevice Address:{hex((status_reg >> 16) & 0x7F)}")
            print(f"\tACKs Received:{hex((status_reg >> 23) & 0x1F)}")
    else:
        print("Firefly 0 not present.")

    if (ff_present & 0x2) != 0:
        status_reg = dev.read_register(FF1_STATUS_REG)
        if status_reg & (0x1 << 29):
            print("Firefly 1: Present. Initialization successful.\n")
        else:
            print("Firefly 1: Present. Initialization failed.")
            print("Failing Transaction:")
            print(f"\tI2C Data:{hex(status_reg & 0xFF)}")
            print(f"\tDevice Address:{hex((status_reg >> 16) & 0x7F)}")
            print(f"\tACKs Received:{hex((status_reg >> 23) & 0x1F)}")
    else:
        print("Firefly 1: Not present.\n")


def report_aurora_status(interface, dev):
    print(f"Fiber Link {interface}: Present")
    print("-------------------------------------------")
    status_reg = dev.read_register(HOST_AURORA0_SOFT_ERROR_REG)
    print(f"Host Aurora {interface} soft error count: {status_reg}")
    status_reg = dev.read_register(HOST_AURORA0_HARD_ERROR_REG)
    print(f"Host Aurora {interface} hard error count: {status_reg}")
    status_reg = dev.read_register(HOST_AURORA0_CRC_ERROR_REG)
    print(f"Host Aurora {interface} crc error count: {status_reg}\n")

    remote_soft_error = []
    remote_hard_error = []
    remote_crc_error = []

    if interface == 0:
        address_soft_error = REMOTE0_AURORA_SOFT_ERROR_REG
        address_hard_error = REMOTE0_AURORA_HARD_ERROR_REG
        address_crc_error = REMOTE0_AURORA_CRC_ERROR_REG
    else:
        address_soft_error = REMOTE1_AURORA_SOFT_ERROR_REG
        address_hard_error = REMOTE1_AURORA_HARD_ERROR_REG
        address_crc_error = REMOTE1_AURORA_CRC_ERROR_REG

    for _ in range(0, 3):
        remote_soft_error.append(dev.read_register(address_soft_error))
        remote_hard_error.append(dev.read_register(address_hard_error))
        remote_crc_error.append(dev.read_register(address_crc_error))

    diff_flag = False
    for i in range(1, 3):
        if remote_soft_error[i] != remote_soft_error[0]:
            diff_flag = True
        if remote_hard_error[i] != remote_hard_error[0]:
            diff_flag = True
        if remote_crc_error[i] != remote_crc_error[0]:
            diff_flag = True

    if diff_flag is False:
        print(f"Remote {interface} Aurora soft error count: {remote_soft_error[0]}")
        print(f"Remote {interface} Aurora hard error count: {remote_hard_error[0]}")
        print(f"Remote {interface} Aurora crc error count: {remote_crc_error[0]}")
    else:
        print("\nDiffering values returned by remote!")
        for i in range(0, 3):
            print(f"Read {i + 1}:")
            print(f"Remote {interface} Aurora soft error count: {remote_soft_error[i]}")
            print(f"Remote {interface} Aurora hard error count: {remote_hard_error[i]}")
            print(f"Remote {interface} Aurora crc error count: {remote_crc_error[i]}")


def read_aurora_status():
    hal = sondos.SondosHAL()
    dev = hal.iface
    remote_0_id = dev.read_register(REMOTE0_SHELL_COMMON_BASE)
    if remote_0_id == 0x50D058E1:
        report_aurora_status(0, dev)

    if get_device_name(0) == "HTG_930" or get_device_name(0) == "VCU_118":
        remote_1_id = dev.read_register(REMOTE1_SHELL_COMMON_BASE)
        if remote_1_id == 0x50D058E1:
            report_aurora_status(1, dev)


def init_alveo():
    hal = sondos.SondosHAL()
    dev = hal.iface
    dev.write_register(ALVEO_INIT_REG, 0x4)
    print("Alveo Initialization Started")
    time.sleep(1)
    id_check = dev.read_register(ALVEO_STATUS_BASE_REG)
    if id_check != 0x74736574:
        print("Alveo Initialization Failed")
        return
    else:
        print("Alveo Initialization Complete!\n")
    dev_list()
    pass


def alveo_status():
    hal = sondos.SondosHAL()
    dev = hal.iface
    id_check = dev.read_register(ALVEO_STATUS_BASE_REG)
    if id_check != 0x74736574:
        print("Alveo Status Registers: Not Present")
        return
    print("Alveo Status Registers:")
    for reg_name, reg_addr, reg_unit in ALVEO_REG_NAMES:
        reg_value = dev.read_register(reg_addr)
        print(f"{reg_name}: {reg_value} {reg_unit}")
    # print(f"QSFP0 Temperature: {int(read_alveo_qsfp_temp(0))} C")
    print(f"QSFP1 Temperature: {int(read_alveo_qsfp_temp(1))} C")


# Reading the QSFP temperature reqires reading a 16-bit value from the QSFP module.
# The value has to be read in a burst transaction, per the SFF-8636 standard. The burst
# queries all registers in lower page 0. We only read the desired value from the CMS IP.
def read_alveo_qsfp_temp(cage):
    hal = sondos.SondosHAL()
    dev = hal.iface
    # Check that mailbox is idle
    while (dev.read_register(ALVEO_CONTROL_REG) & 0x0000_0010) > 0:
        pass
    # Opcode BLOCK_READ
    dev.write_register(ALVEO_CMS_MAILBOX_HEADER_REG, 0x0B000000)
    # Cage number
    dev.write_register(ALVEO_CMS_MAILBOX_CAGE_SEL_REG, cage)
    # Page 0
    dev.write_register(ALVEO_CMS_MAILBOX_PAGE_SEL_REG, 0x0000_0000)
    # Lower half of the page
    dev.write_register(ALVEO_CMS_MAILBOX_EXTD_I2C_ADDR_REG, 0x0000_0000)
    # Indicate a new request message is available and clear any ERROR_REG flags
    dev.write_register(ALVEO_CONTROL_REG, 0x0000_0022)
    # Wait for the response
    while dev.read_register(ALVEO_CONTROL_REG) > 0:
        pass
    # Check for error
    if dev.read_register(ALVEO_HOST_MSG_ERR_REG) > 0:
        print(
            f"ERROR: Cage {cage} Host message error: {hex(dev.read_register(ALVEO_HOST_MSG_ERR_REG))}"
        )
        return 0
    # Get number of bytes to read
    # response_length = dev.read_register(ALVEO_CMS_MAILBOX_PAGE_BYTE_OFFSET_REG)
    # Read the response for the temperature. Data is in the upper 16 bits of the 32-bit word
    # Most significant byte is bits 16-23
    response = dev.read_register(ALVEO_CMS_MAILBOX_DATA_REG + 4 * 5)
    # Read the response for the temperature. Data is in the upper 16 bits of the 32-bit word
    # Most significant byte is bits 16-23
    temp_msb = (response >> 16) & 0xFF
    # Least significant byte is bits 24-31
    temp_lsb = (response >> 24) & 0xFF
    # Combine the two bytes
    temp = (temp_msb << 8) + temp_lsb
    # Convert to Degrees Celsius
    temp_c = temp / 256
    return temp_c


def init_firefly_module(ff_reg_address):
    ff0_i2c = sondos_i2c.SondosI2C(ff_reg_address)
    ff0_i2c.write_i2c_A8D8(0x50, 127, 0)
    ff0_i2c.write_i2c_A8D8(0x50, 98, 0)
    ff0_i2c.write_i2c_A8D8(0x50, 127, 3)
    ff0_i2c.write_i2c_A8D8(0x50, 234, 0x66)
    ff0_i2c.write_i2c_A8D8(0x50, 235, 0x66)


def init_htg():
    hal = sondos.SondosHAL()
    dev = hal.iface
    ver_reg = dev.read_register(TEMP_I2C_VER_REG)
    if ver_reg != 0x12C012C0:
        print("unexpected version register value, please update HTG image")
        return
    dev.write_register(CONFIG_RESET_REG, 0x2A3)
    ff_present = dev.read_register(FF_PRESENT_REG)
    if (ff_present & 0x1) != 0:
        print("Configuring FireFly 0 module")
        init_firefly_module(FF0_I2C_BASE_REG)

    if (ff_present & 0x2) != 0:
        print("Configuring FireFly 1 module")
        init_firefly_module(FF1_I2C_BASE_REG)

    htg_main_i2c = sondos_i2c.SondosI2C(MAIN_I2C_BASE_REG)
    htg_main_i2c.write_i2c_D8(0x70, 2)
    print("Configuring Si5341 Clock Generators")
    with open(THIS_DIR / "Si5341_HTG_config.json") as f:
        data = json.load(f)

    # write preamble config for both clock generators
    for reg_address, reg_value in data["preamble"].items():
        address = int(reg_address, 0)
        value = int(reg_value, 0)
        address_msb = address >> 8
        address_lsb = address & 0xFF
        htg_main_i2c.write_i2c_A8D8(0x75, 0x1, address_msb)
        htg_main_i2c.write_i2c_A8D8(0x75, address_lsb, value)
        htg_main_i2c.write_i2c_A8D8(0x74, 0x1, address_msb)
        htg_main_i2c.write_i2c_A8D8(0x74, address_lsb, value)

    time.sleep(0.4)
    # write clock generator 0 configuration
    for reg_address, reg_value in data["U24_configuration"].items():
        address = int(reg_address, 0)
        value = int(reg_value, 0)
        address_msb = address >> 8
        address_lsb = address & 0xFF
        htg_main_i2c.write_i2c_A8D8(0x75, 0x1, address_msb)
        htg_main_i2c.write_i2c_A8D8(0x75, address_lsb, value)

    # write postable for clock generator 0
    for reg_address, reg_value in data["postamble"].items():
        address = int(reg_address, 0)
        value = int(reg_value, 0)
        address_msb = address >> 8
        address_lsb = address & 0xFF
        htg_main_i2c.write_i2c_A8D8(0x75, 0x1, address_msb)
        htg_main_i2c.write_i2c_A8D8(0x75, address_lsb, value, False)

    # write clock generator 1 configuration
    for reg_address, reg_value in data["U41_configuration"].items():
        address = int(reg_address, 0)
        value = int(reg_value, 0)
        address_msb = address >> 8
        address_lsb = address & 0xFF
        htg_main_i2c.write_i2c_A8D8(0x74, 0x1, address_msb)
        htg_main_i2c.write_i2c_A8D8(0x74, address_lsb, value)

    # write postable for clock generator 1
    for reg_address, reg_value in data["postamble"].items():
        address = int(reg_address, 0)
        value = int(reg_value, 0)
        address_msb = address >> 8
        address_lsb = address & 0xFF
        htg_main_i2c.write_i2c_A8D8(0x74, 0x1, address_msb)
        htg_main_i2c.write_i2c_A8D8(0x74, address_lsb, value, False)

    time.sleep(0.1)
    dev.write_register(CONFIG_RESET_REG, 0x2A2)
    print("Initialization Done\n")
    time.sleep(1)  # wait for clock generators to settle
    dev_list()
    pass


# Define a function to read from a register
def read_reg(address, size, mode):
    hal = sondos.SondosHAL()
    dev = hal.iface
    # Check for Sondos protocol version mismatch
    host_ver = dev.read_register(HOST_SHELL_COMMON_BASE + (62 * 4))
    if (address * 4 >= REMOTE0_BASE) and (address * 4 < REMOTE1_BASE):
        remote_ver = dev.read_register(REMOTE0_SHELL_COMMON_BASE + (62 * 4))
        if (remote_ver >> 24) != (host_ver >> 24):
            dev_list()
            return
    elif address * 4 >= REMOTE1_BASE:
        remote_ver = dev.read_register(REMOTE1_SHELL_COMMON_BASE + (62 * 4))
        if (remote_ver >> 24) != (host_ver >> 24):
            dev_list()
            return
    print("Address hex (decimal) : Value hex (decimal)")
    for i in range(0, size):
        current_address = address + i
        reg_value = dev.read_register(current_address * 4)
        print(
            hex(current_address),
            "(",
            current_address,
            ") : ",
            hex(reg_value),
            "(",
            reg_value,
            ")",
        )
    pass


# Define a function to write to a register
def write_reg(address, data, mode):
    hal = sondos.SondosHAL()
    dev = hal.iface
    # Check for Sondos protocol version mismatch
    host_ver = dev.read_register(HOST_SHELL_COMMON_BASE + (62 * 4))
    if (address * 4 >= REMOTE0_BASE) and (address * 4 < REMOTE1_BASE):
        remote_ver = dev.read_register(REMOTE0_SHELL_COMMON_BASE + (62 * 4))
        if (remote_ver >> 24) != (host_ver >> 24):
            dev_list()
            return
    elif address * 4 >= REMOTE1_BASE:
        remote_ver = dev.read_register(REMOTE1_SHELL_COMMON_BASE + (62 * 4))
        if (remote_ver >> 24) != (host_ver >> 24):
            dev_list()
            return
    dev.write_register(address * 4, data)
    pass


# Define a function to list the available devices
def dev_list():
    host_ver_reg = HOST_SHELL_COMMON_BASE + (62 * 4)
    remote0_ver_reg = REMOTE0_SHELL_COMMON_BASE + (62 * 4)
    remote1_ver_reg = REMOTE1_SHELL_COMMON_BASE + (62 * 4)
    hal = sondos.SondosHAL()
    dev = hal.iface
    print("Detected Devices:")
    host_name = get_device_name(0)
    print("Host Name:      ", host_name)
    host_id = dev.read_register(HOST_SHELL_COMMON_BASE)
    if host_id != 0x50D058E1:
        print("Host Version:    NOT RESPONDING")
    host_ver = dev.read_register(host_ver_reg)
    print(
        "Host Version:    Protocol ",
        host_ver >> 24,
        ", Software (",
        (host_ver >> 16) & 0xFF,
        ".",
        (host_ver >> 8) & 0xFF,
        ".",
        host_ver & 0xFF,
        ")",
        sep="",
    )
    if host_name == "ALV_U250":
        return
    remote0_name = get_device_name(1)
    print("Remote0 Name:   ", remote0_name)
    remote_0_id = dev.read_register(REMOTE0_SHELL_COMMON_BASE)
    if remote_0_id != 0x50D058E1:
        print("Remote0 Version: NOT RESPONDING")
    else:
        remote0_ver = dev.read_register(remote0_ver_reg)
        print(
            "Remote0 Version: Protocol ",
            remote0_ver >> 24,
            ", Software (",
            (remote0_ver >> 16) & 0xFF,
            ".",
            (remote0_ver >> 8) & 0xFF,
            ".",
            remote0_ver & 0xFF,
            ")",
            sep="",
        )
        if remote0_name != "VCK_190 ":
            remote0_temp = dev.read_register(REMOTE0_TEMP_REG)
            # Convert using Equation 2-11 in Xilinx UG580
            remote0_temp = ((remote0_temp * 509.3140064) / 2**10) - 280.23087870
            print(f"Remote0 Temp:   {remote0_temp:.2f} C")
            remote0_vccint = dev.read_register(REMOTE0_VCCINT_REG)
            # Convert using Equation 2-13 in Xilinx UG580
            remote0_vccint = (remote0_vccint / 1024) * 3
            print(f"Remote0 VCCint: {remote0_vccint:.2f} V")
            remote0_vccaux = dev.read_register(REMOTE0_VCCAUX_REG)
            # Convert using Equation 2-13 in Xilinx UG580
            remote0_vccaux = (remote0_vccaux / 1024) * 3
            print(f"Remote0 VCCaux: {remote0_vccaux:.2f} V")
            remote0_vccbram = dev.read_register(REMOTE0_VCCBRAM_REG)
            # Convert using Equation 2-13 in Xilinx UG580
            remote0_vccbram = (remote0_vccbram / 1024) * 3
            print(f"Remote0 VCCbram:  {remote0_vccbram:.2f} V")
        else:
            print("Remote0 Temp:    N/A (VCK190 - no SYSMON in shell)")
        if (remote0_ver >> 24) != (host_ver >> 24):
            print("ERROR: Remote0 and Host protocol versions do not match!")
            return
    if host_name != "HTG_930":
        print("Remote1 Name:    Not Supported")
        return
    remote1_name = get_device_name(2)
    print("Remote1 Name:   ", remote1_name)
    remote_1_id = dev.read_register(REMOTE1_SHELL_COMMON_BASE)
    if remote_1_id != 0x50D058E1:
        print("Remote1 Version: NOT RESPONDING")
    else:
        remote1_ver = dev.read_register(remote1_ver_reg)
        print(
            "Remote1 Version: Protocol ",
            remote1_ver >> 24,
            ", Software (",
            (remote1_ver >> 16) & 0xFF,
            ".",
            (remote1_ver >> 8) & 0xFF,
            ".",
            remote1_ver & 0xFF,
            ")",
            sep="",
        )
        remote1_temp = dev.read_register(REMOTE1_TEMP_REG)
        # Convert using Equation 2-11 in Xilinx UG580
        remote1_temp = ((remote1_temp * 509.3140064) / 2**10) - 280.23087870
        print(f"Remote1 Temp:   {remote1_temp:.2f} C")
        remote1_vccint = dev.read_register(REMOTE1_VCCINT_REG)
        # Convert using Equation 2-13 in Xilinx UG580
        remote1_vccint = (remote1_vccint / 1024) * 3
        print(f"Remote1 Vccint: {remote1_vccint:.2f} V")
        remote1_vccaux = dev.read_register(REMOTE1_VCCAUX_REG)
        # Convert using Equation 2-13 in Xilinx UG580
        remote1_vccaux = (remote1_vccaux / 1024) * 3
        print(f"Remote1 Vccaux: {remote1_vccaux:.2f} V")
        remote1_vccbram = dev.read_register(REMOTE1_VCCBRAM_REG)
        # Convert using Equation 2-13 in Xilinx UG580
        remote1_vccbram = (remote1_vccbram / 1024) * 3
        print(f"Remote1 VCCbram:  {remote1_vccbram:.2f} V")
        if (remote1_ver >> 24) != (host_ver >> 24):
            print("ERROR: Remote1 and Host protocol versions do not match!")
            return
    pass


# Create an argument parser object
parser = argparse.ArgumentParser(
    description="Sondos management program",
    formatter_class=argparse.RawTextHelpFormatter,
)

# Add mutually exclusive arguments for different functionalities
group = parser.add_mutually_exclusive_group(required=True)
group.add_argument(
    "-write_fpga_image",
    action="store_true",
    help="write to QSPI flash memory\nexample 1: python sondos_mgmt.py -write_fpga_image -host -bit file_name.bit \nexample 2: python sondos_mgmt.py -write_fpga_image -remote0 -bit file_name.bit",
)
group.add_argument(
    "-verify_fpga_image",
    action="store_true",
    help="compare QSPI flash memory to a bitfile\nexample 1: python sondos_mgmt.py -verify_fpga_image -host -bit file_name.bit \nexample 2: python sondos_mgmt.py -verify_fpga_image -remote0 -bit file_name.bit",
)
group.add_argument(
    "-reconfig",
    action="store_true",
    help="reconfigure the device\nexample 1: python sondos_mgmt.py -reconfig -host \nexample 2: python sondos_mgmt.py -reconfig -remote0",
)
group.add_argument(
    "-init_htg",
    action="store_true",
    help="initialize HTG930 clock generators and firefly\nexample: python sondos_mgmt.py -init_htg",
)
group.add_argument(
    "-init_htg_status",
    action="store_true",
    help="Read the status of the automatic initialization of the htg930 clock chips and firefly modules\nnexample: python sondos_mgmt.py -init_htg_status",
)
group.add_argument(
    "-read_aurora_status",
    action="store_true",
    help="Read the soft error, hard error, and crc counters from the aurora modules\nexample: python sondos_mgmt.py -read_aurora_status",
)
group.add_argument(
    "-init_alveo",
    action="store_true",
    help="initialize Alveo QSFP cards\nexample: python sondos_mgmt.py -init_alveo",
)
group.add_argument(
    "-alveo_status",
    action="store_true",
    help="Read the temp/current/voltage status registers available on the Alveo host FPGA\nexample: python sondos_mgmt.py -alveo_status",
)
group.add_argument(
    "-read_reg",
    action="store_true",
    help="read from a register\nexample: python sondos_mgmt.py -read_reg [-mode user | -mode shell] -a address -l size",
)
group.add_argument(
    "-write_reg",
    action="store_true",
    help="write to a register\nexample: python sondos_mgmt.py -write_reg [-mode user | -shell]  -a address -d data",
)
group.add_argument(
    "-dev_list",
    action="store_true",
    help="list the available devices\nexample: python sondos_mgmt.py -dev_list",
)

# Add optional arguments for device name and file names
parser.add_argument("-dev", type=str, help="device name")
parser.add_argument("-bit", type=str, help="bit file name")

prog_group = parser.add_mutually_exclusive_group(required=False)
prog_group.add_argument(
    "-host", "--host_fpga", action="store_true", help="write to host fpga"
)
prog_group.add_argument(
    "-remote0", "--remote0_fpga", action="store_true", help="write to remote0 fpga"
)
prog_group.add_argument(
    "-remote1", "--remote1_fpga", action="store_true", help="write to remote1 fpga"
)

# Add a new optional argument for read and write mode
parser.add_argument(
    "-mode",
    type=str,
    choices=["user", "shell"],
    default="user",
    nargs="?",
    help="read or write mode",
)

# Add optional arguments for register address and data with int or hex format
parser.add_argument(
    "-a", type=lambda x: int(x, 0), help="register address (int or hex)"
)
parser.add_argument("-l", type=int, help="number of registers to read")
parser.add_argument("-d", type=lambda x: int(x, 0), help="register data (int or hex)")

# Parse the command-line arguments
args = parser.parse_args()
fpga_index = -1
if args.host_fpga:
    fpga_index = 0
elif args.remote0_fpga:
    fpga_index = 1
elif args.remote1_fpga:
    fpga_index = 2

if (fpga_index < 0) and (
    args.write_fpga_image or args.verify_fpga_image or args.reconfig
):
    print("Please select valid a FPGA ex: -host or -remote0 or -remote1")

# Call the appropriate function based on the arguments
if args.write_fpga_image:
    write_fpga_image(fpga_index=fpga_index, bit_file=args.bit)

elif args.reconfig:
    reconfig(fpga_index=fpga_index)

elif args.verify_fpga_image:
    verify_fpga_image(fpga_index=fpga_index, bit_file=args.bit)
elif args.init_htg:
    init_htg()
elif args.init_htg_status:
    init_htg_status()
elif args.read_aurora_status:
    read_aurora_status()
elif args.init_alveo:
    init_alveo()
elif args.alveo_status:
    alveo_status()
elif args.read_reg:
    if (args.l is None) or (args.l < 1):
        read_length = 1
    else:
        read_length = args.l

    if args.a is not None:
        read_reg(args.a, read_length, args.mode)
    else:
        print("Must pass address argument when using read_reg")
elif args.write_reg:
    if (args.a is not None) and (args.d is not None):
        write_reg(args.a, args.d, args.mode)
    else:
        print("Must pass address and data arguments when using write_reg")
elif args.dev_list:
    dev_list()
else:
    print("Unknown functionality")
