<!-- SPDX-License-Identifier: MIT -->
<!-- (c) Meta Platforms, Inc. and affiliates. -->

# sondos_fpga

**Sondos** is an open-source FPGA shell + library for AMD/Xilinx-based
host and remote FPGA platforms. It provides:

- A drop-in **shell** that brings up the platform (PCIe, DDR, clocks, GPIO,
  flash) on supported boards and exposes a clean AXI4 / AXI4-Lite / AXI4-Stream
  user interface.
- A **library** of common RTL building blocks and a streamer demo example.
- Stable AXI4-* interface packages so user logic can target multiple boards
  with minimal changes.

## Supported boards (v0.1)

| Board             | Variant | Role             | Status |
|-------------------|---------|------------------|--------|
| AMD Alveo U250    | host    | PCIe host        | shipping |
| AMD Alveo U45N    | host    | PCIe host        | shipping |
| HiTech Global HTG-930 | host  | PCIe host        | shipping |
| HiTech Global HTG-930 | remote| C2C remote       | shipping |
| AMD VCU118        | host    | PCIe host        | shipping |
| AMD VCU118        | remote  | C2C remote       | shipping |

See [`docs/supported_boards.md`](docs/supported_boards.md) for the full table
including FPGA part numbers and known limitations.

## Quickstart

```bash
# 1. Clone
git clone https://github.com/facebookresearch/sondos_fpga.git
cd sondos_fpga

# 2. Point at your local Vivado install + load env vars
export VIVADO_DIR=/opt/Xilinx/Vivado/2023.2     # adjust to your version
source scripts/setup.sh                          # exports SONDOS_PATH + VIVADO_DIR
```

### Build the FPGA bitstream

```bash
./scripts/build_demo.sh htg930_host
```

Swap `htg930_host` for any other supported board (`alveo_u250_host`,
`alveo_u45n_host`, `htg930_remote`, `vcu118_host`, `vcu118_remote`).
Windows users: `.\scriptsuild_demo.ps1 htg930_host`.

### Build the host C++ streamer demo

```bash
cd lib/streamer_demo/sw/cpp
cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -S . -B build
cmake --build build --target sondos_streaming_demo --config Release
```

Produces `build/sondos_streaming_demo` (or `.exe` on Windows). Requires a
C++20 compiler (MSVC 2022 / g++ 10+ / clang++ 14+) and the Sondos library
install (`/opt/sondos` on Linux, `C:\Program Files\Sondos` on Windows).

Full build documentation — including all per-board recipes, the Linux
memlock setup, and CLI flags — is in [`docs/build_guide.md`](docs/build_guide.md).

## Repository layout

```
sondos_fpga/
├── shell/                   Sondos Shell (per-board platform bring-up)
│   ├── common/              shared modules, interfaces (AXI4 / AXI4L / AXI4S)
│   ├── alveo/              Alveo U250, U45N
│   ├── htg930_host/        HTG-930 host
│   ├── htg930_remote/      HTG-930 remote (C2C)
│   ├── vcu118_host/        VCU118 host
│   ├── vcu118_remote/      VCU118 remote (C2C)
│   ├── sw/                 Generic shell management utilities
│   │                        (sondos_mgmt.py, sondos_i2c.py, flash_programmer.py)
│   ├── flash_programmers/  Flash bring-up bitstreams + TCLs
│   └── xilinx_ip_gen/      Xilinx IP generation TCL recipes
├── lib/                     Sondos Library
│   ├── rtl/                 reusable RTL modules (streamers + page-translation)
│   └── streamer_demo/       end-to-end streamer demo (multi-board) +
│                            host SW (Python + C++ via CMake)
├── scripts/
│   ├── setup.sh             POSIX env setup (Linux/WSL)
│   ├── setup.ps1            Windows PowerShell env setup
│   ├── build_demo.sh        Generic FPGA build dispatcher (Linux)
│   └── build_demo.ps1       Generic FPGA build dispatcher (Windows)
├── docs/
│   ├── architecture.md      Block diagram + interface contracts
│   ├── build_guide.md       Per-board build + host SW build + run
│   └── supported_boards.md  Board table + adding a new board
├── .github/workflows/       CI (SPDX-header presence check)
├── README.md
├── LICENSE                  MIT license text
├── CONTRIBUTING.md          Contribution guide + CLA pointer
├── CODE_OF_CONDUCT.md       Meta open-source CoC
└── SECURITY.md              Security reporting policy
```

## Architecture

See [`docs/architecture.md`](docs/architecture.md).

## License

MIT — see [`LICENSE`](LICENSE).

## Contributing

We welcome contributions. See [`CONTRIBUTING.md`](CONTRIBUTING.md) and the
project's CLA.

## Security

To report security issues, see [`SECURITY.md`](SECURITY.md).

## Citing this work

If you use `sondos_fpga` in academic work, please cite it. A
machine-readable [`CITATION.cff`](CITATION.cff) is shipped at the
repo root — GitHub's "Cite this repository" widget will render it
automatically. A BibTeX-ready entry is reproduced here for convenience:

```bibtex
@software{sondos_fpga,
  author    = {Hamed, Ezz and Ender, Ian and Graf, Chris},
  title     = {{sondos\_fpga}: An open-source FPGA shell and library
               for AMD/Xilinx host and remote platforms},
  year      = {2026},
  month     = apr,
  version   = {0.1.0},
  publisher = {Meta Platforms, Inc.},
  url       = {https://github.com/facebookresearch/sondos_fpga},
  note      = {GitHub repository}
}
```
