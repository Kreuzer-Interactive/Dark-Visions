<#
.SYNOPSIS
  img2bmp8.ps1 - turn an image into the 8-bit (256-colour) BMP that uGL loads, with the top
  eight palette slots (248-255) reserved for the game's VGA UI colours.

.DESCRIPTION
  Two paths:
  * Indexed path - the source is an 8-bit BMP and no resampling is needed (crop size = output size,
    or -Height 0 = keep the crop height): the pixels and YOUR palette are kept as-is. The
    -Reserve (default 8) least-used palette entries are remapped to their nearest colours and
    moved to slots 248-255, which are then filled with the UI colours below. Index 0 is made the
    darkest colour of the palette (the pad columns the page-turn slide reveals are index 0).
  * Resample path - anything else (PNG/JPG/24-bit BMP, or a size change): System.Drawing fits the
    (cropped) image onto a Width x Height black canvas (aspect kept and centred unless -Stretch),
    WPF builds an optimal palette of 256 - Reserve colours (octree, nearest colour, no dither)
    and the UI colours are appended at 248-255.
  Output: uncompressed bottom-up 8-bit BMP, 256 BGRA palette entries (same layout as TPLOGO.BMP).
  Draw it with uglPutBMPEx ... BMPOPT.NO332 and set the palette from the file (GAME6 VgaPalBMP).

  UI slots: 248 black, 249 white, 250 light grey, 251 mid grey, 252 dark grey, 253 parchment,
  254 dark parchment, 255 red. GAME6.BAS uses these by number (cBlack.. cRed).

.EXAMPLE
  .\img2bmp8.ps1 spread.bmp ..\MAN01H.BMP -CropX 0   -CropW 640 -CropH 853 -Width 640 -Height 853
  .\img2bmp8.ps1 spread.bmp ..\MAN02H.BMP -CropX 640 -CropW 640 -CropH 853 -Width 640 -Height 0
  .\img2bmp8.ps1 spread.bmp ..\MAN01L.BMP -CropW 640 -CropH 853 -Width 320 -Height 200     # resampled
  .\img2bmp8.ps1 page.png ..\MAN03H.BMP -Width 640 -Height 0                              # PNG, width-fit
#>
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$In,
    [Parameter(Mandatory = $true, Position = 1)][string]$Out,
    [int]$Width = 640,
    [int]$Height = 480,
    [switch]$Stretch,
    [int]$CropX = 0,
    [int]$CropY = 0,
    [int]$CropW = 0,
    [int]$CropH = 0,
    [int]$Reserve = 8,
    [switch]$NoBlackZero,
    [int]$SplitAt = 0
)

$ErrorActionPreference = 'Stop'
$uiColors = @(@(0,0,0), @(255,255,255), @(208,208,208), @(144,144,144), @(72,72,72), @(230,200,140), @(150,120,70), @(190,40,40))
if ($Reserve -lt 0 -or $Reserve -gt 8) { throw "-Reserve must be 0..8" }
$srcPath = (Resolve-Path $In).Path

function Write-Bmp8([string]$path, [int]$w, [int]$h, [byte[]]$pixTopDown, [object[]]$pal) {
    # $pal = array of @(r,g,b), exactly 256 entries
    $stride = ($w + 3) -band (-bnot 3)
    $body = New-Object byte[] ($stride * $h)
    for ($y = 0; $y -lt $h; $y++) { [Array]::Copy($pixTopDown, $y * $w, $body, ($h - 1 - $y) * $stride, $w) }
    $off = 14 + 40 + 1024
    $oms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($oms)
    $bw.Write([byte[]](0x42, 0x4D)); $bw.Write([uint32]($off + $body.Length)); $bw.Write([uint16]0); $bw.Write([uint16]0); $bw.Write([uint32]$off)
    $bw.Write([uint32]40); $bw.Write([int32]$w); $bw.Write([int32]$h); $bw.Write([uint16]1); $bw.Write([uint16]8); $bw.Write([uint32]0)
    $bw.Write([uint32]$body.Length); $bw.Write([int32]2835); $bw.Write([int32]2835); $bw.Write([uint32]256); $bw.Write([uint32]256)
    for ($k = 0; $k -lt 256; $k++) { $c = $pal[$k]; $bw.Write([byte[]]($c[2], $c[1], $c[0], 0)) }
    $bw.Write($body); $bw.Flush()
    [System.IO.File]::WriteAllBytes($path, $oms.ToArray())
    return $oms.Length
}

