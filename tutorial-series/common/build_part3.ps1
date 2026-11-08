# Build every Part 3 overlay for both EDGE ZYNQ chips, plus the HLS FIR and the PWM testbench.
# Run from the series folder:  powershell -ExecutionPolicy Bypass -File common\build_part3.ps1
# About 1 hour in total. Each overlay lands in <episode>\overlays\z10 and \z20.
param([string]$Vivado = 'E:\Xilinx\Vivado\2022.2\bin\vivado.bat',
      [string]$Hls    = 'E:\Xilinx\Vitis_HLS\2022.2\bin\vitis_hls.bat',
      [string]$Work   = "$env:TEMP\edge_pynq_series_build")
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$chips = @{ z10 = 'xc7z010clg400-1'; z20 = 'xc7z020clg400-1' }
$results = @()

function Run-Vivado($script, $name, $chip, $outdir, $extra) {
    $w = Join-Path $Work "$name`_$chip"
    if (Test-Path $w) { Remove-Item -Recurse -Force $w }
    New-Item -ItemType Directory -Force -Path $outdir | Out-Null
    $log = Join-Path $Work "$name`_$chip.log"
    $args = @('-mode', 'batch', '-nojournal', '-log', $log, '-source', $script, '-tclargs', $chips[$chip], $w, $outdir) + $extra
    & $Vivado @args | Out-Null
    $line = Select-String -Path $log -Pattern 'EDGE_RESULT' | Select-Object -Last 1
    "$name $chip : $(if ($line) { $line.Line } else { 'no result, see ' + $log })"
}

New-Item -ItemType Directory -Force -Path $Work | Out-Null

# episode 13: Verilog testbench first (run_xsim.bat uses the same Vivado)
$env:VIVADO = Split-Path -Parent (Split-Path -Parent $Vivado)
Push-Location "$root\13_axi_lite_pwm\sim"
$sim = & cmd /c run_xsim.bat 2>&1 | Out-String
Pop-Location
$results += "edge_pwm testbench: " + $(if ($sim -match 'TEST PASSED') { 'PASSED' } else { 'FAILED' })

# episode 16: HLS (C simulation, synthesis, IP export)
Push-Location "$root\16_hls_fir\hls"
$hlsOut = & $Hls -f run_hls.tcl 2>&1 | Out-String
Pop-Location
$hlsIp = "$root\16_hls_fir\hls\fir_prj\solution1\impl\ip"
$results += "HLS FIR: C simulation " + $(if ($hlsOut -match 'TEST PASSED') { 'PASSED' } else { 'FAILED' }) +
            ", IP " + $(if (Test-Path "$hlsIp\component.xml") { 'exported' } else { 'MISSING' })

foreach ($chip in 'z10', 'z20') {
    $results += Run-Vivado "$root\12_first_overlay\first_overlay.tcl" 'first_overlay' $chip "$root\12_first_overlay\overlays\$chip" @()
    $results += Run-Vivado "$root\13_axi_lite_pwm\vivado\pwm_overlay.tcl" 'pwm_overlay' $chip "$root\13_axi_lite_pwm\overlays\$chip" @()
    $results += Run-Vivado "$root\15_axi_dma\dma_overlay.tcl" 'dma_overlay' $chip "$root\15_axi_dma\overlays\$chip" @()
    $results += Run-Vivado "$root\16_hls_fir\vivado\fir_overlay.tcl" 'fir_overlay' $chip "$root\16_hls_fir\overlays\$chip" @($hlsIp)
}
$results
"PART3 BUILD DONE"
