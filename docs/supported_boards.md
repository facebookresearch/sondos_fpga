<!-- SPDX-License-Identifier: MIT -->
<!-- (c) Meta Platforms, Inc. and affiliates. -->

# Supported Boards

| Friendly name        | Part                | Role   | Shell dir                     | Status   | Notes |
|----------------------|---------------------|--------|-------------------------------|----------|-------|
| Alveo U250 host      | xcu250-figd2104-2L-e| host   | `shell/alveo/u250/`           | shipping | PCIe Gen3 x16 |
| Alveo U45N host      | xcu26-vsva1365-2LV-e| host   | `shell/alveo/u45n/`           | shipping | PCIe Gen4 SmartNIC |
| HTG-930 host         | xcvu13p-fhgb2104-2L-e| host  | `shell/htg930_host/`          | shipping | HiTech Global HTG-930 |
| HTG-930 remote       | xcvu13p-fhgb2104-2L-e| remote| `shell/htg930_remote/`        | shipping | C2C link |
| VCU118 host          | xcvu9p-flga2104-2L-e | host  | `shell/vcu118_host/`          | shipping | PCIe Gen3 |
| VCU118 remote        | xcvu9p-flga2104-2L-e | remote| `shell/vcu118_remote/`        | shipping | C2C link |

## Vivado version

**Vivado 2022 or later** is recommended. The OSS reference shell + library
are written in standard SystemVerilog and use only baseline AMD/Xilinx IP
(XPM macros, AXI Crossbar IP, QDMA, Aurora, etc.), so most Vivado versions
from 2022.x onward should work. Earlier versions (2021.x and below) are
likely fine for the SystemVerilog but may need `update_ip_catalog` runs
for some IP cores.

The reference build that the maintainers smoke-test today is **Vivado 2023.2**.

## Adding a new board

The recommended pattern:
1. Copy one of the existing per-board shell directories that targets a
   similar device family.
2. Retarget the part number, generate new IP under `shell/xilinx_ip_gen/`,
   and update constraints (`*.xdc`).
3. Reuse the existing AXI interface instances and the user-facing
   `user_io_if` modport from `shell/common/`.
4. Add a `build_<demo>_<board>.tcl` under your example directory.
