# car3dcnv.ps1 - converts src\ART\Car3d\Car3d.3ds + Texture.png into the files the
# QB/uGL renderer loads:
#   src\CAR3D.MDL  "C3D2", nv%,np%,flags% (bit 0 = unlit) ; nv x {x,y,z,u,v single} ;
#                  np x {a,b,c,d,ci int} (d = -1 for a triangle, else a quad a-b-c-d) ; np x {nx,ny,nz single}
#                  (Y-up, centred on the bounding box, outward normals, v flipped for top-down
#                  textures; ci = texture colour index 0..5 sampled at the face's UV centroid, for
#                  the flat-shaded FPU-free renderer)
#   src\CAR3D.BMP  W x (W*8) 8-bit BMP (W = the texture's size, 64 or 128): the texture stacked 8
#                  times, band b remapped to palette indices 16+b*29+c (c = texture colour, up to
#                  29 of them) with brightness rising with b. Palette 0..3 = the carr.pic CGA
#                  colours (black, green, light cyan, brown), 255 = the transparent key.
#                  -Unlit: one band, up to 239 colours, lighting painted into the texture.
# Run: powershell -ExecutionPolicy Bypass -File src\tools\car3dcnv.ps1
param(
  [string]$Src = "$PSScriptRoot\..\ART\Car3d",
  [string]$Out = "$PSScriptRoot\..",
  [string]$Model = "",                 # the .3ds inside $Src; default = the newest one there
  [string]$Texture = "Texture.png",   # the texture file inside $Src
  [string]$Backdrop = "",             # a painted 320x200 backdrop (<= 16 colours) -> CARROAD.BMP, replaces the carr.pic composition
  [switch]$FlipU,     # mirror the texture left-right (u -> 1-u) if the unwrap was made that way
  [switch]$FlipV,     # do NOT flip v: the default turns 3DS's bottom-up v into top-down rows
  [switch]$Unlit,     # lighting painted into the texture: up to 239 colours, no shade bands, renderer skips lighting
  [switch]$KeepHidden # keep faces whose UV area is entirely transparent (they are dropped by default)
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

# ---------- texture ----------
$img = [System.Drawing.Bitmap]::FromFile("$Src\$Texture")
$TW = $img.Width
if($img.Height -ne $TW -or ($TW -ne 64 -and $TW -ne 128)){ throw "texture must be 64x64 or 128x128 (got $($img.Width)x$($img.Height))" }
$bands = if($Unlit){1}else{8}
$cpb = [Math]::Floor(238 / $bands)      # colours per band: palette 16..253 is shared by the bands (254 = the renderer's ink mark)
$cols = @{}; $list = New-Object System.Collections.ArrayList
[void]$list.Add(@(0,0,0)); $cols["0,0,0"]=0        # colour 0 = black (also transparent)
$idx = New-Object byte[] ($TW*$TW)
for($y=0;$y -lt $TW;$y++){ for($x=0;$x -lt $TW;$x++){
  $c=$img.GetPixel($x,$y); $k="$($c.R),$($c.G),$($c.B)"
  if($c.A -lt 128){ $ci=255 }        # transparent texel: palette index 255 = the renderer's colour key
  elseif($cols.ContainsKey($k)){ $ci=$cols[$k] }
  else { if($list.Count -ge $cpb){ throw "more than $cpb texture colours" }; $ci=$list.Count; [void]$list.Add(@($c.R,$c.G,$c.B)); $cols[$k]=$ci }
  $idx[$y*$TW+$x]=$ci } }
"texture colours: $($list.Count)"

# ---------- 3DS ----------
if(-not $Model){ $Model = (Get-ChildItem "$Src\*.3ds" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).Name }
"model: $Model ($((Get-Item "$Src\$Model").LastWriteTime.ToString('MM-dd HH:mm')))"
$b = [IO.File]::ReadAllBytes("$Src\$Model")
function U16($o){ [BitConverter]::ToUInt16($b,$o) }
function U32($o){ [BitConverter]::ToUInt32($b,$o) }
function F32($o){ [BitConverter]::ToSingle($b,$o) }
# every mesh object in the file is merged (Max writes each object as its own 0x4000 block,
# e.g. a mirrored lamp made as a separate object); vertices are world space in 3DS
$VX=New-Object 'System.Collections.Generic.List[single]'; $VY=New-Object 'System.Collections.Generic.List[single]'; $VZ=New-Object 'System.Collections.Generic.List[single]'
$TU=New-Object 'System.Collections.Generic.List[single]'; $TV=New-Object 'System.Collections.Generic.List[single]'
$FA=New-Object 'System.Collections.Generic.List[int]'; $FB=New-Object 'System.Collections.Generic.List[int]'; $FC=New-Object 'System.Collections.Generic.List[int]'
$o=0; $base=0; $objs=@()
while($o -lt $b.Length){
  $id=U16 $o; $len=U32 ($o+2)
  if($id -in 0x4D4D,0x3D3D,0x4100){ $o+=6; continue }
  if($id -eq 0x4000){ $p=$o+6; $name=''; while($b[$p] -ne 0){ $name+=[char]$b[$p]; $p++ }; $o=$p+1; $base=$VX.Count; $objs+=$name; continue }
  if($id -eq 0x4110){ $n=U16 ($o+6)
    # 3DS is Z-up: (x,y,z) -> (x, z, -y) keeps handedness
    for($i=0;$i -lt $n;$i++){ $VX.Add((F32 ($o+8+$i*12))); $VY.Add((F32 ($o+16+$i*12))); $VZ.Add(-(F32 ($o+12+$i*12))); $TU.Add(0); $TV.Add(0) } }
  elseif($id -eq 0x4140){ $n=U16 ($o+6)
    for($i=0;$i -lt $n -and ($base+$i) -lt $VX.Count;$i++){ $uu=F32 ($o+8+$i*8); $vv=F32 ($o+12+$i*8)
      $TU[$base+$i] = if($FlipU){1-$uu}else{$uu}
      $TV[$base+$i] = if($FlipV){$vv}else{1-$vv} } }
  elseif($id -eq 0x4120){ $n=U16 ($o+6)
    for($i=0;$i -lt $n;$i++){ $FA.Add($base+(U16 ($o+8+$i*8))); $FB.Add($base+(U16 ($o+10+$i*8))); $FC.Add($base+(U16 ($o+12+$i*8))) } }
  $o+=$len
}
$nv=$VX.Count; $nf=$FA.Count
if($nv -eq 0 -or $nf -eq 0){ throw "no mesh chunks found" }
"objects: $($objs -join ', ') -> $nv vertices, $nf faces"
$vx=$VX.ToArray(); $vy=$VY.ToArray(); $vz=$VZ.ToArray(); $tu=$TU.ToArray(); $tv=$TV.ToArray()
# centre on the bounding box
$cx=(($vx|Measure -Min).Minimum+($vx|Measure -Max).Maximum)/2
$cy=(($vy|Measure -Min).Minimum+($vy|Measure -Max).Maximum)/2
$cz=(($vz|Measure -Min).Minimum+($vz|Measure -Max).Maximum)/2
for($i=0;$i -lt $nv;$i++){ $vx[$i]-=$cx; $vy[$i]-=$cy; $vz[$i]-=$cz }
$fa=$FA.ToArray(); $fb=$FB.ToArray(); $fc=$FC.ToArray()
# normals; flip the winding if most of them point inward
function Norm($i){
  $a=$fa[$i];$bb=$fb[$i];$c=$fc[$i]
  $ux=$vx[$bb]-$vx[$a];$uy=$vy[$bb]-$vy[$a];$uz=$vz[$bb]-$vz[$a]
  $wx=$vx[$c]-$vx[$a];$wy=$vy[$c]-$vy[$a];$wz=$vz[$c]-$vz[$a]
  ,@(($uy*$wz-$uz*$wy),($uz*$wx-$ux*$wz),($ux*$wy-$uy*$wx))
}
$inward=0
for($i=0;$i -lt $nf;$i++){ $n=Norm $i; $a=$fa[$i]; $mx=($vx[$a]+$vx[$fb[$i]]+$vx[$fc[$i]])/3; $my=($vy[$a]+$vy[$fb[$i]]+$vy[$fc[$i]])/3; $mz=($vz[$a]+$vz[$fb[$i]]+$vz[$fc[$i]])/3
  if(($n[0]*$mx+$n[1]*$my+$n[2]*$mz) -lt 0){$inward++} }
$flip = $inward -gt $nf/2
if($flip){ for($i=0;$i -lt $nf;$i++){ $t=$fb[$i]; $fb[$i]=$fc[$i]; $fc[$i]=$t } }
$nx = New-Object single[] $nf; $ny = New-Object single[] $nf; $nz = New-Object single[] $nf
for($i=0;$i -lt $nf;$i++){ $n=Norm $i; $l=[Math]::Sqrt($n[0]*$n[0]+$n[1]*$n[1]+$n[2]*$n[2]); if($l -eq 0){$l=1}; $nx[$i]=$n[0]/$l; $ny[$i]=$n[1]/$l; $nz[$i]=$n[2]/$l }
# per-face colour: the texture sampled over the face's UV triangle (a 6x6 barycentric
# grid), transparent texels ignored, the most frequent colour wins; a face that only
# covers transparent texels gets the model's most common colour
$opaque = New-Object byte[] ($TW*$TW)
for($y=0;$y -lt $TW;$y++){ for($x=0;$x -lt $TW;$x++){ $opaque[$y*$TW+$x] = [byte]([int]($img.GetPixel($x,$y).A -ge 128)) } }
$fci = New-Object int[] $nf; $hist = @{}; $none = @()
for($i=0;$i -lt $nf;$i++){
  $cnt = @{}
  for($s=0;$s -le 6;$s++){ for($t=0;$t -le 6-$s;$t++){
    $w1=$s/6; $w2=$t/6; $w0=1-$w1-$w2
    $u=$w0*$tu[$fa[$i]]+$w1*$tu[$fb[$i]]+$w2*$tu[$fc[$i]]; $v=$w0*$tv[$fa[$i]]+$w1*$tv[$fb[$i]]+$w2*$tv[$fc[$i]]
    $px=[Math]::Min($TW-1,[Math]::Max(0,[int][Math]::Floor($u*$TW))); $py=[Math]::Min($TW-1,[Math]::Max(0,[int][Math]::Floor($v*$TW)))
    if($opaque[$py*$TW+$px] -and $idx[$py*$TW+$px] -ne 255){ $c=$idx[$py*$TW+$px]; $cnt[$c]=1+$cnt[$c] } } }
  if($cnt.Count){ $fci[$i] = ($cnt.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key } else { $fci[$i] = -1; $none += $i }
  if($fci[$i] -ge 0){ $hist[$fci[$i]]=1+$hist[$fci[$i]] } }
$common = ($hist.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key
foreach($i in $none){ $fci[$i] = $common; $hist[$common]++ }
if($none.Count -and -not $KeepHidden){
  # a face whose UV triangle holds no opaque texel can never put a pixel on screen,
  # but the renderer would still walk every scanline of it: drop it
  $keep = @(0..($nf-1) | Where-Object { $none -notcontains $_ })
  $fa=[int[]]@($keep | % { $fa[$_] }); $fb=[int[]]@($keep | % { $fb[$_] }); $fc=[int[]]@($keep | % { $fc[$_] })
  $nx=[single[]]@($keep | % { $nx[$_] }); $ny=[single[]]@($keep | % { $ny[$_] }); $nz=[single[]]@($keep | % { $nz[$_] })
  $fci=[int[]]@($keep | % { $fci[$_] })
  "faces with no opaque texel: $($none.Count) of $nf dropped (never visible; -KeepHidden keeps them)"
  $nf = $keep.Count
} else { "faces with no opaque texel: $($none.Count) -> colour $common" }

# quads: merge two triangles that share an edge, have the same colour, are coplanar and
# make a convex quad (one uglPolyF call instead of two). Greedy, best coplanarity first.
$edges = @{}      # "lo,hi" -> list of triangle ids
for($i=0;$i -lt $nf;$i++){ foreach($e in @(@($fa[$i],$fb[$i]),@($fb[$i],$fc[$i]),@($fc[$i],$fa[$i]))){ $k="$([Math]::Min($e[0],$e[1])),$([Math]::Max($e[0],$e[1]))"; if(-not $edges[$k]){ $edges[$k]=@() }; $edges[$k]+=$i } }
function Tri($i){ ,@($fa[$i],$fb[$i],$fc[$i]) }
function Convex($q){   # all turns the same way as the polygon normal
  for($k=0;$k -lt 4;$k++){ $p0=$q[$k]; $p1=$q[($k+1)%4]; $p2=$q[($k+2)%4]
    $e1=@(($vx[$p1]-$vx[$p0]),($vy[$p1]-$vy[$p0]),($vz[$p1]-$vz[$p0])); $e2=@(($vx[$p2]-$vx[$p1]),($vy[$p2]-$vy[$p1]),($vz[$p2]-$vz[$p1]))
    $cx=$e1[1]*$e2[2]-$e1[2]*$e2[1]; $cy=$e1[2]*$e2[0]-$e1[0]*$e2[2]; $cz=$e1[0]*$e2[1]-$e1[1]*$e2[0]
    if(($cx*$nx[$q[4]]+$cy*$ny[$q[4]]+$cz*$nz[$q[4]]) -le 0){ return $false } }
  return $true }
$pairs = @()
foreach($k in $edges.Keys){ $l=$edges[$k]; if($l.Count -ne 2){ continue }; $i=$l[0]; $j=$l[1]
  if($fci[$i] -ne $fci[$j]){ continue }
  $d=$nx[$i]*$nx[$j]+$ny[$i]*$ny[$j]+$nz[$i]*$nz[$j]; if($d -lt 0.995){ continue }
  $pairs += [pscustomobject]@{ I=$i; J=$j; D=$d } }
$used = New-Object bool[] $nf; $polys = @()
foreach($p in ($pairs | Sort-Object D -Descending)){ $i=$p.I; $j=$p.J; if($used[$i] -or $used[$j]){ continue }
  $t1=Tri $i; $t2=Tri $j; $q=$null
  for($k=0;$k -lt 3;$k++){ $v0=$t1[$k]; $pp=$t1[($k+1)%3]; $qq=$t1[($k+2)%3]      # shared edge pp,qq of tri1
    for($m=0;$m -lt 3;$m++){ if($t2[$m] -eq $qq -and $t2[($m+1)%3] -eq $pp){ $r=$t2[($m+2)%3]; $q=@($v0,$pp,$r,$qq,$i) } } }
  if($q -and (Convex $q)){ $used[$i]=$true; $used[$j]=$true; $polys += ,@($q[0],$q[1],$q[2],$q[3],$fci[$i],$i) } }
for($i=0;$i -lt $nf;$i++){ if(-not $used[$i]){ $polys += ,@($fa[$i],$fb[$i],$fc[$i],-1,$fci[$i],$i) } }
$np = $polys.Count; $nq = ($polys | ? { $_[3] -ge 0 }).Count

$fs = [IO.File]::Create("$Out\CAR3D.MDL"); $w = New-Object IO.BinaryWriter($fs)
$w.Write([byte[]][char[]]'C3D2'); $w.Write([int16]$nv); $w.Write([int16]$np); $w.Write([int16]([int]$Unlit.IsPresent))
for($i=0;$i -lt $nv;$i++){ $w.Write([single]$vx[$i]);$w.Write([single]$vy[$i]);$w.Write([single]$vz[$i]);$w.Write([single]$tu[$i]);$w.Write([single]$tv[$i]) }
foreach($p in $polys){ $w.Write([int16]$p[0]);$w.Write([int16]$p[1]);$w.Write([int16]$p[2]);$w.Write([int16]$p[3]);$w.Write([int16]$p[4]) }
foreach($p in $polys){ $i=$p[5]; $w.Write([single]$nx[$i]);$w.Write([single]$ny[$i]);$w.Write([single]$nz[$i]) }
$w.Close()
"CAR3D.MDL: $nv verts, $nf triangles -> $np polygons ($nq quads), winding flipped=$flip, extent x $([int](($vx|Measure -Max).Maximum*2)) y $([int](($vy|Measure -Max).Maximum*2)) z $([int](($vz|Measure -Max).Maximum*2))"
"face colours (index=count): " + (($hist.Keys | Sort-Object | % { "$_=$($hist[$_])" }) -join " ")

$pal = New-Object byte[] 1024
function SetPal($i,$r,$g,$bl){ $pal[$i*4]=[byte][Math]::Min(255,$bl); $pal[$i*4+1]=[byte][Math]::Min(255,$g); $pal[$i*4+2]=[byte][Math]::Min(255,$r) }
SetPal 0 0 0 0; SetPal 1 0 170 0; SetPal 2 85 255 255; SetPal 3 170 85 0   # carr.pic CGA palette
SetPal 255 255 0 255                                                         # colour key (never drawn)
for($bd=0;$bd -lt $bands;$bd++){ $sh = if($Unlit){1}else{0.3 + 1.2*$bd/($bands-1)}
  for($ci=0;$ci -lt $list.Count;$ci++){ $c=$list[$ci]; SetPal (16+$bd*$cpb+$ci) ([int]($c[0]*$sh)) ([int]($c[1]*$sh)) ([int]($c[2]*$sh)) } }
$h=$TW*$bands; $pix = New-Object byte[] ($TW*$h)
for($bd=0;$bd -lt $bands;$bd++){ for($y=0;$y -lt $TW;$y++){ for($x=0;$x -lt $TW;$x++){
  $row = $bd*$TW+$y                      # top-down row
  $t = $idx[$y*$TW+$x]; if($t -eq 255){ $pix[(($h-1-$row)*$TW)+$x] = 255 } else { $pix[(($h-1-$row)*$TW)+$x] = [byte](16+$bd*$cpb+$t) } } } }
# ---------- painted backdrop ----------
# its colours take palette slots 0..15; a colour close to one of the four CGA colours gets
# that CGA slot (0 black, 1 green, 2 cyan, 3 brown = the renderer's ink), the rest 4 upward
if($Backdrop){
  $bgi = [System.Drawing.Bitmap]::FromFile("$Src\$Backdrop")
  if($bgi.Width -ne 320 -or $bgi.Height -ne 200){ throw "backdrop must be 320x200 (got $($bgi.Width)x$($bgi.Height))" }
  $cga = @(@(0,0,0),@(0,170,0),@(85,255,255),@(170,85,0))
  $slots = @{}; $bpal = @{}; $next = 4
  $bpix = New-Object byte[] (320*200)
  for($y=0;$y -lt 200;$y++){ for($x=0;$x -lt 320;$x++){ $c=$bgi.GetPixel($x,$y); $k="$($c.R),$($c.G),$($c.B)"
    if(-not $slots.ContainsKey($k)){
      $best=-1; $bd=999
      for($i=0;$i -lt 4;$i++){ if($bpal.ContainsKey($i)){ continue }; $d=[Math]::Abs($c.R-$cga[$i][0])+[Math]::Abs($c.G-$cga[$i][1])+[Math]::Abs($c.B-$cga[$i][2]); if($d -lt $bd){ $bd=$d; $best=$i } }
      if($best -ge 0 -and $bd -le 60){ $idx=$best } else { if($next -gt 15){ throw "backdrop has more than 16 colours" }; $idx=$next; $next++ }
      $slots[$k]=$idx; $bpal[$idx]=@([int]$c.R,[int]$c.G,[int]$c.B) }
    $bpix[(199-$y)*320+$x] = [byte]$slots[$k] } }
  foreach($i in $bpal.Keys){ $c=$bpal[$i]; SetPal $i $c[0] $c[1] $c[2] }
  $fs = [IO.File]::Create("$Out\CARROAD.BMP"); $w = New-Object IO.BinaryWriter($fs)
  $w.Write([byte]66); $w.Write([byte]77); $w.Write([int32](54+1024+$bpix.Length)); $w.Write([int32]0); $w.Write([int32](54+1024))
  $w.Write([int32]40); $w.Write([int32]320); $w.Write([int32]200); $w.Write([int16]1); $w.Write([int16]8); $w.Write([int32]0); $w.Write([int32]$bpix.Length)
  $w.Write([int32]2835); $w.Write([int32]2835); $w.Write([int32]256); $w.Write([int32]0)
  $w.Write($pal); $w.Write($bpix); $w.Close()
  "CARROAD.BMP: $Backdrop, $($slots.Count) colours in palette slots " + (($bpal.Keys | Sort-Object) -join ",")
} elseif(Test-Path "$Out\CARROAD.BMP"){ Remove-Item "$Out\CARROAD.BMP"; "CARROAD.BMP removed (no -Backdrop): the carr.pic composition is back" }

$fs = [IO.File]::Create("$Out\CAR3D.BMP"); $w = New-Object IO.BinaryWriter($fs)
$w.Write([byte]66); $w.Write([byte]77); $w.Write([int32](54+1024+$pix.Length)); $w.Write([int32]0); $w.Write([int32](54+1024))
$w.Write([int32]40); $w.Write([int32]$TW); $w.Write([int32]$h); $w.Write([int16]1); $w.Write([int16]8); $w.Write([int32]0); $w.Write([int32]$pix.Length)
$w.Write([int32]2835); $w.Write([int32]2835); $w.Write([int32]256); $w.Write([int32]0)
$w.Write($pal); $w.Write($pix); $w.Close()
if($Unlit){ "CAR3D.BMP: ${TW}x$h, 8-bit, unlit, $($list.Count) colours (up to $cpb)" } else { "CAR3D.BMP: ${TW}x$h, 8-bit, $bands shade bands, $($list.Count) colours (up to $cpb)" }
