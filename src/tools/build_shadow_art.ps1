# build_shadow_art.ps1 -- generate SHADW2.PAC v6: killer-warning watchers for
# EVERY door in the mansion whose destination room ever appears in the killer
# schedule. Art per door picked by the exit arrow's POSITION (left wall = W
# set, right = E, back = N, bottom = S); placements are offsets from the
# arrow anchor, calibrated on room2's hand-tuned pilot values.
# Format v6 (INPUT#-readable):
#   file header: 6,nInstances
#   per instance:
#     header: room,TX,TY,TW,TH,Ax,YLo,Dp,Mir,Axs,sbw,sph,dst
#     sections (count line then count ints): idle, lit, keep, clipBg
#       (raw rect rows, rbytes = TW\4), shUp[4 shifted], shDn[4 shifted]
# Placement heuristics (arrow cluster: cx = centroid x, aTop = min y):
#   W: LX=cx-5  LY=aTop+2 | E: LX=cx-12 LY=aTop+2
#   N: LX=cx-12 LY=aTop+1 | S: LX=cx-18 LY=aTop-4
# Rect/motion offsets per orientation come from the room2 pilot tuning.
. "$PSScriptRoot\dv_codec.ps1"
$art = "$PSScriptRoot\..\ART\RoomShadow"
$srcDir = "$PSScriptRoot\.."

# ---- door table: room, arrow anchor (cx, aTop), orientation, destination --
# (arrow anchors extracted from each ROOMn.PAC's walkout hotpoints; only
# doors whose destination is ever killer-hot. room2's four keep their
# hand-tuned exact placements via LX/LY overrides.)
$doors = @(
  @{ rm='room2';  o='W'; LX=73;  LY=152; DST='room8'  },
  @{ rm='room2';  o='E'; LX=212; LY=152; DST='room3'  },
  @{ rm='room2';  o='N'; LX=138; LY=135; DST='room6'  },
  @{ rm='room2';  o='S'; LX=134; LY=170; DST='room1'  },
  @{ rm='room1';  o='E'; cx=222; aTop=150; DST='room2'  },
  @{ rm='room3';  o='S'; cx=152; aTop=174; DST='room5'  },
  @{ rm='room3';  o='N'; cx=150; aTop=134; DST='room4'  },
  @{ rm='room3';  o='W'; cx=78;  aTop=150; DST='room2'  },
  @{ rm='room6';  o='S'; cx=148; aTop=170; DST='room2'  },
  @{ rm='room6';  o='W'; cx=80;  aTop=154; DST='room7'  },
  @{ rm='room7';  o='E'; cx=224; aTop=150; DST='room6'  },
  @{ rm='room7';  o='N'; cx=153; aTop=126; DST='room11' },
  # room8 W->room9 REMOVED: the watcher rect overlaps the RM8CLOCK anims
  # (clock slide + passage states at 73..81,125..159) and stamps them out.
  # Consequence: entering the Dungeon from here is unwarned while it's hot.
  @{ rm='room8';  o='E'; cx=220; aTop=150; DST='room2'  },
  @{ rm='room9';  o='E'; cx=220; aTop=150; DST='room8'  },
  @{ rm='room9';  o='S'; cx=150; aTop=166; DST='room10' },
  @{ rm='room10'; o='N'; cx=152; aTop=134; DST='room9'  },
  @{ rm='room11'; o='E'; cx=228; aTop=162; DST='room7'  }
)

$oriArt = @{
  W = @{ light='WLight'; shUp='WSHadowUp'; shDn='WSHadowDown' }
  E = @{ light='ELight'; shUp='EShadowUp'; shDn='EShadowDown' }
  N = @{ light='NLight'; shUp='NShadowR'; shDn='NShadowL' }
  S = @{ light='SLight'; shUp='SShadowR'; shDn='SShadowL' }
}
function OriGeom($o, $LX, $LY) {
  switch ($o) {
    'W' { @{ TX=$LX-25; TY=$LY-18; TW=56; TH=34; AX=$LX-23; YLO=$LY-2;  DP=16; MIR=0; AXS=0 } }
    'E' { @{ TX=$LX-8;  TY=$LY-18; TW=56; TH=34; AX=$LX+19; YLO=$LY-2;  DP=16; MIR=1; AXS=0 } }
    'N' { @{ TX=$LX-18; TY=$LY-13; TW=64; TH=31; AX=$LX-17; YLO=$LY-12; DP=41; MIR=0; AXS=1 } }
    'S' { @{ TX=$LX-26; TY=$LY;    TW=88; TH=20; AX=$LX-24; YLO=$LY+3;  DP=60; MIR=1; AXS=1 } }
  }
}
function OriLight($o, $cx, $aTop) {
  switch ($o) {
    'W' { @{ LX=$cx-5;  LY=$aTop+2 } }
    'E' { @{ LX=$cx-12; LY=$aTop+2 } }
    'N' { @{ LX=$cx-12; LY=$aTop+1 } }
    'S' { @{ LX=$cx-18; LY=$aTop-4 } }
  }
}

