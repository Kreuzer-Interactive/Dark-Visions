<#
.SYNOPSIS
  pcx2bmp.ps1 - convert 8-bit (256-colour) PCX art to the 8-bit BMP that uGL loads.

.DESCRIPTION
  Reads a version-5 PCX (8 bits per pixel, 1 plane, 256-entry palette at the end of
  the file) and writes an uncompressed 8-bit Windows BMP: 54-byte header, 256 BGRA
  palette entries, bottom-up rows padded to 4 bytes. Pixel indices are kept as-is,
  so drawing the BMP with uglPutBMPEx ... BMPOPT.NO332 and setting the palette from
  the file (GAME6 VgaPalBMP) reproduces the PCX exactly. Same layout as TPLOGO.BMP.

.EXAMPLE
  .\pcx2bmp.ps1 ..\..\art\TP640.pcx ..\TPLOGO.BMP
  .\pcx2bmp.ps1 TP320.pcx            # writes TP320.BMP next to the source
  .\pcx2bmp.ps1 TP640.pcx -Info      # dimensions + colour usage only, no output
#>
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$InPcx,
    [Parameter(Position = 1)][string]$OutBmp,
    [switch]$Info
)

$ErrorActionPreference = 'Stop'
$src = Resolve-Path $InPcx
$d = [System.IO.File]::ReadAllBytes($src)
if ($d.Length -lt 128 + 769 -or $d[0] -ne 10) { throw "$InPcx is not a PCX file" }
$bpp = $d[3]; $planes = $d[65]
if ($bpp -ne 8 -or $planes -ne 1) { throw "only 8-bit single-plane PCX is supported (this one: $bpp bpp, $planes planes)" }
if ($d[$d.Length - 769] -ne 12) { throw "no 256-colour palette marker at the end of $InPcx" }
$xmin = [BitConverter]::ToUInt16($d, 4); $ymin = [BitConverter]::ToUInt16($d, 6)
$xmax = [BitConverter]::ToUInt16($d, 8); $ymax = [BitConverter]::ToUInt16($d, 10)
$bpl = [BitConverter]::ToUInt16($d, 66)
$w = $xmax - $xmin + 1; $h = $ymax - $ymin + 1
$total = $bpl * $h

# RLE decode (top-down scanlines, $bpl bytes each)
$pix = New-Object byte[] $total
$o = 0; $i = 128; $end = $d.Length - 769
while ($o -lt $total -and $i -lt $end) {
    $c = $d[$i]; $i++
    if ($c -ge 192) {
        $n = $c - 192; $v = $d[$i]; $i++
        if ($o + $n -gt $total) { $n = $total - $o }
        for ($k = 0; $k -lt $n; $k++) { $pix[$o + $k] = $v }
        $o += $n
    } else {
        $pix[$o] = $c; $o++
    }
}
if ($o -lt $total) { throw "PCX data ended early ($o of $total bytes)" }

# palette: 256 x RGB at the end of the file
$palOff = $d.Length - 768
$used = New-Object int[] 256
for ($y = 0; $y -lt $h; $y++) { $row = $y * $bpl; for ($x = 0; $x -lt $w; $x++) { $used[$pix[$row + $x]]++ } }
$nUsed = ($used | Where-Object { $_ -gt 0 }).Count
$grey = 0
for ($k = 0; $k -lt 256; $k++) { $p = $palOff + 3 * $k; if ($d[$p] -eq $d[$p + 1] -and $d[$p + 1] -eq $d[$p + 2]) { $grey++ } }
"{0}: {1}x{2}, {3} of 256 palette indices used, {4} grey entries" -f (Split-Path $src -Leaf), $w, $h, $nUsed, $grey
if ($Info) { return }

if (-not $OutBmp) { $OutBmp = [System.IO.Path]::ChangeExtension($src, '.BMP') }
$stride = ($w + 3) -band (-bnot 3)
$body = New-Object byte[] ($stride * $h)
for ($y = 0; $y -lt $h; $y++) {
    # BMP rows are stored bottom-up
    [Array]::Copy($pix, $y * $bpl, $body, ($h - 1 - $y) * $stride, $w)
}
$off = 14 + 40 + 1024
$ms = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter($ms)
$bw.Write([byte[]](0x42, 0x4D))                       # 'BM'
$bw.Write([uint32]($off + $body.Length))              # file size
$bw.Write([uint16]0); $bw.Write([uint16]0)            # reserved
$bw.Write([uint32]$off)                               # pixel data offset
$bw.Write([uint32]40)                                 # BITMAPINFOHEADER size
$bw.Write([int32]$w); $bw.Write([int32]$h)            # width, height (positive = bottom-up)
$bw.Write([uint16]1); $bw.Write([uint16]8)            # planes, bits per pixel
$bw.Write([uint32]0)                                  # BI_RGB (no compression)
$bw.Write([uint32]$body.Length)                       # image size
$bw.Write([int32]2835); $bw.Write([int32]2835)        # pixels per metre (72 dpi)
$bw.Write([uint32]256); $bw.Write([uint32]256)        # colours used / important
for ($k = 0; $k -lt 256; $k++) {
    $p = $palOff + 3 * $k
    $bw.Write([byte[]]($d[$p + 2], $d[$p + 1], $d[$p], 0))   # BGRA
}
$bw.Write($body)
$bw.Flush()
[System.IO.File]::WriteAllBytes($OutBmp, $ms.ToArray())
"wrote {0} ({1} bytes)" -f $OutBmp, $ms.Length
