# hillpath.ps1 -- the hill drive's waypoints for GAME7.BAS (hillWay DATA) from the
# artist's 3DS scene of the road and the painted road.
#
# The screen path is the artist's: the green guide line of ART\Car3d\hill_guide.png
# (magenta = off the road, black = road, green = where the car's ground centre goes),
# given as -Way "x,y, x,y, ..." from the bottom edge to the front door. Depth and climb
# come from the 3DS scene (ART\Car3d\CarPathScene2.3ds: a road mesh, z up): a camera is
# fitted so the mesh covers the painted road best (the scene's own camera does not frame
# the painting; the 3DS/FBX exports do not carry a Physical Camera's lens anyway), its
# height held at -CamHeight (the fit likes to sit on the road otherwise); each waypoint
# then gets the depth of the road's centre line at the same fraction of the projected
# line's screen length (the hairpin's apex aligned) and the road's climb there. Depths
# are scaled so the car (82.8 units wide) is -CarEndPx wide at the last point.
#
# Prints the DATA lines for GAME7 (count, then x,y,depth,climb per point: screen point,
# game units, tenths of a degree nose up) and draws the path with the car's footprint
# at a few steps over the backdrop (-Out). -Cam "cx,cy,cz,yaw,pitch,f,ox,oy" skips the
# fit (the values a run prints).
#
#   tools\hillpath.ps1                      fit, data, hillpath.png
#   tools\hillpath.ps1 -CarEndPx 12         a smaller car
param(
  [string]$Scene = "$PSScriptRoot\..\ART\Car3d\CarPathScene2.3ds",
  [string]$Guide = "$PSScriptRoot\..\ART\Car3d\hill_guide.png",
  [string]$Backdrop = "$PSScriptRoot\..\ART\Car3d\hill_road.png",
  [string]$Way = '172,199, 194,193, 215,186, 236,179, 252,169, 261,156, 254,147, 242,145, 231,143, 219,141, 208,139, 196,137, 185,135, 174,132, 164,130',
  [double]$CamHeight = 90, [string]$Cam = '', [int]$Iters = 1200,
  [double]$CarEndPx = 15, [int]$Steps = 250, [double]$CarW = 82.8, [double]$CarL = 187.1,
  [string]$Out = "$PSScriptRoot\hillpath.png")
