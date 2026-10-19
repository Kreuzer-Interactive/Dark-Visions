# man3didle.ps1 - the 3D man's idle and turning clips for the GAME (GAME8.BAS), src\MAN3DI.ANI, from the
# demo's MANIDLE.ANI (tools\man3dfbx.ps1 -Idle -Import <man_idle.fbx>: the breathing loop, the fidgets and
# the two turning steps as bone matrices at 30 fps "time"), made small for the game's far heap:
#   - frames thinned to at least -MinDur thirtieths of a second each (the 486 redraws him a few times a
#     second standing; 4 = 7.5 fps): a frame shorter than that takes the next one's time and drops it
#   - each bone's rotation in signed bytes (x 127; the game multiplies by rmul to get C3DSKIN's x16384),
#     its translation as is (x16 units): 13 bones x (9 bytes + 3 words) = 98 words a frame, not 156
# Format "C3J1": tag, nv, bones (13), clips, rmul; per clip: frames, kind (0 fidget, 1 the breathing loop,
# 2/3 the turning step to his left/right), each frame's time (1/30 s); then per frame 59 words (117
# rotation bytes, bone by bone row by row, and a pad byte) and 39 words (the translations).
# The model must be the game's (MAN3D.MDL: the same vertex count; the bone words are MAN3DW.ANI's).
#   man3didle.ps1 [-In dist\manwalk\MANIDLE.ANI] [-MinDur 4]
# Another character on his own mesh (James v2 in the intro hall): -OutFile src\JAMES3DI.ANI -Walk none (no man's walk to
# match) -BoneWords ("C3J2": after the header his nv bone words, from the C3I1 input -- GAME8 skins him with
# them) -KeepKinds 1 (only the clips of those kinds: 1 = the breathing loop; the first kept must be it)
param(
  [string]$In = "$PSScriptRoot\..\..\dist\manwalk\MANIDLE.ANI",
  [int]$MinDur = 4,
  [string]$OutFile = "$PSScriptRoot\..\MAN3DI.ANI",
  [string]$Walk = "$PSScriptRoot\..\MAN3DW.ANI",
  [int[]]$KeepKinds = @(),
  [switch]$BoneWords
)
$ErrorActionPreference = 'Stop'
$src = (Resolve-Path "$PSScriptRoot\..").Path
$b = [IO.File]::ReadAllBytes((Resolve-Path $In).Path); $p = 0
function I16 { $v = [BitConverter]::ToInt16($b, $script:p); $script:p += 2; $v }
if ([Text.Encoding]::ASCII.GetString($b, 0, 4) -ne 'C3I1') { throw "$In is not a C3I1 file" }
$p = 4; $nv = I16; $nb = I16; $nc = I16
if ($nb -ne 13) { throw "$nb bones, the game's skin has 13" }
if ($Walk -and $Walk -ne 'none') {
  $w = [IO.File]::ReadAllBytes((Resolve-Path $Walk).Path)
  if ([BitConverter]::ToInt16($w, 4) -ne $nv) { throw "the idle clips are for $nv vertices, MAN3DW.ANI's model has $([BitConverter]::ToInt16($w, 4))" }
  for ($i = 0; $i -lt 2 * $nv; $i++) { if ($b[10 + $i] -ne $w[10 + $i]) { throw 'the idle clips weight the bones differently from MAN3DW.ANI (another model?)' } }
}
$bwords = New-Object byte[] (2 * $nv); [Array]::Copy($b, 10, $bwords, 0, 2 * $nv)
$p += 2 * $nv
$clips = @(); $tot = 0
for ($c = 0; $c -lt $nc; $c++) { $nf = I16; $kind = I16; $d = @(); for ($k = 0; $k -lt $nf; $k++) { $d += I16 }; $clips += ,@{ kind = $kind; durs = $d; first = $tot }; $tot += $nf }
if ($KeepKinds.Count -gt 0) {
  $clips = @($clips | Where-Object { $KeepKinds -contains $_.kind })
  if ($clips.Count -eq 0 -or $clips[0].kind -ne 1) { throw '-KeepKinds: the breathing loop (kind 1) must be kept, and first' }
  $nc = $clips.Count
}
# every frame's 156 words
$fr = New-Object 'int[][]' $tot; $maxr = 0
for ($f = 0; $f -lt $tot; $f++) { $a = New-Object int[] 156; for ($k = 0; $k -lt 156; $k++) { $a[$k] = I16; if (($k % 4) -ne 3 -and [Math]::Abs($a[$k]) -gt $maxr) { $maxr = [Math]::Abs($a[$k]) } }; $fr[$f] = $a }
$rmul = [int][Math]::Ceiling($maxr / 127.0); if ($rmul -lt 129) { $rmul = 129 }
# thinned clips: a frame under MinDur takes the next one's time
$out = New-Object IO.MemoryStream; $bw = New-Object IO.BinaryWriter $out
$bw.Write([Text.Encoding]::ASCII.GetBytes($(if ($BoneWords) { 'C3J2' } else { 'C3J1' }))); $bw.Write([int16]$nv); $bw.Write([int16]13); $bw.Write([int16]$nc); $bw.Write([int16]$rmul)
if ($BoneWords) { $bw.Write($bwords) }
$keep = New-Object 'System.Collections.Generic.List[int]'; $worst = 0; $lines = @()
foreach ($cl in $clips) {
  $kf = New-Object 'System.Collections.Generic.List[int]'; $kd = New-Object 'System.Collections.Generic.List[int]'
  for ($k = 0; $k -lt $cl.durs.Count; $k++) {
    if ($kf.Count -eq 0 -or $kd[$kd.Count - 1] -ge $MinDur) { $kf.Add($cl.first + $k); $kd.Add($cl.durs[$k]) } else { $kd[$kd.Count - 1] += $cl.durs[$k] }
  }
  $bw.Write([int16]$kf.Count); $bw.Write([int16]$cl.kind); foreach ($x in $kd) { $bw.Write([int16]$x) }
  $keep.AddRange($kf); $lines += "kind $($cl.kind): $($cl.durs.Count) -> $($kf.Count) frames, times $($kd -join ' ')"
}
foreach ($f in $keep) {
  $a = $fr[$f]; $rb = New-Object byte[] 118
  for ($bn = 0; $bn -lt 13; $bn++) { for ($r = 0; $r -lt 3; $r++) { for ($k = 0; $k -lt 3; $k++) {
    $v = $a[$bn * 12 + $r * 4 + $k]; $q = [int][Math]::Round($v / $rmul); if ($q -gt 127) { $q = 127 }; if ($q -lt -127) { $q = -127 }
    $e = [Math]::Abs($q * $rmul - $v); if ($e -gt $worst) { $worst = $e }
    $rb[$bn * 9 + $r * 3 + $k] = [byte]($q -band 255)
  } } }
  $bw.Write($rb)
  for ($bn = 0; $bn -lt 13; $bn++) { for ($r = 0; $r -lt 3; $r++) { $bw.Write([int16]$a[$bn * 12 + $r * 4 + 3]) } }
}
$bw.Flush(); $OutFile = Join-Path (Resolve-Path (Split-Path $OutFile)).Path (Split-Path $OutFile -Leaf); [IO.File]::WriteAllBytes($OutFile, $out.ToArray())
$lines
"$tot -> $($keep.Count) frames; rotations x$rmul (worst error $([Math]::Round($worst / 16384.0 * 100, 2))% of a unit vector) -> $OutFile ($((Get-Item $OutFile).Length) B; $($keep.Count * 196) B of it in the game's far heap)"
