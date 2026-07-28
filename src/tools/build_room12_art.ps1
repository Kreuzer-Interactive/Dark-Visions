# Room 12 art conversion: PICs, sprite PCT/MSK sets, inventory tile 38.
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\dv_codec.ps1"
$src = 'C:\Code\Dark-Visions\src'
$art = "$src\ART\Add Room 12"
$sp = 'C:\Users\jhess\AppData\Local\Temp\claude\C--Code-Dark-Visions\7b6a8b66-2315-4be3-9f52-6df13750ff73\scratchpad'

# ---- 1. ROOM12.PIC (new) + ROOM10.PIC (grate baked) ----
$r12 = [DV]::QuantPng("$art\Room12_background.png", $null)
[DV]::EncodePic($r12, "$src\ROOM10.PIC", "$src\ROOM12.PIC")
$r10 = [DV]::QuantPng("$art\ROOM10_with_GrateToRoom12.png", $null)
[DV]::EncodePic($r10, "$src\ROOM10.PIC", "$src\ROOM10.PIC")
Write-Output "PICs written"

# ---- 2. sprite PCT/MSK sets ----
function Write-SpriteSet([string]$name, [string[]]$pngs, [int]$w, [int]$h) {
  $frames = New-Object 'System.Collections.Generic.List[int16[]]'
  $masks  = New-Object 'System.Collections.Generic.List[int16[]]'
  foreach ($p in $pngs) {
    $al = New-Object 'byte[,]' $w, $h
    $px = [DV]::QuantPng($p, $al)
    $frames.Add([DV]::FrameInts($px, $al, $w, $h, $false))
    $masks.Add([DV]::FrameInts($px, $al, $w, $h, $true))
  }
  [DV]::WriteSet("$src\$name.PCT", $frames)
  [DV]::WriteSet("$src\$name.MSK", $masks)
  Write-Output "$name.PCT/.MSK written ($($pngs.Count) frame(s) ${w}x${h})"
}
Write-SpriteSet 'GRATOPN' @("$art\Room10_GrateOpenFrame.png") 14 14
Write-SpriteSet 'NOPULLY' @("$art\NoPullySprite.png") 13 8
Write-SpriteSet 'CANDLE'  @("$art\CandleFlameFrame1.png", "$art\CandleFlameFrame2.png") 4 6
Write-SpriteSet 'CLIMB'   @("$art\JOE_ClimbFrame1.png", "$art\JOE_ClimbFrame2.png") 31 31

# ---- 3. inventory tile 38 (Pulley) on INVTIL2/INVMSK2 slot 17 (x135,y108) ----
Add-Type -AssemblyName System.Drawing
$bmp = [System.Drawing.Bitmap]::FromFile("$src\ART\Pully_InventoryItem.png")
$pw = $bmp.Width; $ph = $bmp.Height
# inventory palette: attr1=#AA5500(6) attr2=#AAAAAA(7) attr3=#555555(8)
$invpal = @(@(0,0,0), @(170,85,0), @(170,170,170), @(85,85,85))
$pq = New-Object 'byte[,]' $pw, $ph
$pa = New-Object 'byte[,]' $pw, $ph
for ($y = 0; $y -lt $ph; $y++) { for ($x = 0; $x -lt $pw; $x++) {
  $c = $bmp.GetPixel($x, $y)
  $pa[$x,$y] = $c.A
  $bi = 0; $bd = [long]::MaxValue
  for ($a = 0; $a -lt 4; $a++) {
    $d = [long]($c.R-$invpal[$a][0])*($c.R-$invpal[$a][0]) + [long]($c.G-$invpal[$a][1])*($c.G-$invpal[$a][1]) + [long]($c.B-$invpal[$a][2])*($c.B-$invpal[$a][2])
    if ($d -lt $bd) { $bd = $d; $bi = $a }
  }
  $pq[$x,$y] = [byte]$bi
} }
$bmp.Dispose()

