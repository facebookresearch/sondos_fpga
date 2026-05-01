<!-- SPDX-License-Identifier: MIT -->
<!-- (c) Meta Platforms, Inc. and affiliates. -->

# Build Guide

## Prerequisites

- **AMD/Xilinx Vivado 2022 or later** (the maintainers test against 2023.2; older / newer versions should also work for most builds).
- Bash on Linux (or WSL2 on Windows), or PowerShell on Windows.

> **Note**: AMD/Xilinx Vivado is not supported on macOS. Use Linux or Windows.

## Environment setup

Point at your local tool install before running any build TCL:

### Linux

```bash
export VIVADO_DIR=/opt/Xilinx/Vivado/2023.2
# Optional: export XSCT_DIR=/opt/Xilinx/Vitis/2023.2
source scripts/setup.sh
```

### Windows (PowerShell)

```powershell
$env:VIVADO_DIR = 'C:\Xilinx\Vivado\2023.2'
. .\scripts\setup.ps1
```

`setup.{sh,ps1}` validates the install path and prepends Vivado's bin to
`PATH`. It does not install or download anything.

## Building the streamer demo

The repo ships a generic dispatcher script that picks the right per-board
build TCL for you:

```bash
# Linux:
./scripts/build_demo.sh <board>

# Windows:
.\scripts\build_demo.ps1 <board>
```

After Vivado finishes, the output bitstream is under the local
`./streamer_demo/streamer_demo.runs/impl_1/` directory.

### Available boards

| Board            | Command                                |
|------------------|----------------------------------------|
| Alveo U250 host  | `./scripts/build_demo.sh alveo_u250_host`  |
| Alveo U45N host  | `./scripts/build_demo.sh alveo_u45n_host`  |
| HTG-930 host     | `./scripts/build_demo.sh htg930_host`      |
| HTG-930 remote   | `./scripts/build_demo.sh htg930_remote`    |
| VCU118 host      | `./scripts/build_demo.sh vcu118_host`      |
| VCU118 remote    | `./scripts/build_demo.sh vcu118_remote`    |

If you'd rather invoke Vivado directly (no dispatcher), each board has a
flat `build.tcl` next to its `*_project_top.sv`:

```bash
cd lib/streamer_demo/htg930_host
vivado -mode batch -source build.tcl
```

## Building the host C++ SW (`sondos_streaming_demo`)

The streamer demo ships a host C++ binary that talks to the FPGA via the
Sondos library's GenTL Transport Layer C API. Build with **CMake 3.20+**
and a C++20-capable compiler (MSVC 19.30+ on Windows, g++ 10+ / clang++ 14+
on Linux).

### Prerequisites
- Sondos install at `C:\Program Files\Sondos` on Windows (or `/opt/sondos`
  on Linux). Must contain `headers/sondos/sondos_base.h` and the import
  library (`lib/sondos.dll.imp.lib` on Windows; `lib/libsondos.so` on Linux).
- CMake 3.20+ on `PATH`.
- A C++20 compiler:
  - **Windows**: Visual Studio Build Tools 2022 with the "Desktop development
    with C++" workload (`cl.exe` 19.30+).
  - **Linux**: g++ 10+ or clang++ 14+.
- Internet access on first build (CMake `FetchContent` pulls `gflags`).

### Windows
```powershell
# Open "x64 Native Tools Command Prompt for VS 2022", or run:
& "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"

cd lib\streamer_demo\sw\cpp
cmake -G Ninja -DCMAKE_BUILD_TYPE=Release `
      -DCMAKE_CXX_FLAGS="/EHsc /D_CRT_SECURE_NO_WARNINGS /DNOMINMAX /DWIN32_LEAN_AND_MEAN" `
      -S . -B build
cmake --build build --target sondos_streaming_demo --config Release
```

### Linux
```bash
cd lib/streamer_demo/sw/cpp
cmake -G Ninja -DCMAKE_BUILD_TYPE=Release \
      -DSONDOS_INSTALL_DIR=/opt/sondos \
      -S . -B build
cmake --build build --target sondos_streaming_demo --config Release
```

The output binary is at `build/sondos_streaming_demo` (or `.exe` on Windows).

### Linux memlock limit (one-time setup)

The streamer demo page-locks DMA buffers (`mlock`-style) to give the FPGA
DMA stable physical addresses. Linux's default `RLIMIT_MEMLOCK` (~64 KB
on most distros) is too small — the demo will fail on the first lock call.

Run this once (requires `sudo`), then **log out and back in** so the new
limit takes effect:

```bash
echo -e "$USER hard memlock unlimited
$USER soft memlock unlimited" \
    | sudo tee /etc/security/limits.d/99-$USER-sondos.conf
```

Verify with `ulimit -l` after re-login — should print `unlimited`.

Windows users do not need this — Windows handles working-set sizing in
the demo binary itself.

### Running
```bash
# Default: host loopback, both Rx and Tx perf threads
./sondos_streaming_demo

# Remote-1 mode (use the C2C remote FPGA):
./sondos_streaming_demo --RemoteId=1

# Remote-2 mode:
./sondos_streaming_demo --RemoteId=2

# List all flags:
./sondos_streaming_demo --help
```

Common flags:
| Flag | Default | Purpose |
|---|---|---|
| `--RemoteId N` | `0` | `0` = host, `1` = Remote1, `2` = Remote2 |
| `--Interface ID` | `libsondos.if0` | Which Sondos interface to open (use `libsondos.if1` for the built-in simulator). |
| `--Latency` | `false` | Run latency-only test |
| `--RxPerf` / `--TxPerf` | `true` | Run perf tests for receive / transmit |
| `--Rx` / `--Tx` | `false` | One-shot receive / transmit modes (file or text) |
| `--NumPackets N` | `200000` | Packets per perf/latency iteration |
| `--PacketSize N` | `1024` | Bytes per packet |
| `--EnableVerboseLogging` | `false` | Spam the log with extra info |

## Adding a new board

See [`supported_boards.md`](supported_boards.md) for the recommended pattern.
