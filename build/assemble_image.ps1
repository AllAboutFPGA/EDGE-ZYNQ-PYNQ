# Make the EDGE ZYNQ PYNQ SD card image: PYNQ-Z2 v3.1.1 image with the EDGE boot partition, then zip it.
param([string]$BootZip = 'E:\Downloads\edge_jobs\pynq\edge_boot_part.zip', [string]$Name = 'EDGE_ZYNQ_PYNQ_v3.1.1_2026-11-07')
$ErrorActionPreference = 'Stop'
$p = 'E:\Downloads\edge_jobs\pynq'
$src = "$p\pynq_z2_v3.1.1.img"
$rel = "$p\release"; New-Item -ItemType Directory -Force $rel | Out-Null
$name = $Name
$img = "$rel\$name.img"
Add-Type -AssemblyName System.IO.Compression.FileSystem

# boot partition built by tools/make_bootfs.py (zipped)
$tmp = "$p\edge_boot_part_unzip"; Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
[IO.Compression.ZipFile]::ExtractToDirectory($BootZip, $tmp)
$boot = Get-ChildItem $tmp -Filter *.bin | Select-Object -First 1
"boot partition: $($boot.Name) $($boot.Length)"

# partition 1 of the PYNQ-Z2 image
$fs = [IO.File]::OpenRead($src); $mbr = New-Object byte[] 512; [void]$fs.Read($mbr, 0, 512); $fs.Close()
$lba = [BitConverter]::ToUInt32($mbr, 446 + 8); $cnt = [BitConverter]::ToUInt32($mbr, 446 + 12)
"partition 1: start $lba, $cnt sectors ($([int64]$cnt * 512) bytes)"
if ([int64]$cnt * 512 -ne $boot.Length) { throw "boot partition size does not match" }

Copy-Item $src $img -Force
$o = [IO.File]::Open($img, 'Open', 'ReadWrite')
$o.Position = [int64]$lba * 512
$b = [IO.File]::ReadAllBytes($boot.FullName)
$o.Write($b, 0, $b.Length); $o.Flush(); $o.Close()

# check: the partition in the image is byte-for-byte the new one
$o = [IO.File]::OpenRead($img); $o.Position = [int64]$lba * 512
$chk = New-Object byte[] $b.Length; $n = 0; while ($n -lt $b.Length) { $r = $o.Read($chk, $n, $b.Length - $n); if ($r -le 0) { break }; $n += $r }; $o.Close()
$sha = [Security.Cryptography.SHA256]::Create()
$h1 = [BitConverter]::ToString($sha.ComputeHash($b)); $h2 = [BitConverter]::ToString($sha.ComputeHash($chk))
"boot partition written: $($h1 -eq $h2)"
if ($h1 -ne $h2) { throw "verify failed" }
Remove-Item $tmp -Recurse -Force

$imgHash = (Get-FileHash $img -Algorithm SHA256).Hash
"$imgHash  $name.img" | Set-Content "$rel\$name.img.sha256" -Encoding ASCII
"image: $img $((Get-Item $img).Length)  sha256 $imgHash"

# zip (streamed, Zip64 for the 8 GB image)
$zip = "$rel\$name.zip"; Remove-Item $zip -Force -ErrorAction SilentlyContinue
$za = [IO.Compression.ZipFile]::Open($zip, 'Create')
[void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($za, $img, "$name.img", 'Optimal')
[void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($za, "$rel\$name.img.sha256", "$name.img.sha256", 'Optimal')
$za.Dispose()
$zipHash = (Get-FileHash $zip -Algorithm SHA256).Hash
"$zipHash  $name.zip" | Set-Content "$rel\$name.zip.sha256" -Encoding ASCII
"zip: $zip $((Get-Item $zip).Length)  sha256 $zipHash"

# check the zip: the image inside must have the same SHA-256
$za = [IO.Compression.ZipFile]::OpenRead($zip)
$e = $za.Entries | Where-Object { $_.Name -eq "$name.img" }
$st = $e.Open(); $h = [BitConverter]::ToString($sha.ComputeHash($st)).Replace('-', ''); $st.Close(); $za.Dispose()
"zip check: $($h -eq $imgHash)"
"ASSEMBLE DONE"