$til = [DV]::DecodePic("$src\INVTIL2.PIC")
$msk = [DV]::DecodePic("$src\INVMSK2.PIC")
$cx = 135; $cy = 108
# clear the whole cell (45x54) on both sheets
for ($y = 0; $y -lt 54; $y++) { for ($x = 0; $x -lt 45; $x++) { $til[($cx+$x),($cy+$y)] = 0 } }
for ($y = 0; $y -lt 40; $y++) { for ($x = 0; $x -lt 45; $x++) { $msk[($cx+$x),($cy+$y)] = 0 } }
# art centered in the 45x40 icon area
$ox = $cx + [int]((45 - $pw) / 2); $oy = $cy + [int]((40 - $ph) / 2)
for ($y = 0; $y -lt $ph; $y++) { for ($x = 0; $x -lt $pw; $x++) {
  if ($pa[$x,$y] -ge 128) {
    $til[($ox+$x),($oy+$y)] = $pq[$x,$y]
    $msk[($ox+$x),($oy+$y)] = 3
  }
} }
# label "Pulley" in font2, colour sampled from an existing label
# font loader (same format as addtile37)
$lines = @()
foreach ($l in (Get-Content "$src\font.txt")) { $t = $l.Trim(); if ($t.Length -gt 0 -and -not $t.StartsWith('#')) { $lines += $t } }
$fh = [int]$lines[0]
$font = @{}
$i = 1
while ($i + 1 + $fh -le $lines.Count) {
  $code = [int]$lines[$i]; $w = [int]$lines[$i+1]
  $rows = @()
  for ($r = 0; $r -lt $fh; $r++) { $rows += $lines[$i+2+$r].PadRight($w, '0') }
  $font[[char]$code] = ,$rows + $w
  $i += 2 + $fh
}
function TextW([string]$s) { $t = 0; foreach ($ch in $s.ToCharArray()) { if ($font.ContainsKey($ch)) { $t += $font[$ch][1] + 1 } else { $t += 3 } }; if ($t -gt 0) { $t - 1 } else { 0 } }
# label colour: sample the "Unreadable formula" label (cell x90,y108, rows 40-52)
$cnt = @(0,0,0,0)
for ($y = 148; $y -le 160; $y++) { for ($x = 92; $x -le 132; $x++) { $cnt[$til[$x,$y]]++ } }
$col = 1; for ($a = 2; $a -lt 4; $a++) { if ($cnt[$a] -gt $cnt[$col]) { $col = $a } }
Write-Output "label colour attr=$col fonth=$fh"
$lw = TextW 'Pulley'
$lx = $cx + 2 + [int]((41 - $lw) / 2); $ly = $cy + 43
foreach ($ch in 'Pulley'.ToCharArray()) {
  if (-not $font.ContainsKey($ch)) { $lx += 3; continue }
  $rows = $font[$ch][0]; $w = $font[$ch][1]
  for ($r = 0; $r -lt $fh; $r++) { for ($k = 0; $k -lt $w; $k++) {
    if ($rows[$r][$k] -eq '1') { $til[($lx+$k),($ly+$r)] = [byte]$col }
  } }
  $lx += $w + 1
}
[DV]::EncodePic($til, "$src\INVTIL2.PIC", "$src\INVTIL2.PIC")
[DV]::EncodePic($msk, "$src\INVMSK2.PIC", "$src\INVMSK2.PIC")
[DV]::Save($til, 135, 108, 45, 54, 6, "$sp\tile38_preview.png")
[DV]::Save($msk, 135, 108, 45, 40, 6, "$sp\tile38_mask_preview.png")
Write-Output "tile 38 written"

# ---- 4. verification previews ----
$chk = [DV]::DecodePic("$src\ROOM12.PIC")
[DV]::Save($chk, 0, 0, 320, 200, 2, "$sp\room12_pic_check.png")
Write-Output "done"
