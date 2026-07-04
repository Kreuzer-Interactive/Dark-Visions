# addtile37.ps1 -- add inventory tile 37 ("Unreadable formula", item id 52) to
# INVTIL2.PIC + INVMSK2.PIC (src + QA\current), slot 16 (cell x90,y108).
# Art = copy of tile 31 (Complete formula, slot 10 @ x135,y54) with the label
# re-rendered as "Unreadable formula" in the game's font2 (ART/../font.txt).
# NOTE: the INVTILES.png master does NOT have this cell -- re-run this script
# after any INVTIL2.PIC regeneration from the master.
# Also writes scratch previews (tile37_preview.png) for eyeball verification.

$ErrorActionPreference = 'Stop'
$src = 'C:\Code\Dark-Visions\src'

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Imaging;
using System.Collections.Generic;

public static class Tile37 {
  // ---- CGA .PIC (BSAVE B800 dump) decode/encode ----
  public static byte[,] Decode(string path) {
    byte[] raw = File.ReadAllBytes(path);
    var px = new byte[320, 200];
    for (int y = 0; y < 200; y++) {
      int off = 7 + (y / 2) * 80 + (y % 2) * 8192;
      for (int x = 0; x < 320; x++) {
        byte b = raw[off + x / 4];
        px[x, y] = (byte)((b >> (2 * (3 - (x % 4)))) & 3);
      }
    }
    return px;
  }
  public static void Encode(byte[,] px, string tmplPath, string outPath) {
    byte[] raw = File.ReadAllBytes(tmplPath); // keep header + any slack bytes
    for (int y = 0; y < 200; y++) {
      int off = 7 + (y / 2) * 80 + (y % 2) * 8192;
      for (int xb = 0; xb < 80; xb++) {
        int v = 0;
        for (int i = 0; i < 4; i++) v |= (px[xb * 4 + i, y] & 3) << (2 * (3 - i));
        raw[off + xb] = (byte)v;
      }
    }
    File.WriteAllBytes(outPath, raw);
  }
  public static void CopyRect(byte[,] px, int sx, int sy, int dx, int dy, int w, int h) {
    for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) px[dx + x, dy + y] = px[sx + x, sy + y];
  }
  public static void Fill(byte[,] px, int x0, int y0, int w, int h, byte v) {
    for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) px[x0 + x, y0 + y] = v;
  }
  // ---- font.txt (font2): height line, then per glyph: code, width, <h> binary rows ----
  public static Dictionary<char, string[]> LoadFont(string path, out int height) {
    var lines = new List<string>();
    foreach (var l in File.ReadAllLines(path)) {
      var t = l.Trim();
      if (t.Length > 0 && !t.StartsWith("#")) lines.Add(t);
    }
    height = int.Parse(lines[0]);
    var f = new Dictionary<char, string[]>();
    int i = 1;
    while (i + 1 + height <= lines.Count) {
      int code = int.Parse(lines[i]);
      int w = int.Parse(lines[i + 1]);
      var rows = new string[height];
      for (int r = 0; r < height; r++) rows[r] = lines[i + 2 + r].PadRight(w, '0');
      f[(char)code] = rows;
      i += 2 + height;
    }
    return f;
  }
  public static int TextW(Dictionary<char, string[]> f, string s) {
    int w = 0;
    foreach (char c in s) { if (f.ContainsKey(c)) w += f[c][0].Length + 1; else w += 3; }
    return w > 0 ? w - 1 : 0;
  }
  public static void DrawText(byte[,] px, Dictionary<char, string[]> f, int h, string s, int x, int y, byte col) {
    foreach (char c in s) {
      if (!f.ContainsKey(c)) { x += 3; continue; }
      var rows = f[c]; int w = rows[0].Length;
      for (int r = 0; r < h; r++) for (int i = 0; i < w; i++)
        if (rows[r][i] == '1') px[x + i, y + r] = col;
      x += w + 1;
    }
  }
  public static void Preview(byte[,] px, int x0, int y0, int w, int h, string outPng) {
    Color[] pal = { Color.Black, Color.FromArgb(169,85,0), Color.FromArgb(170,170,170), Color.FromArgb(85,85,85) };
    using (var bmp = new Bitmap(w * 3, h * 3)) {
      using (var g = Graphics.FromImage(bmp))
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++)
          using (var br = new SolidBrush(pal[px[x0 + x, y0 + y]])) g.FillRectangle(br, x * 3, y * 3, 3, 3);
      bmp.Save(outPng, ImageFormat.Png);
    }
  }
  // most common non-black attr in a rect (= the label text colour)
  public static byte SampleCol(byte[,] px, int x0, int y0, int w, int h) {
    int[] n = new int[4];
    for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) n[px[x0 + x, y0 + y]]++;
    int best = 1;
    for (int a = 2; a < 4; a++) if (n[a] > n[best]) best = a;
    return (byte)best;
  }
  // print the y rows inside a cell's label box that contain ink (to mimic line layout)
  public static string InkRows(byte[,] px, int cx, int cy) {
    var s = "";
    for (int r = 38; r < 54; r++) {
      bool ink = false;
      for (int x = 1; x < 44; x++) if (px[cx + x, cy + r] != 0) { ink = true; break; }
      if (ink) s += r + " ";
    }
    return s;
  }
}
'@

