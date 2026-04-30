<!-- SPDX-License-Identifier: MIT -->
<!-- (c) Meta Platforms, Inc. and affiliates. -->

# Sondos Shell

The Sondos Shell is the per-board FPGA platform layer: it owns PCIe / DDR /
clocks / GPIO / flash bring-up, exposes a clean AXI4 / AXI4-Lite /
AXI4-Stream user interface, and lets user logic target multiple AMD/Xilinx
boards with minimal portability work.

## Layout

```
shell/
├── common/                       Shared across all boards
│   ├── interfaces/               AXI4 / AXI4-Lite / AXI4-Stream packages
│   │                             (so_axi4_if, so_axi4l_if, so_axi4s_if)
│   ├── modules/                  Shared shell RTL (sondos_axi4l_crossbar,
│   │                             sondos_axi_crossbar_wrapper, packetized_axi4*,
│   │                             aurora_firefly_0_wrapper, sysmon_wrapper, ...)
│   └── phy/                      Per-PHY xci recipes (aurora, qdma, cms_subsystem)
├── alveo_u250/                   U250 PCIe host shell
├── alveo_u45n/                   U45N PCIe host shell + alveo-CMS, FireFly,
│                                 QSFP-init modules (board-specific)
├── htg930_host/                  HTG-930 PCIe host shell + aurora_firefly_1_wrapper
├── htg930_remote/                HTG-930 C2C remote shell
├── vcu118_host/                  VCU118 PCIe host shell
├── vcu118_remote/                VCU118 C2C remote shell
├── flash_programmers/            Bitstreams + scripts to program board flash
├── xilinx_ip_gen/                Reproducible Xilinx IP generation TCLs
└── sw/                           Generic Sondos-shell management Python utilities
                                  (sondos_mgmt, sondos_i2c, flash_programmer)
```

## Adding a new board

See [`docs/supported_boards.md`](../docs/supported_boards.md) for the
recommended pattern (start from the closest existing board's directory,
swap the part number / pin map / IP recipes, wire the user interface).
