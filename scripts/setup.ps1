# SPDX-License-Identifier: MIT
# (c) Meta Platforms, Inc. and affiliates.
#
# sondos_fpga environment setup (PowerShell). Dot-source this file before
# invoking any build TCLs:
#
#     $env:VIVADO_DIR = 'C:\Xilinx\Vivado\2023.2'
#     $env:XSCT_DIR   = 'C:\Xilinx\Vitis\2023.2'
#     . .\scripts\setup.ps1
#
# The script does NOT install or download anything. It only validates that
# the required Xilinx tools are reachable and updates PATH for the session.

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$env:REPO_ROOT = $repoRoot
# SONDOS_PATH is the public-facing alias used by all build TCLs / scripts.
$env:SONDOS_PATH = $repoRoot

if (-not $env:VIVADO_DIR) {
    throw 'Please set $env:VIVADO_DIR to your Vivado install path (e.g. C:\Xilinx\Vivado\2023.2).'
}
if (-not $env:XSCT_DIR) {
    $env:XSCT_DIR = Join-Path (Split-Path $env:VIVADO_DIR -Parent) ('Vitis\' + (Split-Path $env:VIVADO_DIR -Leaf))
}

$vivadoExe = Join-Path $env:VIVADO_DIR 'bin\vivado.bat'
if (-not (Test-Path -LiteralPath $vivadoExe)) {
    throw "vivado.bat not found at $vivadoExe"
}

$env:Path = (Join-Path $env:VIVADO_DIR 'bin') + ';' + (Join-Path $env:XSCT_DIR 'bin') + ';' + $env:Path

Write-Host "sondos_fpga setup OK:"
Write-Host ("  REPO_ROOT   = " + $env:REPO_ROOT)
Write-Host ("  SONDOS_PATH = " + $env:SONDOS_PATH)
Write-Host ("  VIVADO_DIR  = " + $env:VIVADO_DIR)
Write-Host ("  XSCT_DIR    = " + $env:XSCT_DIR)
$ver = (& $vivadoExe -version 2>$null | Select-Object -First 1)
Write-Host ("  Vivado     = " + $ver)
Write-Host "Ready to build."
