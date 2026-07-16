# HUB75 simulation runner for Windows PowerShell (Icarus Verilog).
# Usage:  ./run_sim.ps1            # build + run the self-checking testbench
#         ./run_sim.ps1 -Wave      # also open the waveform in GTKWave

param([switch]$Wave)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$top = "../src/main.v"
$tb = "tb_hub75.v"
$image = "image_8x8.hex"
$out = "tb_hub75.vvp"
$vcd = "tb_hub75.vcd"

# HUB75_SIM_INIT preloads the framebuffer from $image via $readmemh
$defs = @("-DHUB75_SIM_INIT", "-DHUB75_INIT_FILE=`"$image`"")

Write-Host "==> Compiling..." -ForegroundColor Cyan
& iverilog -g2012 -Wall @defs -o $out $top $tb
if ($LASTEXITCODE -ne 0) { throw "iverilog failed" }

Write-Host "==> Running..." -ForegroundColor Cyan
& vvp $out

if ($Wave) {
    Write-Host "==> Opening waveform..." -ForegroundColor Cyan
    & gtkwave $vcd
}
