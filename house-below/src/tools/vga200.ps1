# vga200.ps1 -- convert the 320x240 asset set to the 320x200 (mode 13h) set.
#
#   powershell -File vga200.ps1 -In <dir with the 240-line VGA\*.BMP/DAT> -Out <dir>
#
# A 4:3 monitor stretches 200 lines to the full screen height (pixels 1.2x taller than wide), so
# every picture keeps its width and its height is scaled by 154/184 (rooms: 184 -> 154 lines;
# the bottom panel shrinks from 56 to 46 lines). Mirrors what the old exporters did, but works
# on the indexed BMPs: area-averaged vertical scaling, then nearest-colour in the shared palette
# (Floyd-Steinberg for backgrounds, none for sprites/portraits). Index 227 is the transparent mask.
# Portraits lose their bottom 12 rows (the speech tail sits there). WORLD.DAT / STAGE.DAT y coordinates are scaled the same way.
param([Parameter(Mandatory)][string]$In, [Parameter(Mandatory)][string]$Out)
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
using System.IO;
public static class V200 {
    public static void Convert(string src, string dst, int newH, bool sprite, int keep) {
        byte[] b = File.ReadAllBytes(src);
        int w = BitConverter.ToInt32(b, 18), h = BitConverter.ToInt32(b, 22), off = BitConverter.ToInt32(b, 10);
        int[] pr = new int[256], pg = new int[256], pb = new int[256];
        for (int i = 0; i < 256; i++) { pb[i] = b[54 + i * 4]; pg[i] = b[55 + i * 4]; pr[i] = b[56 + i * 4]; }
        byte[] px = new byte[w * h];          // top-down copy
        for (int y = 0; y < h; y++) Array.Copy(b, off + (h - 1 - y) * w, px, y * w, w);
        byte[] outp = new byte[w * newH];
        double[] er = new double[w + 2], eg = new double[w + 2], eb = new double[w + 2];
        double[] nr = new double[w + 2], ng = new double[w + 2], nb = new double[w + 2];
        double ratio = (double)h / newH;
        for (int y = 0; y < newH; y++) {
            double y0 = y * ratio, y1 = (y + 1) * ratio;
            Array.Clear(nr, 0, nr.Length); Array.Clear(ng, 0, ng.Length); Array.Clear(nb, 0, nb.Length);
            for (int x = 0; x < w; x++) {
                double r = 0, g = 0, bl = 0, wt = 0, mw = 0;
                for (int sy = (int)y0; sy < h && sy < y1; sy++) {
                    double ov = Math.Min(y1, sy + 1) - Math.Max(y0, sy);
                    if (ov <= 0) continue;
                    int c = px[sy * w + x];
                    if (sprite && c == 227) { mw += ov; continue; }
                    r += pr[c] * ov; g += pg[c] * ov; bl += pb[c] * ov; wt += ov;
                }
                if (sprite && (mw >= ratio * 0.5 || wt == 0)) { outp[y * w + x] = 227; continue; }
                r /= wt; g /= wt; bl /= wt;
                if (!sprite) { r += er[x + 1]; g += eg[x + 1]; bl += eb[x + 1]; }
                int best = 0; double bd = 1e18;
                for (int i = 0; i < 256; i++) {
                    if (sprite && i == 227) continue;
                    double dr = pr[i] - r, dg = pg[i] - g, db = pb[i] - bl;
                    double d = dr * dr * 0.3 + dg * dg * 0.59 + db * db * 0.11;
                    if (d < bd) { bd = d; best = i; }
                }
                outp[y * w + x] = (byte)best;
                if (!sprite) {
                    double qr = r - pr[best], qg = g - pg[best], qb = bl - pb[best];
                    er[x + 2] += qr * 7 / 16; eg[x + 2] += qg * 7 / 16; eb[x + 2] += qb * 7 / 16;
                    nr[x] += qr * 3 / 16; ng[x] += qg * 3 / 16; nb[x] += qb * 3 / 16;
                    nr[x + 1] += qr * 5 / 16; ng[x + 1] += qg * 5 / 16; nb[x + 1] += qb * 5 / 16;
                    nr[x + 2] += qr / 16; ng[x + 2] += qg / 16; nb[x + 2] += qb / 16;
                }
            }
            if (!sprite) { Array.Copy(nr, er, er.Length); Array.Copy(ng, eg, eg.Length); Array.Copy(nb, eb, eb.Length); }
        }
        int fullH = newH; newH = keep; byte[] o = new byte[off + w * newH];
        Array.Copy(b, o, off);
        Array.Copy(BitConverter.GetBytes(newH), 0, o, 22, 4);
        Array.Copy(BitConverter.GetBytes(w * newH), 0, o, 34, 4);
        Array.Copy(BitConverter.GetBytes(o.Length), 0, o, 2, 4);
        for (int y = 0; y < newH; y++) Array.Copy(outp, y * w, o, off + (newH - 1 - y) * w, w);
        File.WriteAllBytes(dst, o);
    }
}
'@
$f = 154.0 / 184.0
New-Item -ItemType Directory -Force $Out | Out-Null
foreach ($file in Get-ChildItem $In -File) {
    $n = $file.Name.ToUpperInvariant(); $dst = Join-Path $Out $n
    if ($n -match '^(RM\d\d|CAR)\.BMP$') { [V200]::Convert($file.FullName, $dst, 154, $false, 154) }
    elseif ($n -match '^CHAR\d\d\.BMP$') { [V200]::Convert($file.FullName, $dst, 73, $true, 73) }
    elseif ($n -match '^P\d\d[AL]\.BMP$') {
        $h = [BitConverter]::ToInt32([IO.File]::ReadAllBytes($file.FullName), 22)
        $sh = [int][Math]::Round($h * 5 / 6.0 + 0.1)
        [V200]::Convert($file.FullName, $dst, $sh, $true, $sh - 12)   # bottom 12 rows cropped: the speech-tail zone
    }
    elseif ($n -eq 'WORLD.DAT') {
        $lines = [IO.File]::ReadAllLines($file.FullName) | ForEach-Object {
            if ($_ -match '^(\d+),(\d+),(\d+),(\d+),(.*)$') {
                '{0},{1},{2},{3},{4}' -f $Matches[1], [int][Math]::Round([int]$Matches[2] * $f), $Matches[3], [int][Math]::Round([int]$Matches[4] * $f), $Matches[5]
            } else { $_ }
        }
        [IO.File]::WriteAllText($dst, ($lines -join "`r`n") + "`r`n", [Text.Encoding]::ASCII)
    }
    elseif ($n -eq 'STAGE.DAT') {
        $lines = [IO.File]::ReadAllLines($file.FullName) | Where-Object { $_ } | ForEach-Object {
            $v = $_.Split(','); '{0},{1},{2},{3},{4}' -f [int][Math]::Round([int]$v[0] * $f), $v[1], [int][Math]::Round([int]$v[2] * $f), $v[3], $v[4]
        }
        [IO.File]::WriteAllText($dst, ($lines -join "`r`n") + "`r`n", [Text.Encoding]::ASCII)
    }
    elseif ($n -match '^(FACE\d\d|YOU)\.BMP$') { }   # superseded boxed portraits, not shipped
    else { Copy-Item $file.FullName $dst }
}
