# SPDX-License-Identifier: MIT
# (c) Meta Platforms, Inc. and affiliates.
#
# Generic streamer-demo build dispatcher (Windows PowerShell).
# Usage:    .\scripts\build_demo.ps1 <board>
# Example:  .\scripts\build_demo.ps1 htg930_host
#
# Supported board names match the per-board directories under
# lib/streamer_demo/ (alveo_u250_host, alveo_u45n_host, htg930_host,
# htg930_remote, vcu118_host, vcu118_remote).

$ErrorActionPreference = 'Stop'

if (-not $args -or $args.Count -lt 1) {
    Write-Host "Usage: .\scripts\build_demo.ps1 <board>"
    Write-Host "Available boards:"
    $demoDir = Join-Path $PSScriptRoot '..\lib\streamer_demo'
    if (Test-Path -LiteralPath $demoDir) {
        Get-ChildItem -LiteralPath $demoDir -Directory `
            | Where-Object { $_.Name -notin @('common','sw') } `
            | ForEach-Object { Write-Host ("  " + $_.Name) }
    }
    exit 1
}
$Board = $args[0]

if (-not $env:SONDOS_PATH) {
    $env:SONDOS_PATH = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
}
if (-not $env:VIVADO_DIR) {
    Write-Host "ERROR: VIVADO_DIR is not set. Point it at your Vivado install (e.g. C:\Xilinx\Vivado\2023.2)."
    exit 1
}

$BuildTcl = Join-Path $env:SONDOS_PATH ("lib\streamer_demo\" + $Board + "\build.tcl")
if (-not (Test-Path -LiteralPath $BuildTcl)) {
    Write-Host ("ERROR: no build.tcl for board '" + $Board + "' at " + $BuildTcl)
    exit 1
}

& "$env:VIVADO_DIR\bin\vivado.bat" -mode batch -source $BuildTcl
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
