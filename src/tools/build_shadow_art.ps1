# build_shadow_art.ps1 -- generate SHADW2.PAC (room2 west shadow-door data)
# from ART\RoomShadow PNGs + ROOM2.PIC. Layout (all INPUT#-readable ints, one
# per line; each array = count line, then count ints incl. the GET w*2/h header):
#   header line: version,tickX,tickY,tickW,tickH,doorX,doorY,shadW,shadH
#   arrays: bgDoor(PSET door-stamp rect), idleTick(PSET), litFull(PSET),
#           clipKeep(AND keep-lit), clipBg(OR restore), shadR(AND), shadL(AND)
# Draw model in-game (GAME2 ShadTick):
#   idle   : PUT bgDoor at door rect (once per room load)
#   lit    : PUT litFull PSET at tick rect
#   shadow : litFull PSET -> shad* AND at (sx,sy) -> clipKeep AND -> clipBg OR
. "$PSScriptRoot\dv_codec.ps1"
$art = "$PSScriptRoot\..\ART\RoomShadow"
$srcDir = "$PSScriptRoot\.."

# placement constants (keep in sync with GAME2.BAS ShadRoom/ShadTick)
$DX = 72; $DY = 126           # door top-left, WDoor is 9x33
$LX = 74; $LY = 150           # light top-left, WFloorLight is 18x14
$TX = 68; $TY = 149; $TW = 34; $TH = 16   # tick rect (68,149)-(101,164)

function LoadSprite($name) {
  $p = "$art\$name.png"; $sz = [DV]::PngSize($p)
  $al = New-Object 'byte[,]' $sz[0], $sz[1]
  $px = [DV]::QuantPng($p, $al)
  @{ w = $sz[0]; h = $sz[1]; px = $px; al = $al }
}
$door = LoadSprite 'WDoor'; $light = LoadSprite 'WFloorLight'
$shL = LoadSprite 'WSiloShadowL'; $shR = LoadSprite 'WSiloShadowR'
$room = [DV]::DecodePic("$srcDir\ROOM2.PIC")

# door opacity + art-with-door composite
$doorOp = New-Object 'bool[,]' 320, 200
$artDoor = $room.Clone()
for ($y = 0; $y -lt $door.h; $y++) { for ($x = 0; $x -lt $door.w; $x++) {
  if ($door.al[$x, $y] -gt 127) {
    $doorOp[($DX + $x), ($DY + $y)] = $true
    $artDoor[($DX + $x), ($DY + $y)] = $door.px[$x, $y] } } }

# carved light mask: gray light px, minus baked blue (exit arrow), minus door
$kept = New-Object 'bool[,]' 320, 200
for ($y = 0; $y -lt $light.h; $y++) { for ($x = 0; $x -lt $light.w; $x++) {
  $sx = $LX + $x; $sy = $LY + $y
  if ($light.px[$x, $y] -eq 1 -and $room[$sx, $sy] -ne 2 -and -not $doorOp[$sx, $sy]) {
    $kept[$sx, $sy] = $true } } }

# lit composite = art+door with light gray at kept px
$litArt = $artDoor.Clone()
for ($y = 0; $y -lt 200; $y++) { for ($x = 0; $x -lt 320; $x++) {
  if ($kept[$x, $y]) { $litArt[$x, $y] = 1 } } }

# crop helpers: build w*h byte[,] views for FrameInts
function CropPx($src, $x0, $y0, $w, $h) {
  $o = New-Object 'byte[,]' $w, $h
  for ($y = 0; $y -lt $h; $y++) { for ($x = 0; $x -lt $w; $x++) { $o[$x, $y] = $src[($x0 + $x), ($y0 + $y)] } }
  , $o
}
function CropAlpha($boolSrc, $x0, $y0, $w, $h, $invert) {
  $o = New-Object 'byte[,]' $w, $h
  for ($y = 0; $y -lt $h; $y++) { for ($x = 0; $x -lt $w; $x++) {
    $v = $boolSrc[($x0 + $x), ($y0 + $y)]; if ($invert) { $v = -not $v }
    $o[$x, $y] = if ($v) { 255 } else { 0 } } }
  , $o
}

$opaque = $null  # FrameInts treats null alpha as fully opaque
$bgDoor  = [DV]::FrameInts((CropPx $artDoor $DX $DY $door.w $door.h), $opaque, $door.w, $door.h, $false)
$idle    = [DV]::FrameInts((CropPx $artDoor $TX $TY $TW $TH), $opaque, $TW, $TH, $false)
$lit     = [DV]::FrameInts((CropPx $litArt $TX $TY $TW $TH), $opaque, $TW, $TH, $false)
# clipKeep: AND array with 3 at kept px (mask=true maps opaque->0, so invert)
$keep    = [DV]::FrameInts((CropPx $artDoor $TX $TY $TW $TH), (CropAlpha $kept $TX $TY $TW $TH $true), $TW, $TH, $true)
# clipBg: OR array = art+door outside kept, 0 at kept (alpha opaque where NOT kept)
$clipBg  = [DV]::FrameInts((CropPx $artDoor $TX $TY $TW $TH), (CropAlpha $kept $TX $TY $TW $TH $true), $TW, $TH, $false)
# shadows: AND arrays, 0 at silhouette (opaque), 3 elsewhere
function SilAlpha($sp) {
  $o = New-Object 'byte[,]' $sp.w, $sp.h
  for ($y = 0; $y -lt $sp.h; $y++) { for ($x = 0; $x -lt $sp.w; $x++) {
    $o[$x, $y] = if ($sp.al[$x, $y] -gt 127) { 255 } else { 0 } } }
  , $o
}
$shRi = [DV]::FrameInts($shR.px, (SilAlpha $shR), $shR.w, $shR.h, $true)
$shLi = [DV]::FrameInts($shL.px, (SilAlpha $shL), $shL.w, $shL.h, $true)

$sb = New-Object System.Text.StringBuilder
[void]$sb.Append("1,$TX,$TY,$TW,$TH,$DX,$DY,$($shR.w),$($shR.h)`r`n")
foreach ($arr in @(,$bgDoor) + @(,$idle) + @(,$lit) + @(,$keep) + @(,$clipBg) + @(,$shRi) + @(,$shLi)) {
  [void]$sb.Append("$($arr.Length)`r`n")
  foreach ($v in $arr) { [void]$sb.Append("$v`r`n") }
}
[System.IO.File]::WriteAllText("$srcDir\SHADW2.PAC", $sb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host ("SHADW2.PAC written: bgDoor=$($bgDoor.Length) idle=$($idle.Length) lit=$($lit.Length) keep=$($keep.Length) clipBg=$($clipBg.Length) shadR=$($shRi.Length) shadL=$($shLi.Length)")