function LoadSprite($name) {
  $p = "$art\$name.png"; $sz = [DV]::PngSize($p)
  $al = New-Object 'byte[,]' $sz[0], $sz[1]
  $px = [DV]::QuantPng($p, $al)
  @{ w = $sz[0]; h = $sz[1]; px = $px; al = $al }
}
function PackRect($src, $x0, $y0, $w, $h) {
  $rb = [int]($w / 4)
  $bytes = New-Object 'byte[]' ($rb * $h)
  for ($y = 0; $y -lt $h; $y++) { for ($x = 0; $x -lt $w; $x++) {
    $bi = $y * $rb + [int][math]::Floor($x / 4)
    $sh = 6 - 2 * ($x % 4)
    $bytes[$bi] = $bytes[$bi] -bor (($src[($x0 + $x), ($y0 + $y)] -band 3) -shl $sh)
  } }
  , $bytes
}
function PackMaskShift($sp, $shift, $sbw) {
  $bytes = New-Object 'byte[]' ($sbw * $sp.h)
  for ($i = 0; $i -lt $bytes.Length; $i++) { $bytes[$i] = 255 }
  for ($y = 0; $y -lt $sp.h; $y++) { for ($x = 0; $x -lt $sp.w; $x++) {
    if ($sp.al[$x, $y] -gt 127) {
      $xx = $x + $shift
      $bi = $y * $sbw + [int][math]::Floor($xx / 4)
      $sh = 6 - 2 * ($xx % 4)
      $bytes[$bi] = $bytes[$bi] -band (-bnot (3 -shl $sh))
    }
  } }
  , $bytes
}
function BytesToInts([byte[]]$bytes, [byte]$padByte) {
  $n = $bytes.Length
  if ($n % 2 -eq 1) { $bytes = $bytes + @($padByte); $n++ }
  $ints = New-Object 'int[]' ($n / 2)
  for ($i = 0; $i -lt $ints.Length; $i++) {
    # [int] cast is load-bearing: -shl on a [byte] operand stays byte-typed and
    # a <<8 wraps to 0, silently discarding every high byte (4px black bars in game)
    $v = $bytes[$i * 2] -bor ([int]$bytes[$i * 2 + 1] -shl 8)
    if ($v -gt 32767) { $v = $v - 65536 }
    $ints[$i] = $v
  }
  , $ints
}

$sprites = @{}
foreach ($o in 'W','E','N','S') {
  $sprites[$o] = @{
    sU = LoadSprite $oriArt[$o].shUp
    sD = LoadSprite $oriArt[$o].shDn
    light = LoadSprite $oriArt[$o].light
  }
}
$rooms = @{}

$sb = New-Object System.Text.StringBuilder
[void]$sb.Append("6,$($doors.Count)`r`n")
$grand = 0
function EmitSection($ints) {
  [void]$script:sb.Append("$($ints.Length)`r`n")
  foreach ($v in $ints) { [void]$script:sb.Append("$v`r`n") }
  $script:grand += $ints.Length
}
foreach ($d in $doors) {
  if (-not $rooms.ContainsKey($d.rm)) {
    $n = $d.rm -replace 'room',''
    $rooms[$d.rm] = [DV]::DecodePic("$srcDir\ROOM$n.PIC")
  }
  $room = $rooms[$d.rm]
  $o = $d.o
  if ($d.ContainsKey('LX')) { $LX = $d.LX; $LY = $d.LY }
  else { $l = OriLight $o $d.cx $d.aTop; $LX = $l.LX; $LY = $l.LY }
  $g = OriGeom $o $LX $LY
  # byte-align the rect (keep right-edge coverage)
  $TXa = [int][math]::Floor($g.TX / 4) * 4
  $TWa = $g.TW + ($g.TX - $TXa)
  if ($TWa % 4 -ne 0) { $TWa = $TWa + (4 - $TWa % 4) }
  $sU = $sprites[$o].sU; $sD = $sprites[$o].sD; $light = $sprites[$o].light
  $sbw = [int][math]::Ceiling(($sU.w + 3) / 4)
  # light mask: gray px minus this room's baked blue arrow px
  $kept = New-Object 'bool[,]' 320, 200
  for ($y = 0; $y -lt $light.h; $y++) { for ($x = 0; $x -lt $light.w; $x++) {
    $sx = $LX + $x; $sy = $LY + $y
    if ($sx -ge 0 -and $sx -lt 320 -and $sy -ge 0 -and $sy -lt 200) {
      if ($light.px[$x, $y] -eq 1 -and $room[$sx, $sy] -ne 2) { $kept[$sx, $sy] = $true }
    } } }
  $litArt = $room.Clone()
  $keepM = New-Object 'byte[,]' 320, 200
  $clipA = $room.Clone()
  for ($y = 0; $y -lt 200; $y++) { for ($x = 0; $x -lt 320; $x++) {
    if ($kept[$x, $y]) { $litArt[$x, $y] = 1; $keepM[$x, $y] = 3; $clipA[$x, $y] = 0 } } }
  [void]$sb.Append("$($d.rm),$TXa,$($g.TY),$TWa,$($g.TH),$($g.AX),$($g.YLO),$($g.DP),$($g.MIR),$($g.AXS),$sbw,$($sU.h),$($d.DST)`r`n")
  EmitSection (BytesToInts (PackRect $room  $TXa $g.TY $TWa $g.TH) 0)
  EmitSection (BytesToInts (PackRect $litArt $TXa $g.TY $TWa $g.TH) 0)
  EmitSection (BytesToInts (PackRect $keepM $TXa $g.TY $TWa $g.TH) 0)
  EmitSection (BytesToInts (PackRect $clipA $TXa $g.TY $TWa $g.TH) 0)
  foreach ($sp in @($sU, $sD)) {
    $all = New-Object System.Collections.Generic.List[int]
    for ($v = 0; $v -lt 4; $v++) {
      $ints = BytesToInts (PackMaskShift $sp $v $sbw) 255
      foreach ($x in $ints) { $all.Add($x) }
    }
    EmitSection $all.ToArray()
  }
  Write-Host ("{0} {1} light=({2},{3}) rect=({4},{5}) {6}x{7} dst={8}" -f $d.rm, $o, $LX, $LY, $TXa, $g.TY, $TWa, $g.TH, $d.DST)
}
[System.IO.File]::WriteAllText("$srcDir\SHADW2.PAC", $sb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host "SHADW2.PAC v6: $($doors.Count) instances, total ints=$grand"
