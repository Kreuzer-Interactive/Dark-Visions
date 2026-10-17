# man3dfbx.ps1 - the 3D man's walk as an FBX you can edit in 3ds Max, and back.
#
#   man3dfbx.ps1                 export: the artist's mesh (src\ART\Man3d\Man3d_v2.fbx) with a skeleton
#                                (13 points in a "Rig" point that carries the mesh's transform), a Skin
#                                modifier (one bone per rigid piece, the knee rings shared) and the keyed
#                                walk (12 frames + the loop key at 12, 30 fps), built by 3ds Max in batch
#                                mode -> src\ART\Man3d\man_walk.max and man_walk.fbx (Max's own exporter,
#                                so Max reads it back as is); Max's skinned mesh is checked against the
#                                rig's frames vertex by vertex
#   man3dfbx.ps1 -Import <fbx>   import: the edited walk, exported from Max as FBX with Bake Animation
#                                on (a key every frame), sampled over its time span (the last frame is
#                                the loop, so 0..12 = 12 frames), each frame's skin evaluated and set on
#                                the ground -> dist\manwalk\MAN3D.ANI for MANWALK; the stride (the cycle's
#                                length, so the planted foot stays put) is measured from the feet
#
#   The vertex order is the one fbx2tds.ps1 + car3dcnv.ps1 make from the same mesh: the import checks
#   the FBX's mesh against the staged CAR3D.MDL vertex by vertex and refuses a mismatch (a changed mesh
#   needs restaging: manwalk.ps1 -Anim <fbx> does both).
#   Options: -Source <fbx> -Mdl <CAR3D.MDL> -Out <file> -Texture <png> -Frames <n> -Cycle <units>
#            -NoGround (keep the file's own height per frame) -Preview <png> (the frames, as man3danim draws them)
param(
  [string]$Import = "",
  [string]$Source = "$PSScriptRoot\..\ART\Man3d\Man3d_v2.fbx",
  [string]$Mdl = "$PSScriptRoot\..\..\dist\manwalk\CAR3D.MDL",
  [string]$Out = "",
  [string]$Texture = "$PSScriptRoot\..\ART\Man3d\man_tex.png",
  [int]$Frames = 0,
  [double]$Cycle = 0,
  [switch]$NoGround,
  [string]$Preview = "",
  [string]$KeysFrom = ""     # export: take the bones' keys from this animated FBX (the artist's edited walk) instead of the keyed walk
)
$ErrorActionPreference = 'Stop'
if (-not ('WalkRig' -as [type])) { Add-Type -Path "$PSScriptRoot\WalkRig.cs" }
if (-not ('FbxScene' -as [type])) { Add-Type -Path "$PSScriptRoot\FbxWalkIO.cs" -ReferencedAssemblies System.IO.Compression }
$Mdl = (Resolve-Path $Mdl).Path

# the MDL rest pose against an FBX mesh split the fbx2tds way: the per-vertex offset (the converter's centring)
function Match($scene, $rig) {
  if ($scene.SplitCP.Count -ne $rig.NV) { throw "the FBX mesh splits into $($scene.SplitCP.Count) vertices, the staged model has $($rig.NV): restage it from this FBX (manwalk.ps1 -Anim <fbx>)" }
  $p0 = $scene.SplitPos[0]; $off = @(($p0[0] - $rig.X[0]), ($p0[2] - $rig.Y[0]), ((-$p0[1]) - $rig.Z[0]))
  $worst = 0.0
  for ($i = 0; $i -lt $rig.NV; $i++) {
    $p = $scene.SplitPos[$i]
    $d = [Math]::Abs($p[0] - $off[0] - $rig.X[$i]) + [Math]::Abs($p[2] - $off[1] - $rig.Y[$i]) + [Math]::Abs(-$p[1] - $off[2] - $rig.Z[$i])
    if ($d -gt $worst) { $worst = $d }
  }
  if ($worst -gt 0.05) { throw "the FBX mesh does not match the staged model (worst vertex off by $([Math]::Round($worst, 3)) units): restage it from this FBX (manwalk.ps1 -Anim <fbx>)" }
  return ,$off
}

