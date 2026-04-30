#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# (c) Meta Platforms, Inc. and affiliates.
#
# sondos_fpga environment setup (POSIX). Source this file before invoking
# any of the build TCLs:
#
#     export VIVADO_DIR=/opt/Xilinx/Vivado/2023.2
#     export XSCT_DIR=/opt/Xilinx/Vitis/2023.2
#     source scripts/setup.sh
#
# The script does NOT install or download anything. It only validates that
# the required Xilinx tools are reachable and exports a couple of convenience
# variables consumed by the build TCLs.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
export REPO_ROOT
# SONDOS_PATH is the public-facing alias used by all build TCLs / scripts.
export SONDOS_PATH="$REPO_ROOT"

# Allow the user to override; default to the standard install layout if unset.
: "${VIVADO_DIR:?Please export VIVADO_DIR pointing to your Vivado install (e.g. /opt/Xilinx/Vivado/2023.2)}"
: "${XSCT_DIR:=$VIVADO_DIR/../Vitis/$(basename "$VIVADO_DIR")}"
export XSCT_DIR

if [[ ! -x "$VIVADO_DIR/bin/vivado" ]]; then
  echo "ERROR: vivado not found at $VIVADO_DIR/bin/vivado" >&2
  return 1 2>/dev/null || exit 1
fi

export PATH="$VIVADO_DIR/bin:$XSCT_DIR/bin:$PATH"

echo "sondos_fpga setup OK:"
echo "  REPO_ROOT   = $REPO_ROOT"
echo "  SONDOS_PATH = $SONDOS_PATH"
echo "  VIVADO_DIR  = $VIVADO_DIR"
echo "  XSCT_DIR    = $XSCT_DIR"
echo "  Vivado      = $(vivado -version 2>/dev/null | head -1)"
echo "Ready to build."
