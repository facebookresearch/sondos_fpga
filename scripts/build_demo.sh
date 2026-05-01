#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# (c) Meta Platforms, Inc. and affiliates.
#
# Generic streamer-demo build dispatcher (Linux).
# Usage:  ./scripts/build_demo.sh <board>
# Example: ./scripts/build_demo.sh htg930_host
#
# Supported board names match the per-board directories under
# lib/streamer_demo/ (alveo_u250_host, alveo_u45n_host, htg930_host,
# htg930_remote, vcu118_host, vcu118_remote).

set -eu

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <board>"
    echo "Available boards:"
    ls "$(dirname "$0")/../lib/streamer_demo" 2>/dev/null \
        | grep -v -E '^(common|sw)$' \
        | sed 's/^/  /'
    exit 1
fi
BOARD="$1"

# Repo root. Prefer an explicit SONDOS_PATH; fall back to git.
: "${SONDOS_PATH:=$(git rev-parse --show-toplevel 2>/dev/null || true)}"
: "${SONDOS_PATH:?Please export SONDOS_PATH to the sondos_fpga repo root, or run from inside a git checkout.}"
export SONDOS_PATH

# Vivado install — caller must point us at it.
: "${VIVADO_DIR:?Please export VIVADO_DIR (e.g. /opt/Xilinx/Vivado/2023.2).}"
# shellcheck disable=SC1091
source "$VIVADO_DIR/settings64.sh"

BUILD_TCL="$SONDOS_PATH/lib/streamer_demo/$BOARD/build.tcl"
if [ ! -f "$BUILD_TCL" ]; then
    echo "ERROR: no build.tcl for board '$BOARD' at $BUILD_TCL"
    exit 1
fi

vivado -mode batch -source "$BUILD_TCL"
