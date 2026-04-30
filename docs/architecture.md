<!-- SPDX-License-Identifier: MIT -->
<!-- (c) Meta Platforms, Inc. and affiliates. -->

# Sondos FPGA — Architecture

Sondos is built around a clean separation between a board-specific **shell**
and board-agnostic **library** modules.

```
+--------------------------------------------------------------------+
|                          Sondos Library (lib/)                     |
|                                                                    |
|   - lib/rtl/modules/        re-usable RTL                          |
|   - lib/rtl/interfaces/     SO_AXI4* / SO_AXI4S* interface decls   |
|   - lib/examples/           end-to-end demos (streamer_demo)       |
|                                                                    |
+----+-----------+-----------+-----------+--------+------------------+
     |           |           |           |        |
   AXI4-Lite   AXI4         AXI4-Stream  user_io  ...
     |           |           |           |
+----v-----------v-----------v-----------v---------------------------+
|                          Sondos Shell (shell/)                     |
|                                                                    |
|  PCIe IP / DDR / clocks / GPIO / flash / per-board bring-up        |
|  shell/{alveo,htg930_*,vcu118_*}/                                  |
|                                                                    |
+--------------------------------------------------------------------+
                          ^                       ^
                          |                       |
                          v                       v
                    Xilinx IPs            external pins/devices
                  shell/xilinx_ip_gen     (PHYs, flash, LEDs, ...)
```

## Stable interfaces (`shell/common/interfaces/`)

Sondos defines a small set of strongly-typed SystemVerilog interfaces that
form the contract between shell and user logic:

- `so_axi4_if`       — full AXI4 (memory-mapped, with bursts)
- `so_axi4l_if`      — AXI4-Lite (CSR/control plane)
- `so_axi4s_if`      — AXI4-Stream (data plane)
- `user_io_if`       — board-agnostic GPIO / LED tap

User modules instantiate these interfaces parameterized by width-config
constants (e.g., `C_SO_AXI4S_D512`) defined in the matching `*_if_pkg`.

## AXI4-Stream width

The v0.1 release fixes AXI4-Stream user-side width at **512 bits** for all
supported boards. Resize / arbitration adapters are not included; if you
need width conversion, instantiate it in your own user logic.

## Streamer demo data path

The reference example (`lib/streamer_demo/`) is a permanent
host-to-card → card-to-host loopback. Useful for bringing up PCIe DMA on
a new board and as a starting point for your own streaming user logic.

```
host PCIe ---> shell ---> axi_stream_h2c ---> user_top ---> axi_stream_c2h ---> shell ---> host PCIe
                                              (loopback)
```

## Adding a new board

See [`docs/build_guide.md`](build_guide.md) for the full procedure. Short
version: copy an existing per-board shell directory, retarget the part /
constraints / clock files, and instantiate the existing user-facing
interfaces.