Add-Type -AssemblyName System.Drawing
$cs = @'
using System;
using System.Collections.Generic;
public static class RoadFit2 {
    public static double[] VX, VY, VZ; public static int[] FA, FB, FC;
    public static byte[] Mask; public static int W = 320, H = 200;
    public static double Near = 2.0;
    static byte[] buf = new byte[320 * 200];
    static double[] cxv, cyv, czv;
    static void Norm(double[] v) { double l = Math.Sqrt(v[0]*v[0]+v[1]*v[1]+v[2]*v[2]); v[0]/=l; v[1]/=l; v[2]/=l; }
    static double[] Cross(double[] a, double[] b) { return new double[]{ a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0] }; }
    // p: cx, cy, cz, yaw (from +y toward +x), pitch (up), f (px for the 320 frame), ox, oy
    public static void Basis(double[] p, out double[] C, out double[] R, out double[] U, out double[] F) {
        C = new double[]{ p[0], p[1], p[2] };
        F = new double[]{ Math.Sin(p[3])*Math.Cos(p[4]), Math.Cos(p[3])*Math.Cos(p[4]), Math.Sin(p[4]) };
        Norm(F); R = Cross(F, new double[]{0,0,1}); Norm(R); U = Cross(R, F);
    }
    public static double[] Project(double[] p, double wx, double wy, double wz) {
        double[] C, R, U, F; Basis(p, out C, out R, out U, out F); double f = p[5];
        double dx = wx-C[0], dy = wy-C[1], dz = wz-C[2];
        double X = dx*R[0]+dy*R[1]+dz*R[2], Y = dx*U[0]+dy*U[1]+dz*U[2], Z = dx*F[0]+dy*F[1]+dz*F[2];
        return new double[]{ 160 + p[6] + f*X/Z, 100 + p[7] - f*Y/Z, X, Y, Z };
    }
    static double[] px = new double[8], py = new double[8];
    static double[] qx = new double[8], qy = new double[8], qz = new double[8];
    public static double Score(double[] p) { if (p[5] < 180 || p[5] > 700) return -1e9 + p[5]; return Iou(p); }
    public static double Iou(double[] p) {
        double[] C, R, U, F; Basis(p, out C, out R, out U, out F); double f = p[5];
        int n = VX.Length;
        if (cxv == null || cxv.Length != n) { cxv = new double[n]; cyv = new double[n]; czv = new double[n]; }
        for (int i = 0; i < n; i++) {
            double dx = VX[i]-C[0], dy = VY[i]-C[1], dz = VZ[i]-C[2];
            cxv[i] = dx*R[0]+dy*R[1]+dz*R[2]; cyv[i] = dx*U[0]+dy*U[1]+dz*U[2]; czv[i] = dx*F[0]+dy*F[1]+dz*F[2];
        }
        Array.Clear(buf, 0, buf.Length);
        for (int t = 0; t < FA.Length; t++) {
            int[] idx = { FA[t], FB[t], FC[t] };
            int m = 0;
            for (int k = 0; k < 3; k++) {
                int a = idx[k], b = idx[(k+1)%3];
                double za = czv[a], zb = czv[b];
                bool ina = za >= Near, inb = zb >= Near;
                if (ina) { qx[m]=cxv[a]; qy[m]=cyv[a]; qz[m]=za; m++; }
                if (ina != inb) { double tt = (Near - za)/(zb - za); qx[m]=cxv[a]+(cxv[b]-cxv[a])*tt; qy[m]=cyv[a]+(cyv[b]-cyv[a])*tt; qz[m]=Near; m++; }
            }
            if (m < 3) continue;
            for (int k = 0; k < m; k++) { px[k] = 160 + p[6] + f*qx[k]/qz[k]; py[k] = 100 + p[7] - f*qy[k]/qz[k]; }
            FillPoly(m);
        }
        int inter = 0, uni = 0;
        for (int k = 0; k < buf.Length; k++) { bool a = buf[k] != 0, b = Mask[k] != 0; if (a || b) uni++; if (a && b) inter++; }
        return uni == 0 ? 0 : (double)inter / uni;
    }
    static double[] xs = new double[8];
    static void FillPoly(int n) {
        double miny = 1e9, maxy = -1e9;
        for (int k = 0; k < n; k++) { if (py[k] < miny) miny = py[k]; if (py[k] > maxy) maxy = py[k]; }
        if (miny > H + 10 || maxy < -10) return;
        int y0 = (int)Math.Ceiling(miny - 0.5), y1 = (int)Math.Floor(maxy - 0.5);
        if (y0 < 0) y0 = 0; if (y1 > H-1) y1 = H-1;
        for (int y = y0; y <= y1; y++) {
            double yc = y + 0.5; int m = 0;
            for (int k = 0; k < n; k++) {
                int j = (k+1) % n; double ya = py[k], yb = py[j];
                if ((ya <= yc && yb > yc) || (yb <= yc && ya > yc)) { xs[m++] = px[k] + (px[j]-px[k])*(yc-ya)/(yb-ya); }
            }
            if (m < 2) continue;
            Array.Sort(xs, 0, m);
            for (int k = 0; k + 1 < m; k += 2) {
                int xa = (int)Math.Ceiling(xs[k] - 0.5), xb = (int)Math.Floor(xs[k+1] - 0.5);
                if (xa < 0) xa = 0; if (xb > W-1) xb = W-1;
                for (int x = xa; x <= xb; x++) buf[y*W + x] = 1;
            }
        }
    }
    // Nelder-Mead over the parameters with a non-zero step, maximising Score
    public static double[] Optimize(double[] start, double[] step, int maxIter, out double best) {
        var free = new List<int>(); for (int i = 0; i < step.Length; i++) if (step[i] != 0) free.Add(i);
        int n = free.Count;
        double[] full = (double[])start.Clone();
        Func<double[], double> eval = (q) => { for (int i = 0; i < n; i++) full[free[i]] = q[i]; return -Score(full); };
        double[][] s = new double[n+1][]; double[] v = new double[n+1];
        s[0] = new double[n]; for (int i = 0; i < n; i++) s[0][i] = start[free[i]]; v[0] = eval(s[0]);
        for (int i = 0; i < n; i++) { s[i+1] = (double[])s[0].Clone(); s[i+1][i] += step[free[i]]; v[i+1] = eval(s[i+1]); }
        for (int it = 0; it < maxIter; it++) {
            Array.Sort(v, s);
            double[] c = new double[n];
            for (int i = 0; i < n; i++) for (int j = 0; j < n; j++) c[j] += s[i][j] / n;
            double[] xr = new double[n]; for (int j = 0; j < n; j++) xr[j] = c[j] + (c[j] - s[n][j]);
            double fr = eval(xr);
            if (fr < v[0]) {
                double[] xe = new double[n]; for (int j = 0; j < n; j++) xe[j] = c[j] + 2*(c[j] - s[n][j]);
                double fe = eval(xe);
                if (fe < fr) { s[n] = xe; v[n] = fe; } else { s[n] = xr; v[n] = fr; }
            } else if (fr < v[n-1]) { s[n] = xr; v[n] = fr; }
            else {
                double[] xc = new double[n]; for (int j = 0; j < n; j++) xc[j] = c[j] + 0.5*(s[n][j] - c[j]);
                double fc = eval(xc);
                if (fc < v[n]) { s[n] = xc; v[n] = fc; }
                else { for (int i = 1; i <= n; i++) { for (int j = 0; j < n; j++) s[i][j] = s[0][j] + 0.5*(s[i][j]-s[0][j]); v[i] = eval(s[i]); } }
            }
            double vmin = v[0], vmax = v[0]; for (int i = 1; i <= n; i++) { if (v[i] < vmin) vmin = v[i]; if (v[i] > vmax) vmax = v[i]; }
            if (vmax - vmin < 1e-7 && it > 80) break;
        }
        Array.Sort(v, s); best = -v[0];
        for (int i = 0; i < n; i++) full[free[i]] = s[0][i];
        return (double[])full.Clone();
    }
}
'@
if (-not ('RoadFit2' -as [type])) { Add-Type -TypeDefinition $cs }
# ---------------------------------------------------------------- the road mesh (3DS)
$b = [IO.File]::ReadAllBytes($Scene)
function U16($o){ [BitConverter]::ToUInt16($b,$o) }
function U32($o){ [BitConverter]::ToUInt32($b,$o) }
function F32($o){ [BitConverter]::ToSingle($b,$o) }
$vx = @(); $vy = @(); $vz = @(); $fa = @(); $fb = @(); $fc = @()
$o = 0
while ($o + 6 -le $b.Length) {
  $id = U16 $o; $len = U32 ($o+2)
  if ($id -in 0x4D4D,0x3D3D,0x4100) { $o += 6; continue }
  if ($id -eq 0x4000) { $p=$o+6; while($b[$p] -ne 0){$p++}; $o = $p+1; continue }
  if ($id -eq 0x4110) { $n = U16 ($o+6); for ($i=0;$i -lt $n;$i++){ $vx += [double](F32 ($o+8+$i*12)); $vy += [double](F32 ($o+12+$i*12)); $vz += [double](F32 ($o+16+$i*12)) } }
  if ($id -eq 0x4120) { $n = U16 ($o+6); for ($i=0;$i -lt $n;$i++){ $fa += [int](U16 ($o+8+$i*8)); $fb += [int](U16 ($o+10+$i*8)); $fc += [int](U16 ($o+12+$i*8)) } }
  if ($id -eq 0xB000) { break }
  $o += $len
}
[RoadFit2]::VX = [double[]]$vx; [RoadFit2]::VY = [double[]]$vy; [RoadFit2]::VZ = [double[]]$vz
[RoadFit2]::FA = [int[]]$fa; [RoadFit2]::FB = [int[]]$fb; [RoadFit2]::FC = [int[]]$fc
"road mesh: $($vx.Count) vertices, $($fa.Count) faces"
# the centre line: the quad strip's cross-section pairs (inner, outer), midpoints, densified
# (the strip's layout in CarPathScene2.3ds: the straight run's rungs, the bend's fan from
# vertex 9, the top leg's rungs)
$pairs = @(@(13,0),@(14,15),@(16,17),@(18,19),@(20,21),@(22,23),@(24,25),@(26,27),@(12,1),@(11,28),@(10,2),@(9,3),@(9,4),@(29,5),@(8,31),@(30,33),@(32,35),@(34,6),@(7,6))
$mx = @(); $my = @(); $mz = @()
foreach ($pr in $pairs) { $mx += ($vx[$pr[0]]+$vx[$pr[1]])/2; $my += ($vy[$pr[0]]+$vy[$pr[1]])/2; $mz += ($vz[$pr[0]]+$vz[$pr[1]])/2 }
function CatRom($arr, $i, $t) { $k0 = [Math]::Max(0,$i-1); $k3 = [Math]::Min($arr.Count-1,$i+2); $a0 = $arr[$k0]; $a1 = $arr[$i]; $a2 = $arr[$i+1]; $a3 = $arr[$k3]; $t2 = $t*$t; $t3 = $t2*$t
  return 0.5*(2*$a1 + ($a2-$a0)*$t + (2*$a0-5*$a1+4*$a2-$a3)*$t2 + (3*$a1-$a0-3*$a2+$a3)*$t3) }
