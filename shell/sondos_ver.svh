// SPDX-License-Identifier: MIT
// (c) Meta Platforms, Inc. and affiliates.

// Make sure not to define the Sondos version file multiple times
`ifndef __SONDOS_VER__
`define __SONDOS_VER__

// Sondos protocol version. All devices in the system must match!
`define C_SONDOS_HW_REV   8'd1
// Major software version indicates breaking software change (not backward compatible)
`define C_SONDOS_SW_MAJOR 8'd1
// Minor software version indicates new feature, but still backwards compatible with the same major revision
`define C_SONDOS_SW_MINOR 8'd3
// Patch software version indicates bugfixes (no new features), but still backwards compatible with same major revision
`define C_SONDOS_SW_PATCH 8'd0

`endif
