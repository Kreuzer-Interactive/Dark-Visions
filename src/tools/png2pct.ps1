<#
.SYNOPSIS
  PNG -> Dark Visions .PCT sprite (a QuickBASIC SCREEN 1 PUT array as text, one int per line).

.DESCRIPTION
  The game's sprites are 2 bits per pixel PUT arrays: int 0 = width*2 (bits per row),
  int 1 = height, then byte-aligned rows (ceil(width*2/8) bytes each) packed little-endian
  into signed 16-bit ints. This writes that layout as text so GAME*.BAS can INPUT # it.

  Each PNG colour is mapped to an attribute 0-3 with -Map ("RRGGBB=attr" pairs); any other
  colour goes to the nearest mapped colour. Transparent pixels (alpha < 128) become attr 0.
  With -Mask a second file is written in the same layout where transparent pixels are 3
  (AND mask keeps the background) and everything else is 0, for the game's masked PUTs.

  Default map = the intro heads (src/ART/HeadYou.png, HeadJames.png -> HEADYOU.PCT, HEADJAM.PCT):
    000000=0 black, AAAAAA=1 light gray, 0000AA=2 blue, AA5500=3 brown
  GAME6 IntroTalk draws them in mode 13h with attr 1 = the extra light-gray index.

.EXAMPLE
  .\png2pct.ps1 ..\ART\HeadYou.png ..\HEADYOU.PCT -FlipX     # the game shows both heads MIRRORED (you on
  .\png2pct.ps1 ..\ART\HeadJames.png ..\HEADJAM.PCT -FlipX   # the left, James on the right of the dialog)
  .\png2pct.ps1 sprite.png ..\THING.PCT -Mask ..\THING.MSK -Map "000000=0","AAAAAA=1","0000AA=2","AA5500=3"
#>
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$In,
    [Parameter(Mandatory = $true, Position = 1)][string]$Out,
    [string]$Mask = "",
    [string[]]$Map = @("000000=0", "AAAAAA=1", "0000AA=2", "AA5500=3"),
    [switch]$FlipX
)
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Bitmap]::FromFile((Resolve-Path -LiteralPath $In))
# -FlipX mirrors left/right (the intro heads: drawn looking one way, placed on the other side)
if ($FlipX) { $img.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipX) }
$w = $img.Width; $h = $img.Height
if ($w -lt 1 -or $w -gt 320 -or $h -lt 1 -or $h -gt 200) { throw "sprite must fit 320x200 ($w x $h)" }
$cols = @()
foreach ($m in $Map) {
    $k, $a = $m.Split('=')
    $cols += ,@([Convert]::ToInt32($k.Substring(0, 2), 16), [Convert]::ToInt32($k.Substring(2, 2), 16), [Convert]::ToInt32($k.Substring(4, 2), 16), [int]$a)
}
$bpr = [int][Math]::Ceiling(($w * 2) / 8.0)
$pix = New-Object byte[] ($bpr * $h)
$msk = New-Object byte[] ($bpr * $h)
$unmapped = @{}
for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
        $p = $img.GetPixel($x, $y)
        $attr = 0; $mval = 0
        if ($p.A -lt 128) {
            $attr = 0; $mval = 3
        } else {
            $best = -1; $bd = [int]::MaxValue
            foreach ($c in $cols) {
                $d = ($p.R - $c[0]) * ($p.R - $c[0]) + ($p.G - $c[1]) * ($p.G - $c[1]) + ($p.B - $c[2]) * ($p.B - $c[2])
                if ($d -lt $bd) { $bd = $d; $best = $c[3] }
            }
            if ($bd -gt 0) { $unmapped[("{0:X2}{1:X2}{2:X2}" -f $p.R, $p.G, $p.B)] = $best }
            $attr = $best
        }
        # [Math]::Floor, not [int]: PowerShell's [int] cast rounds to nearest
        $i = $y * $bpr + [int][Math]::Floor($x / 4); $sh = 6 - 2 * ($x % 4)
        $pix[$i] = $pix[$i] -bor ($attr -shl $sh)
        $msk[$i] = $msk[$i] -bor ($mval -shl $sh)
    }
}
$img.Dispose()
function Write-Pct($path, [byte[]]$data) {
    $ints = New-Object System.Collections.Generic.List[string]
    $ints.Add([string]($w * 2)); $ints.Add([string]$h)
    for ($i = 0; $i -lt $data.Length; $i += 2) {
        $lo = $data[$i]; $hi = 0; if ($i + 1 -lt $data.Length) { $hi = $data[$i + 1] }
        $v = $lo + $hi * 256; if ($v -gt 32767) { $v -= 65536 }
        $ints.Add([string]$v)
    }
    [IO.File]::WriteAllText($path, (($ints -join "`r`n") + "`r`n"), [Text.Encoding]::ASCII)
    "{0}: {1}x{2}, {3} ints" -f $path, $w, $h, $ints.Count
}
Write-Pct $Out $pix
if ($Mask) { Write-Pct $Mask $msk }
if ($unmapped.Count) { "colours snapped to nearest attr: " + (($unmapped.GetEnumerator() | ForEach-Object { "$($_.Key)->$($_.Value)" }) -join ", ") }
