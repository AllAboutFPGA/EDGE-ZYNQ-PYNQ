# Build PYNQ's HLS video IP (color_convert, pixel_unpack) with Vitis HLS 2022.2.
# Usage: build_hls_ip.ps1 -IpDir <folder where pynq_ip.zip was unzipped>\ip
param([Parameter(Mandatory = $true)][string]$IpDir,
      [string]$Hls = 'C:\Xilinx\Vitis_HLS\2022.2\bin\vitis_hls.bat')
$ErrorActionPreference = 'Stop'
Push-Location "$IpDir\hls"
try {
    foreach ($ip in 'color_convert', 'pixel_unpack') {
        & $Hls -f "$ip/script.tcl"
        if (-not (Test-Path "$ip\solution1\impl\ip\component.xml")) { throw "$ip was not exported" }
        "$ip OK"
    }
} finally { Pop-Location }
