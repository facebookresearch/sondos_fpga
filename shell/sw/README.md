<!-- SPDX-License-Identifier: MIT -->
<!-- (c) Meta Platforms, Inc. and affiliates. -->

# Sondos Shell — Host SW utilities

Generic host-side Python utilities for managing any FPGA running the
Sondos Shell. These work against any board (host or remote) with no demo
specificity — they target the shell's CSR map, flash controller, and I2C
interfaces directly.

## What ships here

| File                  | Purpose |
|-----------------------|---------|
| `sondos_mgmt.py`      | Top-level CLI: read/write registers, write/verify/reconfig FPGA flash bitstream, init Aurora / Alveo CMS / HTG930 board init. Supports `-host`, `-remote0`, `-remote1` target selectors. |
| `flash_programmer.py` | Library used by `sondos_mgmt.py` to drive the on-shell flash controller (Alveo QSPI / HTG930 BPI / VCU118 QSPI). |
| `sondos_i2c.py`       | I2C master library used by `sondos_mgmt.py` for board init (Si5341, FireFly, etc.). |

## Quickstart

```bash
# List all available device targets the Sondos library can see
python sondos_mgmt.py -list

# Write a bitfile to the host FPGA's flash and verify
python sondos_mgmt.py -write_fpga_image -host -bit my_design.bit
python sondos_mgmt.py -verify_fpga_image -host -bit my_design.bit

# Reconfigure the host FPGA from flash without a power cycle
python sondos_mgmt.py -reconfig -host

# Read a single shell register
python sondos_mgmt.py -read_reg -host -addr 0x00F00044 -size 4
```

Run `python sondos_mgmt.py --help` for the full flag list.

## Dependencies

Requires the [Sondos library](https://github.com/facebookresearch/sondos)
Python bindings to be importable as `sondos.sondos`. On Windows the
standard install location is `C:\Program Files\Sondos\sw\`. Add to
`PYTHONPATH` if not already there.