if (-not $Import) {
  # ======================================================== export, built by 3ds Max itself
  # (Max's FBX importer does not take a skin's bind matrices from a hand-written file the way its
  # exporter writes them, so the rig is built in Max: the mesh imported, a "Rig" point with the
  # mesh's transform, a point per bone at its joint, a Skin modifier with these weights added in
  # the rest pose, then the walk keyed; Max saves the scene and exports the FBX)
  if (-not $Out) { $Out = "$PSScriptRoot\..\ART\Man3d\man_walk.fbx" }
  $Out = Join-Path (Resolve-Path (Split-Path $Out)).Path (Split-Path $Out -Leaf)
  $maxOut = [IO.Path]::ChangeExtension($Out, '.max')
  $batch = Get-ChildItem 'C:\Program Files\Autodesk\3ds Max *\3dsmaxbatch.exe' -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
  if (-not $batch) { throw "3ds Max (3dsmaxbatch.exe) not found: the export is built by Max" }
  $nf = if ($Frames -gt 0) { $Frames } else { 12 }
  if ($KeysFrom) {
    # the edited walk: its bones by name, their rest offsets (from the skin's bind matrices) and keys
    $KS = [FbxScene]::Load((Resolve-Path $KeysFrom).Path); $KS.FindMesh(); $KS.FindAnim(); $KS.FindSkin()
    $nf = [Math]::Max(1, [int][Math]::Round(($KS.Stop - $KS.Start) / $KS.FrameTicks))
    $kid = @{}; foreach ($kv in $KS.Obj.GetEnumerator()) { if ($kv.Value.Name -eq 'Model') { $kid[[FbxScene]::NameOf($kv.Value)] = $kv.Key } }
    $ktl = @{}; foreach ($c in $KS.Clusters) { $ktl[$c.Name] = $c.TL }
    if (-not $kid.ContainsKey('Rig')) { throw "$KeysFrom has no 'Rig' node: it is not a walk made by man3dfbx.ps1" }
    "keys from $([IO.Path]::GetFileName($KeysFrom)): $nf frames"
  }
  $srcFbx = (Resolve-Path $Source).Path
  $scene = [FbxScene]::Load($srcFbx); $scene.FindMesh(); $scene.Split()
  $rig = [WalkRig]::Load($Mdl); $off = Match $scene $rig
  $rig.Rig(); $rig.Bake($nf)
  # MDL (y up, front -z, centred) -> the mesh's own space (z up): x, -z, y plus the offset
  function ML($p) { return @(($p[0] + $off[0]), (-($p[2] + $off[2])), ($p[1] + $off[1])) }
  $nb = 13; $names = [WalkRig]::BoneName; $par = [WalkRig]::Parent
  $localT = @()
  for ($b = 0; $b -lt $nb; $b++) { $q = ML $rig.Pivot[$b]; if ($par[$b] -lt 0) { $localT += ,$q } else { $pp = ML $rig.Pivot[$par[$b]]; $localT += ,@(($q[0] - $pp[0]), ($q[1] - $pp[1]), ($q[2] - $pp[2])) } }
  $IC = [Globalization.CultureInfo]::InvariantCulture
  function N($v) { ([double]$v).ToString('0.######', $IC) }
  function P3($a) { '[' + (N $a[0]) + ',' + (N $a[1]) + ',' + (N $a[2]) + ']' }
  # per control point: its position (to find Max's vertex) and its bones
  $ncp = $scene.CP.Length / 3
  $cb1 = New-Object int[] $ncp; $cb2 = New-Object int[] $ncp; $cw = New-Object double[] $ncp
  for ($i = 0; $i -lt $ncp; $i++) { $cb1[$i] = -1 }
  for ($i = 0; $i -lt $rig.NV; $i++) { $cp = $scene.SplitCP[$i]; $cb1[$cp] = $rig.B1[$i]; $cb2[$cp] = $rig.B2[$i]; $cw[$cp] = $rig.W1[$i] }
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine("cpPos = #(" + ((0..($ncp - 1) | ForEach-Object { P3 @($scene.CP[$_ * 3], $scene.CP[$_ * 3 + 1], $scene.CP[$_ * 3 + 2]) }) -join ',') + ")")
  [void]$sb.AppendLine("cpB1 = #(" + (($cb1 | ForEach-Object { $_ + 1 }) -join ',') + ")")
  [void]$sb.AppendLine("cpB2 = #(" + (($cb2 | ForEach-Object { $_ + 1 }) -join ',') + ")")
  [void]$sb.AppendLine("cpW = #(" + (($cw | ForEach-Object { N $_ }) -join ',') + ")")
  [void]$sb.AppendLine("boneName = #(" + (($names | ForEach-Object { '"' + $_ + '"' }) -join ',') + ")")
  [void]$sb.AppendLine("boneParent = #(" + (($par | ForEach-Object { $_ + 1 }) -join ',') + ")")
  [void]$sb.AppendLine("boneT = #(" + (($localT | ForEach-Object { P3 $_ }) -join ',') + ")")
  # the keys: per frame, per bone, the local matrix (rows = the axes' images, Max's row-vector form)
  $keys = @()
  if ($KeysFrom) {
    # each bone's key relative to its parent; its translation moved by the change of the joint's rest
    # offset (the new mesh's joints against the walk's), so the skin and the keys agree
    $restOld = @(); $moved = 0.0
    for ($b = 0; $b -lt $nb; $b++) {
      $nm = $names[$b]; if (-not $kid.ContainsKey($nm) -or -not $ktl.ContainsKey($nm)) { throw "the edited walk has no bone $nm" }
      $pg = if ($par[$b] -lt 0) { $KS.Global($kid['Rig'], $KS.Start) } else { $ktl[$names[$par[$b]]] }
      $rl = [M34]::Mul([M34]::Inv($pg), $ktl[$nm]); $restOld += ,@($rl[3], $rl[7], $rl[11])
      $d = [Math]::Abs($rl[3] - $localT[$b][0]) + [Math]::Abs($rl[7] - $localT[$b][1]) + [Math]::Abs($rl[11] - $localT[$b][2]); if ($d -gt $moved) { $moved = $d }
    }
    "joints: the new mesh's against the walk's rest, largest move $([Math]::Round($moved, 3)) units"
    for ($f = 0; $f -lt $nf; $f++) {
      $t = [long]($KS.Start + ($KS.Stop - $KS.Start) * $f / $nf); $row = @()
      for ($b = 0; $b -lt $nb; $b++) {
        $pnode = if ($par[$b] -lt 0) { $kid['Rig'] } else { $kid[$names[$par[$b]]] }
        $m = [M34]::Mul([M34]::Inv($KS.Global($pnode, $t)), $KS.Global($kid[$names[$b]], $t))
        $tt = @(($m[3] - $restOld[$b][0] + $localT[$b][0]), ($m[7] - $restOld[$b][1] + $localT[$b][1]), ($m[11] - $restOld[$b][2] + $localT[$b][2]))
        $row += "(matrix3 " + (P3 @($m[0], $m[4], $m[8])) + " " + (P3 @($m[1], $m[5], $m[9])) + " " + (P3 @($m[2], $m[6], $m[10])) + " " + (P3 $tt) + ")"
      }
      $keys += "#(" + ($row -join ',') + ")"
    }
  } else {
  for ($f = 0; $f -lt $nf; $f++) {
    $A = $rig.Angles($f / $nf); $row = @()
    for ($b = 0; $b -lt $nb; $b++) {
      $pa = $A[$b][0] * [Math]::PI / 180; $ya = $A[$b][1] * [Math]::PI / 180
      $ca = [Math]::Cos($pa); $sa = [Math]::Sin($pa); $cy = [Math]::Cos($ya); $sy = [Math]::Sin($ya)
      # R = Rz(yaw) * Rx(pitch), column-vector; Max rows = R's columns
      $R = @(@($cy, (-$sy * $ca), ($sy * $sa)), @($sy, ($cy * $ca), (-$cy * $sa)), @(0, $sa, $ca))
      $t = $localT[$b]; if ($b -eq 0) { $t = @($t[0], $t[1], ($t[2] + $rig.DY[$f])) }
      $row += "(matrix3 " + (P3 @($R[0][0], $R[1][0], $R[2][0])) + " " + (P3 @($R[0][1], $R[1][1], $R[2][1])) + " " + (P3 @($R[0][2], $R[1][2], $R[2][2])) + " " + (P3 $t) + ")"
    }
    $keys += "#(" + ($row -join ',') + ")"
  }
  }
  [void]$sb.AppendLine("keyM = #(" + ($keys -join ",`n") + ")")
  $tmp = Join-Path $env:TEMP 'man3dfbx_build'; if (-not (Test-Path $tmp)) { New-Item -ItemType Directory $tmp | Out-Null }
  $logf = Join-Path $tmp 'build.txt'; $chk = Join-Path $tmp 'check.txt'
  foreach ($x in $logf, $chk) { if (Test-Path $x) { [IO.File]::Delete($x) } }
  $ms = @"
resetMaxFile #noPrompt
lf = createFile @"$logf"
FBXImporterSetParam "Mode" #create
FBXImporterSetParam "Animation" false
importFile @"$srcFbx" #noPrompt using:FBXIMP
man = undefined
for o in geometry where (classof o == Editable_mesh or classof o == Editable_Poly) do man = o
if man == undefined do ( format "no mesh imported\n" to:lf; close lf; quitMax #noPrompt )
man.name = "man"
$($sb.ToString())
rigNode = Point name:"Rig" size:8 box:true cross:false
rigNode.transform = man.transform
bns = #()
for i = 1 to boneName.count do (
  b = Point name:boneName[i] size:4 cross:true box:false axistripod:true
  p = if boneParent[i] == 0 then rigNode else bns[boneParent[i]]
  b.parent = p
  b.transform = (transMatrix boneT[i]) * p.transform
  append bns b
)
sk = Skin()
addModifier man sk
max modify mode
select man
modPanel.setCurrentObject sk
for i = 1 to bns.count do skinOps.addBone sk bns[i] (if i == bns.count then 1 else 0)
nv = skinOps.GetNumberVertices sk
base = man.baseObject.mesh
cpOf = #()
for v = 1 to nv do (
  pv = getVert base v
  c = 0
  if v <= cpPos.count and distance pv cpPos[v] < 0.001 then c = v else (
    best = 1e9
    for k = 1 to cpPos.count do ( d = distance pv cpPos[k]; if d < best do ( best = d; c = k ) )
  )
  append cpOf c
  if cpB1[c] > 0 do (
    if cpB2[c] == cpB1[c] or cpW[c] >= 1 then skinOps.ReplaceVertexWeights sk v #(cpB1[c]) #(1.0)
    else skinOps.ReplaceVertexWeights sk v #(cpB1[c], cpB2[c]) #(cpW[c], 1.0 - cpW[c])
  )
)
format "skin: % bones, % vertices weighted\n" (skinOps.GetNumberBones sk) nv to:lf
nf = keyM.count
animationRange = interval 0 nf
with animate on (
  for f = 0 to nf do at time f (
    km = keyM[(mod f nf) + 1]
    for i = 1 to bns.count do bns[i].transform = km[i] * bns[i].parent.transform
  )
)
cf = createFile @"$chk"
for f = 0 to nf - 1 do at time f (
  m = snapshotAsMesh man
  inv = inverse man.transform
  for v = 1 to m.numverts do ( q = (getVert m v) * inv; format "% % % % % %\n" f v cpOf[v] q.x q.y q.z to:cf )
  delete m
)
close cf
saveMaxFile @"$maxOut" quiet:true
FBXExporterSetParam "ASCII" false
FBXExporterSetParam "Animation" true
FBXExporterSetParam "BakeAnimation" true
FBXExporterSetParam "BakeFrameStart" 0
FBXExporterSetParam "BakeFrameEnd" nf
FBXExporterSetParam "BakeFrameStep" 1
FBXExporterSetParam "Skin" true
FBXExporterSetParam "Shape" false
exok = exportFile @"$Out" #noPrompt using:FBXEXP
format "saved: %\nexported: %\n" (doesFileExist @"$maxOut") exok to:lf
close lf
"@
  $msf = Join-Path $tmp 'build.ms'
  [IO.File]::WriteAllText($msf, $ms, [Text.Encoding]::ASCII)
  "building in 3ds Max (headless, about half a minute) ..."
  $p = Start-Process -FilePath $batch.FullName -ArgumentList @("`"$msf`"", '-listenerlog', "`"$(Join-Path $tmp 'listener.txt')`"") -PassThru -WindowStyle Hidden
  if (-not $p.WaitForExit(600000)) { $p.Kill(); throw "3ds Max did not finish" }
  if (-not (Test-Path $logf)) { Get-Content (Join-Path $tmp 'listener.txt') | Select-String 'Exception' -Context 0, 3 | Select-Object -First 3 | ForEach-Object { $_.ToString() }; throw "the Max build failed" }
  Get-Content $logf
  if ($KeysFrom) {
    # the rebuilt walk's bones against the edited walk's: every bone's local rotation, every frame
    $N2 = [FbxScene]::Load($Out); $N2.FindMesh(); $N2.FindAnim()
    $nid = @{}; foreach ($kv in $N2.Obj.GetEnumerator()) { if ($kv.Value.Name -eq 'Model') { $nid[[FbxScene]::NameOf($kv.Value)] = $kv.Key } }
    $worst = 0.0
    for ($f = 0; $f -lt $nf; $f++) {
      $t1 = [long]($KS.Start + ($KS.Stop - $KS.Start) * $f / $nf); $t2 = [long]($N2.Start + ($N2.Stop - $N2.Start) * $f / $nf)
      for ($b = 0; $b -lt $nb; $b++) {
        $pa = if ($par[$b] -lt 0) { 'Rig' } else { $names[$par[$b]] }
        $m1 = [M34]::Mul([M34]::Inv($KS.Global($kid[$pa], $t1)), $KS.Global($kid[$names[$b]], $t1))
        $m2 = [M34]::Mul([M34]::Inv($N2.Global($nid[$pa], $t2)), $N2.Global($nid[$names[$b]], $t2))
        foreach ($k in 0, 1, 2, 4, 5, 6, 8, 9, 10) { $d = [Math]::Abs($m1[$k] - $m2[$k]); if ($d -gt $worst) { $worst = $d } }
      }
    }
    "the rebuilt walk's bone rotations against the edited walk's: worst matrix element off by $([Math]::Round($worst, 5))"
    "-> $Out"; "-> $maxOut"
    return
  }
  # Max's own skinning against the rig's frames: every vertex, every frame
  $ref = @{}; for ($f = 0; $f -lt $nf; $f++) { $ref[$f] = @($rig.FX[$f], $rig.FY[$f], $rig.FZ[$f]) }
  $cpToSplit = @{}; for ($i = 0; $i -lt $rig.NV; $i++) { $cp = $scene.SplitCP[$i]; if (-not $cpToSplit.ContainsKey($cp)) { $cpToSplit[$cp] = $i } }
  $worst = 0.0
  foreach ($line in Get-Content $chk) {
    $w = $line.Split(' '); $f = [int]$w[0]; $cp = [int]$w[2] - 1
    $i = $cpToSplit[$cp]; if ($null -eq $i) { continue }
    $x = [double]::Parse($w[3], $IC) - $off[0]; $y = [double]::Parse($w[5], $IC) - $off[1]; $z = -[double]::Parse($w[4], $IC) - $off[2]
    $d = [Math]::Abs($x - $ref[$f][0][$i]) + [Math]::Abs($y - $ref[$f][1][$i]) + [Math]::Abs($z - $ref[$f][2][$i])
    if ($d -gt $worst) { $worst = $d }
  }
  "Max's skinned mesh against the rig's own frames: worst vertex off by $([Math]::Round($worst, 3)) units"
  "-> $Out"
  "-> $maxOut"
  return
}
# ======================================================== import
if (-not $Out) { $Out = Join-Path (Split-Path $Mdl) 'MAN3D.ANI' }
$scene = [FbxScene]::Load((Resolve-Path $Import).Path); $scene.FindMesh(); $scene.Split(); $scene.FindAnim(); $scene.FindSkin()
if ($scene.Clusters.Count -eq 0) { throw "the FBX has no skin (export it from Max with Skins on)" }
$rig = [WalkRig]::Load($Mdl); $off = Match $scene $rig
$span = $scene.Stop - $scene.Start
$nf = if ($Frames -gt 0) { $Frames } else { [Math]::Max(1, [int][Math]::Round($span / $scene.FrameTicks)) }
"fbx: $($scene.Clusters.Count) bones skinned, $(@($scene.Anim.Keys).Count) animated nodes, $nf frames over $([Math]::Round($span / $scene.FrameTicks, 2)) frames of time"
foreach ($n in $scene.Notes) { if ($n -ne 'order') { $n } }
if ($nf -gt 24) { throw "$nf frames: MANWALK takes 24 at most (-Frames resamples)" }
$rig.NF = $nf; $rig.FX = New-Object 'float[][]' $nf; $rig.FY = New-Object 'float[][]' $nf; $rig.FZ = New-Object 'float[][]' $nf
$ymin = $rig.YMin
for ($f = 0; $f -lt $nf; $f++) {
  $t = [long]($scene.Start + $span * $f / $nf)
  $def = $scene.Deform($t)
  $fx = New-Object float[] $rig.NV; $fy = New-Object float[] $rig.NV; $fz = New-Object float[] $rig.NV; $low = 1e9
  for ($i = 0; $i -lt $rig.NV; $i++) { $p = $def[$scene.SplitCP[$i]]; $fx[$i] = [float]($p[0] - $off[0]); $fy[$i] = [float]($p[2] - $off[1]); $fz[$i] = [float](-$p[1] - $off[2]); if ($fy[$i] -lt $low) { $low = $fy[$i] } }
  if (-not $NoGround) { $dy = [float]($ymin - $low); for ($i = 0; $i -lt $rig.NV; $i++) { $fy[$i] += $dy } }
  $rig.FX[$f] = $fx; $rig.FY[$f] = $fy; $rig.FZ[$f] = $fz
}
"skin matrices: $($scene.Convention) convention"
# the stride frame by frame from the planted foot (WalkRig.ComputeStride), or even with -Cycle
if ($Cycle -gt 0) { $rig.SetUniform($Cycle); "stride: given, $Cycle units, even" } else { $rig.ComputeStride() }
$rig.Save($Out)
"-> $Out ($((Get-Item $Out).Length) bytes)"
if ($Preview) {
  # the same strip man3danim.ps1 draws, from these frames
  if (-not ('Man3D' -as [type])) { Add-Type -AssemblyName System.Drawing; Add-Type -Path "$PSScriptRoot\Man3D.cs" -ReferencedAssemblies System.Drawing }
  Add-Type -AssemblyName System.Drawing
  $m = New-Object Man3D ($rig.UPC * 188 / 180), 0
  $img = [System.Drawing.Bitmap]::FromFile((Resolve-Path $Texture).Path)
  $m.TW = $img.Width; $m.Tex = New-Object byte[] ($m.TW * $m.TW); $pal = [Man3D]::Pal
  for ($y = 0; $y -lt $m.TW; $y++) { for ($x = 0; $x -lt $m.TW; $x++) { $c = $img.GetPixel($x, $y); if ($c.A -lt 128) { $m.Tex[$y * $m.TW + $x] = 255; continue }; $best = 0; $bd = 1e9; for ($k = 0; $k -lt $pal.Count; $k++) { $d = [Math]::Abs($pal[$k].R - $c.R) + [Math]::Abs($pal[$k].G - $c.G) + [Math]::Abs($pal[$k].B - $c.B); if ($d -lt $bd) { $bd = $d; $best = $k } }; $m.Tex[$y * $m.TW + $x] = [byte]$best } }
  $img.Dispose()
  for ($i = 0; $i -lt $rig.NV; $i++) { $m.V.Add([float[]]@($rig.X[$i], $rig.Y[$i], $rig.Z[$i])); $m.UV.Add([float[]]@(($rig.U[$i] * $m.TW), ($rig.V[$i] * $m.TW))) }
  foreach ($p in $rig.Polys) { $m.F.Add([int[]]@($p[0], $p[1], $p[2])); if ($p.Count -eq 4) { $m.F.Add([int[]]@($p[0], $p[2], $p[3])) } }
  $W = 70; $H = 120; $big = 3; $cols = $nf + 1
  $sheet = New-Object System.Drawing.Bitmap ($cols * $W * $big), ([int](2 * $H * 1.2 * $big) + 40)
  $g = [System.Drawing.Graphics]::FromImage($sheet); $g.Clear([System.Drawing.Color]::FromArgb(30, 30, 30)); $g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'
  $font = New-Object System.Drawing.Font 'Segoe UI', 9
  for ($f = -1; $f -lt $nf; $f++) {
    for ($i = 0; $i -lt $rig.NV; $i++) { if ($f -lt 0) { $m.V[$i] = [float[]]@($rig.X[$i], $rig.Y[$i], $rig.Z[$i]) } else { $m.V[$i] = [float[]]@($rig.FX[$f][$i], $rig.FY[$f][$i], $rig.FZ[$f][$i]) } }
    foreach ($row in 0, 1) {
      $yaw = if ($row -eq 0) { [Math]::PI / 2 } else { 0.6 }
      $bm = $m.Render($yaw, 150, $W, $H, 160, 1.2, 4, 0)
      $g.DrawImage($bm, ($f + 1) * $W * $big, 20 + $row * ([int]($H * 1.2 * $big) + 10), $bm.Width * $big, $bm.Height * $big); $bm.Dispose()
    }
    $g.DrawString($(if ($f -lt 0) { 'rest' } else { "frame $f" }), $font, [System.Drawing.Brushes]::White, ($f + 1) * $W * $big + 4, 2)
  }
  $g.Dispose(); $sheet.Save($Preview); $sheet.Dispose()
  "preview: $Preview"
}