$til = [Tile37]::Decode("$src\INVTIL2.PIC")

# measure an existing 2-line label ("Partial formula" = tile 23, slot 2 @ x90,y0)
Write-Host "ink rows of 'Partial formula' label: $([Tile37]::InkRows($til, 90, 0))"
$col = [Tile37]::SampleCol($til, 92, 40, 41, 13)
Write-Host "label colour attr = $col"

# copy tile 31 (slot 10 @ x135,y54) -> slot 16 (x90,y108), then relabel
[Tile37]::CopyRect($til, 135, 54, 90, 108, 45, 54)
[Tile37]::Fill($til, 91, 147, 43, 13, 0)   # clear the label box (rows 39-51 of the cell)

$h = 0
$font = [Tile37]::LoadFont("$src\font.txt", [ref]$h)
$w1 = [Tile37]::TextW($font, 'Unreadable')
$w2 = [Tile37]::TextW($font, 'formula')
Write-Host "font h=$h  'Unreadable' w=$w1  'formula' w=$w2"
if ($w1 -gt 43 -or $w2 -gt 43) { throw 'label too wide for the box' }
# 2 lines of 7px into rows 40-52 of the cell: line1 top = cell+40, line2 top = cell+47 (measured layout below may adjust)
[Tile37]::DrawText($til, $font, $h, 'Unreadable', [int](90 + 2 + (41 - $w1) / 2), 108 + 40, $col)
[Tile37]::DrawText($til, $font, $h, 'formula', [int](90 + 2 + (41 - $w2) / 2), 108 + 47, $col)

[Tile37]::Preview($til, 90, 108, 45, 54, "$env:TEMP\tile37_preview.png")
[Tile37]::Encode($til, "$src\INVTIL2.PIC", "$src\INVTIL2.PIC")
Copy-Item "$src\INVTIL2.PIC" 'C:\Code\Dark-Visions\QA\current\INVTIL2.PIC' -Force

# mask sheet: copy tile 31's keep-mask (slot 10 @ x135,y54, 45x40) -> slot 16 (x90,y108)
$msk = [Tile37]::Decode("$src\INVMSK2.PIC")
[Tile37]::CopyRect($msk, 135, 54, 90, 108, 45, 40)
[Tile37]::Encode($msk, "$src\INVMSK2.PIC", "$src\INVMSK2.PIC")
Copy-Item "$src\INVMSK2.PIC" 'C:\Code\Dark-Visions\QA\current\INVMSK2.PIC' -Force

Write-Host 'done'
