<!-- SPDX-License-Identifier: MIT -->
<!-- (c) Meta Platforms, Inc. and affiliates. -->

# Sondos Library

The Sondos Library is a collection of reusable RTL building blocks and
end-to-end example designs that consume the [Sondos Shell](../shell/).

## Layout

```
lib/
├── rtl/                          Reusable user-facing RTL modules
│   ├── ingress_axi_streamer.sv
│   ├── egress_axi_streamer.sv
│   ├── page_translation_stage_read.sv
│   └── page_translation_stage_write.sv
└── streamer_demo/                End-to-end FPGA + host SW streamer demo
    ├── common/                   Shared user-side RTL (loopback top, regs, IO)
    ├── alveo_u250_host/          { project_top.sv, .xdc, build.tcl }
    ├── alveo_u45n_host/          { project_top.sv, .xdc, build.tcl }
    ├── htg930_host/              { project_top.sv, .xdc, build.tcl }
    ├── htg930_remote/            { project_top.sv, .xdc, build.tcl }
    ├── vcu118_host/              { project_top.sv, .xdc, build.tcl }
    ├── vcu118_remote/            { project_top.sv, .xdc, build.tcl }
    └── sw/                       Demo-specific host-side software
        ├── py/                   Python streamer demo + perf test
        └── cpp/                  C++ streamer demo (CMake build, raw GenTL C API)
```

> Generic Sondos-shell management utilities (`sondos_mgmt.py`, `sondos_i2c.py`,
> `flash_programmer.py`) live under [`../shell/sw/`](../shell/sw/), not here
> — they work against any board running the Shell, not just this demo.

## Streamer demo

A permanent host ↔ FPGA AXI4-Stream loopback that exercises the page-table
DMA path. The bitstream pipes the PCIe host->card stream straight back as
the card->host stream; the included Python and C++ host SW measures
throughput, latency, and correctness.

See [`docs/build_guide.md`](../docs/build_guide.md) for build commands.