$cx = @(); $cy = @(); $cz = @()
for ($i = 0; $i -lt $mx.Count - 1; $i++) {
  $segLen = [Math]::Sqrt(($mx[$i+1]-$mx[$i])*($mx[$i+1]-$mx[$i]) + ($my[$i+1]-$my[$i])*($my[$i+1]-$my[$i]) + ($mz[$i+1]-$mz[$i])*($mz[$i+1]-$mz[$i]))
  $m = [Math]::Max(2, [int][Math]::Ceiling($segLen / 2.0))
  for ($j = 0; $j -lt $m; $j++) { $t = $j / $m; $cx += CatRom $mx $i $t; $cy += CatRom $my $i $t; $cz += CatRom $mz $i $t } }
$cx += $mx[-1]; $cy += $my[-1]; $cz += $mz[-1]
$slope = New-Object double[] $cx.Count
for ($i = 0; $i -lt $cx.Count; $i++) { $i0 = [Math]::Max(0,$i-2); $i1 = [Math]::Min($cx.Count-1,$i+2)
  $dh = [Math]::Sqrt(($cx[$i1]-$cx[$i0])*($cx[$i1]-$cx[$i0]) + ($cy[$i1]-$cy[$i0])*($cy[$i1]-$cy[$i0])); $dv = $cz[$i1]-$cz[$i0]
  $slope[$i] = [Math]::Atan2($dv, $dh) * 180 / [Math]::PI }