function Make-BlackZero([byte[]]$pix, [object[]]$pal, [int]$uiStart) {
    # move the darkest non-UI entry to index 0 (swap entries + pixel values)
    $best = 0; $bestL = 1e9
    for ($k = 0; $k -lt $uiStart; $k++) { $c = $pal[$k]; $l = 299 * $c[0] + 587 * $c[1] + 114 * $c[2]; if ($l -lt $bestL) { $bestL = $l; $best = $k } }
    if ($best -ne 0) {
        $t = $pal[0]; $pal[0] = $pal[$best]; $pal[$best] = $t
        for ($i = 0; $i -lt $pix.Length; $i++) { $v = $pix[$i]; if ($v -eq 0) { $pix[$i] = [byte]$best } elseif ($v -eq $best) { $pix[$i] = 0 } }
    }
}

# ---- read the source header to decide the path ----
$bytes = [System.IO.File]::ReadAllBytes($srcPath)
$isBmp8 = $false
if ($bytes.Length -gt 54 -and $bytes[0] -eq 0x42 -and $bytes[1] -eq 0x4D) {
    $bpp = [BitConverter]::ToUInt16($bytes, 28); $comp = [BitConverter]::ToUInt32($bytes, 30)
    if ($bpp -eq 8 -and $comp -eq 0) { $isBmp8 = $true }
}
if ($isBmp8) {
    $srcW = [BitConverter]::ToInt32($bytes, 18); $srcH = [BitConverter]::ToInt32($bytes, 22)
} else {
    Add-Type -AssemblyName System.Drawing
    $probe = [System.Drawing.Image]::FromFile($srcPath); $srcW = $probe.Width; $srcH = $probe.Height; $probe.Dispose()
}
if ($CropW -le 0) { $CropW = $srcW - $CropX }
if ($CropH -le 0) { $CropH = $srcH - $CropY }
if ($Height -le 0) { $Height = [int][Math]::Round($CropH * ($Width / $CropW)) }
$uiStart = 256 - $Reserve
$pal = New-Object object[] 256
for ($k = 0; $k -lt 256; $k++) { $pal[$k] = @(0, 0, 0) }