# ---------------------------------------------------------------- the painted road
$g = New-Object System.Drawing.Bitmap $Guide
$mask = New-Object byte[] (320*200); $cnt = 0
for ($y = 0; $y -lt 200; $y++) { for ($x = 0; $x -lt 320; $x++) { $c = $g.GetPixel($x, $y)
  if (($c.R -lt 90 -and $c.G -lt 90 -and $c.B -lt 90) -or ($c.G -gt 150 -and $c.R -lt 120 -and $c.B -lt 120)) { $mask[$y*320+$x] = 1; $cnt++ } } }
$g.Dispose()
[RoadFit2]::Mask = $mask
"painted road: $cnt pixels"
# ---------------------------------------------------------------- the camera
if ($Cam) {
  $camv = New-Object double[] 8; $ci = 0; foreach ($tok in $Cam.Split(',')) { $camv[$ci] = [double]::Parse($tok.Trim(), [Globalization.CultureInfo]::InvariantCulture); $ci++ }
} else {
  $best = -1e18; $camv = $null; $t0 = Get-Date
  $stepv = [double[]]@(40, 80, 0, 0.08, 0.05, 60, 0, 0)
  foreach ($cx0 in -100, 0, 60, 150) { foreach ($cy0 in -300, -450, -650, -900) { foreach ($f in 250, 350, 500) {
    $yaw = [Math]::Atan2(-120 - $cx0, 0 - $cy0)
    $start = [double[]]@($cx0, $cy0, $CamHeight, $yaw, 0.0, $f, 0, 0)
    $sc = 0.0; $p = [RoadFit2]::Optimize($start, $stepv, $Iters, [ref]$sc)
    if ($sc -gt $best) { $best = $sc; $camv = $p } } } }
  $stepP = [double[]]@(10, 20, 0, 0.02, 0.0125, 15, 0, 0)
  $sc = 0.0; $p = [RoadFit2]::Optimize($camv, $stepP, $Iters, [ref]$sc); if ($sc -gt $best) { $best = $sc; $camv = $p }
  "camera fit: the mesh covers the painted road with IoU {0:0.000} ({1:0} s)" -f $best, ((Get-Date) - $t0).TotalSeconds
}
"camera: ({0:0.0}, {1:0.0}, {2:0.0}) yaw {3:0.0} deg pitch {4:0.0} deg focal {5:0.0} px; -Cam `"{6}`"" -f $camv[0], $camv[1], $camv[2], ($camv[3]*180/[Math]::PI), ($camv[4]*180/[Math]::PI), $camv[5], (($camv | ForEach-Object { '{0:0.0000}' -f $_ }) -join ', ')
# ---------------------------------------------------------------- depth along the projected centre line
$proj = @()
for ($i = 0; $i -lt $cx.Count; $i++) { $s = [RoadFit2]::Project($camv, $cx[$i], $cy[$i], $cz[$i]); if ($s[4] -gt 2) { $proj += ,@($s[0], $s[1], $s[4], $slope[$i]) } }
$i0 = 0; while ($i0 -lt $proj.Count -and ($proj[$i0][1] -ge 200 -or $proj[$i0][0] -lt 0 -or $proj[$i0][0] -ge 320)) { $i0++ }
$arc = @(0.0); $tot = 0.0
for ($i = $i0 + 1; $i -lt $proj.Count; $i++) { $tot += [Math]::Sqrt(($proj[$i][0]-$proj[$i-1][0])*($proj[$i][0]-$proj[$i-1][0]) + ($proj[$i][1]-$proj[$i-1][1])*($proj[$i][1]-$proj[$i-1][1])); $arc += $tot }
"projected centre line: on screen from ({0:0},{1:0}) depth {2:0} to ({3:0},{4:0}) depth {5:0}; climb {6:0.0} -> {7:0.0} deg" -f $proj[$i0][0], $proj[$i0][1], $proj[$i0][2], $proj[-1][0], $proj[-1][1], $proj[-1][2], $proj[$i0][3], $proj[-1][3]
$apexP = $i0; for ($i = $i0; $i -lt $proj.Count; $i++) { if ($proj[$i][0] -gt $proj[$apexP][0]) { $apexP = $i } }; $apexFracP = $arc[$apexP - $i0] / $tot
function DepthAt($frac) {
  if ($script:apexFracW -gt 0) { if ($frac -le $script:apexFracW) { $frac = $frac / $script:apexFracW * $apexFracP } else { $frac = $apexFracP + ($frac - $script:apexFracW) / (1 - $script:apexFracW) * (1 - $apexFracP) } }
  $a = $frac * $tot; $k = 0; while ($k -lt $arc.Count - 2 -and $arc[$k+1] -lt $a) { $k++ }
  $f = 0; if ($arc[$k+1] -gt $arc[$k]) { $f = ($a - $arc[$k]) / ($arc[$k+1] - $arc[$k]) }; if ($f -gt 1) { $f = 1 }; if ($f -lt 0) { $f = 0 }
  $z = $proj[$i0+$k][2] + ($proj[$i0+$k+1][2] - $proj[$i0+$k][2]) * $f; $sl = $proj[$i0+$k][3] + ($proj[$i0+$k+1][3] - $proj[$i0+$k][3]) * $f
  return @($z, $sl) }
# ---------------------------------------------------------------- the screen path and its waypoints' depth and climb
$vals = $Way.Split(',') | ForEach-Object { [double]$_.Trim() }
$nw = [int]($vals.Count / 2); $wx = @(); $wy = @()
for ($i = 0; $i -lt $nw; $i++) { $wx += $vals[2*$i]; $wy += $vals[2*$i+1] }
$m = [int][Math]::Floor(200 / ($nw - 1)); $ns = $m * ($nw - 1)
$qx = New-Object double[] ($ns+1); $qy = New-Object double[] ($ns+1)
for ($i = 0; $i -lt $nw - 1; $i++) { for ($j = 0; $j -le $m; $j++) { $t = $j / $m; $qx[$i*$m+$j] = CatRom $wx $i $t; $qy[$i*$m+$j] = CatRom $wy $i $t } }
$warc = @(0.0); $wtot = 0.0
for ($i = 1; $i -le $ns; $i++) { $wtot += [Math]::Sqrt(($qx[$i]-$qx[$i-1])*($qx[$i]-$qx[$i-1]) + ($qy[$i]-$qy[$i-1])*($qy[$i]-$qy[$i-1])); $warc += $wtot }
$apexW = 0; for ($i = 0; $i -lt $nw; $i++) { if ($wx[$i] -gt $wx[$apexW]) { $apexW = $i } }; $script:apexFracW = $warc[$apexW*$m] / $wtot
$zEndScene = (DepthAt 1.0)[0]
$K = (256 * $CarW / $CarEndPx) / $zEndScene
$tf = New-Object double[] $nw; $rawZ = New-Object double[] $nw; $rawP = New-Object double[] $nw
for ($i = 0; $i -lt $nw; $i++) { $tf[$i] = $warc[$i*$m] / $wtot; $d = DepthAt $tf[$i]; $rawZ[$i] = $d[0] * $K; $rawP[$i] = $d[1] * 10 }
# smoothed: a least-squares cubic in the way-along for the depth and the climb (the raw
# values follow the projected line's uneven proportions and turn the car in bursts); the
# first and last depth kept, the climb never below 0
function FitCubic([double[]]$tt, [double[]]$yy) {
  $mA = [Array]::CreateInstance([double], 4, 4); $vB = New-Object double[] 4
  for ($q = 0; $q -lt $tt.Length; $q++) { $pv = New-Object double[] 4; $pv[0] = 1; $pv[1] = $tt[$q]; $pv[2] = $tt[$q]*$tt[$q]; $pv[3] = $pv[2]*$tt[$q]
    for ($r = 0; $r -lt 4; $r++) { $vB[$r] += $pv[$r]*$yy[$q]; for ($cc = 0; $cc -lt 4; $cc++) { $mA[$r,$cc] += $pv[$r]*$pv[$cc] } } }
  for ($r = 0; $r -lt 4; $r++) { $piv = $mA[$r,$r]; for ($cc = 0; $cc -lt 4; $cc++) { $mA[$r,$cc] = $mA[$r,$cc]/$piv }; $vB[$r] = $vB[$r]/$piv
    for ($r2 = 0; $r2 -lt 4; $r2++) { if ($r2 -ne $r) { $fct = $mA[$r2,$r]; for ($cc = 0; $cc -lt 4; $cc++) { $mA[$r2,$cc] -= $fct*$mA[$r,$cc] }; $vB[$r2] -= $fct*$vB[$r] } } }
  return ,$vB }
function Ev($cf, $t) { $cf[0] + $cf[1]*$t + $cf[2]*$t*$t + $cf[3]*$t*$t*$t }
$coefZ = FitCubic $tf $rawZ; $coefP = FitCubic $tf $rawP
$wz = @(); $wp = @(); $data = @()
for ($i = 0; $i -lt $nw; $i++) { $zg = [int][Math]::Round((Ev $coefZ $tf[$i])); $pt = [int][Math]::Round((Ev $coefP $tf[$i]))
  if ($i -eq 0 -or $i -eq $nw - 1) { $zg = [int][Math]::Round($rawZ[$i]) }
  if ($pt -lt 0) { $pt = 0 }
  $wz += $zg; $wp += $pt; $data += "$($wx[$i]),$($wy[$i]),$zg,$pt" }
$mono = $true; for ($i = 1; $i -lt $nw; $i++) { if ($wz[$i] -le $wz[$i-1]) { $mono = $false } }
if (-not $mono) { "WARNING: the smoothed depth is not rising everywhere; check the waypoints" }
"raw depths : " + (($rawZ | ForEach-Object { [int][Math]::Round($_) }) -join ', ')
"raw climbs : " + (($rawP | ForEach-Object { [int][Math]::Round($_) }) -join ', ')
""
"hillWay DATA for GAME7.BAS (screen x,y, depth in game units, climb in tenths of a degree):"
"DATA $nw"
$half = [int][Math]::Ceiling($nw / 2)
"DATA " + (($data | Select-Object -First $half) -join ', ')
"DATA " + (($data | Select-Object -Skip $half) -join ', ')
""
# ---------------------------------------------------------------- the drive as GAME7 walks it, drawn
$qz = New-Object double[] ($ns+1); $qp = New-Object double[] ($ns+1)
for ($i = 0; $i -lt $nw - 1; $i++) { for ($j = 0; $j -le $m; $j++) { $t = $j / $m; $qz[$i*$m+$j] = CatRom $wz $i $t; $qp[$i*$m+$j] = CatRom $wp $i $t } }
$X = New-Object double[] ($ns+1); $Y = New-Object double[] ($ns+1)
for ($i = 0; $i -le $ns; $i++) { $X[$i] = ($qx[$i]-160)*$qz[$i]/256; $Y[$i] = (100-$qy[$i])*$qz[$i]/256 }
$L = 0.0; for ($i = 1; $i -le $ns; $i++) { $L += [Math]::Sqrt(($X[$i]-$X[$i-1])*($X[$i]-$X[$i-1]) + ($Y[$i]-$Y[$i-1])*($Y[$i]-$Y[$i-1]) + ($qz[$i]-$qz[$i-1])*($qz[$i]-$qz[$i-1])) }
$stepLen = $L / $Steps
"the drive: {0:0} game units, {1:0.00} a step; depth {2:0} -> {3:0}, the car {4:0} px -> {5:0} px wide" -f $L, $stepLen, $qz[0], $qz[$ns], (256*$CarW/$qz[0]), (256*$CarW/$qz[$ns])
$pts = @(); $sx = $X[0]; $sy = $Y[0]; $sz = $qz[0]; $spit = $qp[0]; $i = 1; $d = 0
while ($true) {
  $pts += ,@($sx, $sy, $sz, $spit)
  if ($i -gt $ns -or $d -ge 300) { break }
  $fr = $stepLen
  while ($i -le $ns) { $u = [Math]::Sqrt(($X[$i]-$sx)*($X[$i]-$sx) + ($Y[$i]-$sy)*($Y[$i]-$sy) + ($qz[$i]-$sz)*($qz[$i]-$sz))
    if ($u -ge $fr) { $t = $fr/$u; $sx += ($X[$i]-$sx)*$t; $sy += ($Y[$i]-$sy)*$t; $sz += ($qz[$i]-$sz)*$t; $spit += ($qp[$i]-$spit)*$t; break }
    $fr -= $u; $sx = $X[$i]; $sy = $Y[$i]; $sz = $qz[$i]; $spit = $qp[$i]; $i++ }
  $d++
}
$SC = 3
$bmp = New-Object System.Drawing.Bitmap $Backdrop
$o = New-Object System.Drawing.Bitmap (320*$SC), (200*$SC)
$gr = [System.Drawing.Graphics]::FromImage($o); $gr.InterpolationMode = 'NearestNeighbor'; $gr.PixelOffsetMode = 'Half'
$gr.DrawImage($bmp, 0, 0, 320*$SC, 200*$SC); $gr.SmoothingMode = 'AntiAlias'
function Scr($X, $Y, $Z) { return @((160 + 256*$X/$Z), (100 - 256*$Y/$Z)) }
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(230, 255, 230, 0)), 2
for ($k = 1; $k -lt $pts.Count; $k++) { $a = Scr $pts[$k-1][0] $pts[$k-1][1] $pts[$k-1][2]; $c = Scr $pts[$k][0] $pts[$k][1] $pts[$k][2]; $gr.DrawLine($pen, [float]($a[0]*$SC), [float]($a[1]*$SC), [float]($c[0]*$SC), [float]($c[1]*$SC)) }
for ($k = 0; $k -lt $pts.Count; $k += 10) { $a = Scr $pts[$k][0] $pts[$k][1] $pts[$k][2]; $gr.FillEllipse([System.Drawing.Brushes]::White, [float]($a[0]*$SC-2), [float]($a[1]*$SC-2), 4, 4) }
$font = New-Object System.Drawing.Font 'Segoe UI', 9
$penW = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(200, 80, 200, 255)), 2
foreach ($k in 0, 40, 80, 120, 160, 200, ($pts.Count-1)) { if ($k -ge $pts.Count) { continue }
  $k1 = [Math]::Max(0,$k-2); $k2 = [Math]::Min($pts.Count-1,$k+2)
  $dx = $pts[$k2][0]-$pts[$k1][0]; $dz = $pts[$k2][2]-$pts[$k1][2]; $yaw = [Math]::Atan2($dx, $dz)
  $fx = [Math]::Sin($yaw); $fz = [Math]::Cos($yaw); $rx = $fz; $rz = -$fx
  $P = $pts[$k]; $ptsF = @()
  foreach ($c in @(@(1,1),@(1,-1),@(-1,-1),@(-1,1))) { $cx3 = $P[0] + $c[0]*$fx*$CarL/2 + $c[1]*$rx*$CarW/2; $cz3 = $P[2] + $c[0]*$fz*$CarL/2 + $c[1]*$rz*$CarW/2; $q = Scr $cx3 $P[1] $cz3; $ptsF += New-Object System.Drawing.PointF ([float]($q[0]*$SC)), ([float]($q[1]*$SC)) }
  $gr.DrawPolygon($penW, [System.Drawing.PointF[]]$ptsF)
  $scp = Scr $P[0] $P[1] $P[2]
  $gr.DrawString("$k", $font, [System.Drawing.Brushes]::White, [float]($scp[0]*$SC+6), [float]($scp[1]*$SC-14))
  "step {0,3}: screen ({1:0},{2:0}) depth {3:0} car {4:0} px wide, heading {5:0} deg, pitch {6:0.0} deg" -f $k, $scp[0], $scp[1], $P[2], (256*$CarW/$P[2]), ($yaw*180/[Math]::PI), ($P[3]/10) }
$gr.Dispose(); $o.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png); $o.Dispose(); $bmp.Dispose()
"$Out written"