$resampleIndexed = $isBmp8 -and -not ($CropW -eq $Width -and $CropH -eq $Height)
if ($isBmp8) {
    # ================= indexed path: keep pixels + palette =================
    # (with a size change the crop is resampled in RGB and mapped back onto this
    #  same palette below, so the author's colours survive either way)
    $off = [BitConverter]::ToUInt32($bytes, 10); $hs = [BitConverter]::ToUInt32($bytes, 14)
    $nCol = [BitConverter]::ToUInt32($bytes, 46); if ($nCol -eq 0) { $nCol = 256 }
    $flip = $srcH -gt 0; $ah = [Math]::Abs($srcH)
    for ($k = 0; $k -lt $nCol; $k++) { $p = 14 + $hs + 4 * $k; $pal[$k] = @([int]$bytes[$p + 2], [int]$bytes[$p + 1], [int]$bytes[$p]) }
    $sstride = ($srcW + 3) -band (-bnot 3)
    $pix = New-Object byte[] ($CropW * $CropH)
    for ($y = 0; $y -lt $CropH; $y++) {
        $sy = $CropY + $y; $frow = if ($flip) { $ah - 1 - $sy } else { $sy }
        [Array]::Copy($bytes, $off + $frow * $sstride + $CropX, $pix, $y * $CropW, $CropW)
    }
    $used = New-Object int[] 256
    foreach ($v in $pix) { $used[$v]++ }
    if ($Reserve -gt 0) {
        # least-used entries become the UI slots; remap their pixels to the nearest kept colour
        $order = 0..255 | Sort-Object { $used[$_] }, { $_ }
        $freed = @($order | Select-Object -First $Reserve)
        $isFreed = New-Object bool[] 256; foreach ($f in $freed) { $isFreed[$f] = $true }
        $map = New-Object byte[] 256; for ($k = 0; $k -lt 256; $k++) { $map[$k] = [byte]$k }
        $lost = 0
        foreach ($f in $freed) {
            if ($used[$f] -eq 0) { continue }
            $lost += $used[$f]
            $c = $pal[$f]; $best = -1; $bestD = [long]::MaxValue
            for ($k = 0; $k -lt 256; $k++) {
                if ($isFreed[$k]) { continue }
                $d = $pal[$k]; $dr = $c[0] - $d[0]; $dg = $c[1] - $d[1]; $db = $c[2] - $d[2]
                $dist = 3 * $dr * $dr + 4 * $dg * $dg + 2 * $db * $db
                if ($dist -lt $bestD) { $bestD = $dist; $best = $k }
            }
            $map[$f] = [byte]$best
        }
        # permutation: freed slot f <-> target slot 248+k (pixels valued at the target move to f)
        for ($k = 0; $k -lt $Reserve; $k++) {
            $f = $freed[$k]; $t = $uiStart + $k
            if ($f -ne $t) {
                # anything currently mapping to $t must go to $f, and $t's palette colour moves to $f
                for ($m = 0; $m -lt 256; $m++) { if ($map[$m] -eq $t) { $map[$m] = [byte]$f } }
                $pal[$f] = $pal[$t]
                # keep the freed list consistent for later swaps: slot t is now "free", slot f holds t's colour
                for ($j = $k + 1; $j -lt $Reserve; $j++) { if ($freed[$j] -eq $t) { $freed[$j] = $f } }
            }
            $pal[$t] = $uiColors[$k]
        }
        for ($i = 0; $i -lt $pix.Length; $i++) { $pix[$i] = $map[$pix[$i]] }
        "{0}: {1}x{2} indexed, crop {3},{4} {5}x{6}; {7} pixels remapped to free {8} UI slots" -f (Split-Path $srcPath -Leaf), $srcW, $srcH, $CropX, $CropY, $CropW, $CropH, $lost, $Reserve
    }
    if ($resampleIndexed) {
        # size change: render the crop, resize it with bicubic filtering, then map every pixel
        # back onto the kept palette entries (WPF nearest-colour with a fixed palette)
        Add-Type -AssemblyName System.Drawing
        Add-Type -AssemblyName PresentationCore
        Add-Type -AssemblyName WindowsBase
        $tmp = [System.IO.Path]::Combine($env:TEMP, 'img2bmp8_' + [System.IO.Path]::GetRandomFileName() + '.bmp')
        [void](Write-Bmp8 $tmp $CropW $CropH $pix $pal)
        $src = [System.Drawing.Image]::FromFile($tmp)
        try {
            $canvas = New-Object System.Drawing.Bitmap $Width, $Height, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
            $g = [System.Drawing.Graphics]::FromImage($canvas)
            $g.Clear([System.Drawing.Color]::Black)
            $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            if ($Stretch) { $dw = $Width; $dh = $Height; $dx = 0; $dy = 0 }
            else {
                $scale = [Math]::Min($Width / $CropW, $Height / $CropH)
                $dw = [int][Math]::Round($CropW * $scale); $dh = [int][Math]::Round($CropH * $scale)
                $dx = [int](($Width - $dw) / 2); $dy = [int](($Height - $dh) / 2)
            }
            $g.DrawImage($src, (New-Object System.Drawing.Rectangle $dx, $dy, $dw, $dh))
            $g.Dispose()
            $ms = New-Object System.IO.MemoryStream
            $canvas.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
            $canvas.Dispose()
        } finally { $src.Dispose(); [System.IO.File]::Delete($tmp) }
        $ms.Position = 0
        $frame = [System.Windows.Media.Imaging.BitmapFrame]::Create($ms, [System.Windows.Media.Imaging.BitmapCreateOptions]::None, [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
        $colors = New-Object 'System.Collections.Generic.List[System.Windows.Media.Color]'
        for ($k = 0; $k -lt $uiStart; $k++) { $c = $pal[$k]; $colors.Add([System.Windows.Media.Color]::FromRgb([byte]$c[0], [byte]$c[1], [byte]$c[2])) }
        $wpal = [System.Windows.Media.Imaging.BitmapPalette]::new($colors)   # (New-Object would splat the list into 248 arguments)
        $conv = New-Object System.Windows.Media.Imaging.FormatConvertedBitmap($frame, [System.Windows.Media.PixelFormats]::Indexed8, $wpal, 0.0)
        $pix = New-Object byte[] ($Width * $Height)
        $conv.CopyPixels($pix, $Width, 0)
        "  resampled to {0}x{1} (image {2}x{3} at {4},{5}), mapped back onto the {6} kept palette entries" -f $Width, $Height, $dw, $dh, $dx, $dy, $uiStart
    }
    if (-not $NoBlackZero) { Make-BlackZero $pix $pal $uiStart }
} else {
    # ================= resample path: System.Drawing fit + WPF quantise =================
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    $src = [System.Drawing.Image]::FromFile($srcPath)
    try {
        $canvas = New-Object System.Drawing.Bitmap $Width, $Height, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
        $g = [System.Drawing.Graphics]::FromImage($canvas)
        $g.Clear([System.Drawing.Color]::Black)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        if ($Stretch) { $dw = $Width; $dh = $Height; $dx = 0; $dy = 0 }
        else {
            $scale = [Math]::Min($Width / $CropW, $Height / $CropH)
            $dw = [int][Math]::Round($CropW * $scale); $dh = [int][Math]::Round($CropH * $scale)
            $dx = [int](($Width - $dw) / 2); $dy = [int](($Height - $dh) / 2)
        }
        $g.DrawImage($src, (New-Object System.Drawing.Rectangle $dx, $dy, $dw, $dh), (New-Object System.Drawing.Rectangle $CropX, $CropY, $CropW, $CropH), [System.Drawing.GraphicsUnit]::Pixel)
        $g.Dispose()
        $ms = New-Object System.IO.MemoryStream
        $canvas.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        $canvas.Dispose()
    } finally { $src.Dispose() }
    $ms.Position = 0
    $frame = [System.Windows.Media.Imaging.BitmapFrame]::Create($ms, [System.Windows.Media.Imaging.BitmapCreateOptions]::None, [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
    $wpal = New-Object System.Windows.Media.Imaging.BitmapPalette($frame, $uiStart)
    $conv = New-Object System.Windows.Media.Imaging.FormatConvertedBitmap($frame, [System.Windows.Media.PixelFormats]::Indexed8, $wpal, 0.0)
    $pix = New-Object byte[] ($Width * $Height)
    $conv.CopyPixels($pix, $Width, 0)
    $cols = $conv.Palette.Colors
    if ($cols.Count -gt $uiStart) { throw "quantiser returned $($cols.Count) colours, expected <= $uiStart" }
    for ($k = 0; $k -lt $cols.Count; $k++) { $c = $cols[$k]; $pal[$k] = @([int]$c.R, [int]$c.G, [int]$c.B) }
    for ($k = 0; $k -lt $Reserve; $k++) { $pal[$uiStart + $k] = $uiColors[$k] }
    if (-not $NoBlackZero) { Make-BlackZero $pix $pal $uiStart }
    "{0}: {1}x{2} resampled, crop {3},{4} {5}x{6} -> image {7}x{8} at {9},{10} on {11}x{12}, {13} colours + {14} UI" -f (Split-Path $srcPath -Leaf), $srcW, $srcH, $CropX, $CropY, $CropW, $CropH, $dw, $dh, $dx, $dy, $Width, $Height, $cols.Count, $Reserve
}
if ($SplitAt -gt 0 -and $SplitAt -lt $Height) {
    # two files sharing one palette: rows 0..SplitAt-1 -> $Out, the rest -> <Out>B.<ext>
    # (uGL 0.23b's BMP loader corrupts bitmaps that overhang the video page, so GAME6 wants
    #  a top part of at most 460 rows and a bottom part of at most 480 rows)
    $top = New-Object byte[] ($Width * $SplitAt); [Array]::Copy($pix, 0, $top, 0, $top.Length)
    $bh = $Height - $SplitAt
    $bot = New-Object byte[] ($Width * $bh); [Array]::Copy($pix, $Width * $SplitAt, $bot, 0, $bot.Length)
    $len = Write-Bmp8 $Out $Width $SplitAt $top $pal
    $out2 = [System.IO.Path]::Combine((Split-Path $Out -Parent), ([System.IO.Path]::GetFileNameWithoutExtension($Out) + 'B' + [System.IO.Path]::GetExtension($Out)))
    $len2 = Write-Bmp8 $out2 $Width $bh $bot $pal
    "wrote {0} ({1}x{2}, {3} bytes) + {4} ({5}x{6}, {7} bytes), index 0 = {8}" -f $Out, $Width, $SplitAt, $len, $out2, $Width, $bh, $len2, ($pal[0] -join ',')
} else {
    $len = Write-Bmp8 $Out $Width $Height $pix $pal
    "wrote {0} ({1}x{2}, {3} bytes, index 0 = {4})" -f $Out, $Width, $Height, $len, ($pal[0] -join ',')
}
