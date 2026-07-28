# Dark Visions art codec helpers (dot-source me).
# CGA .PIC (BSAVE B800 dump) <-> byte[320,200] attrs; PNG quantize (room palette
# 0=black 1=#555555 2=#0000AA 3=#AA5500); preview PNG writer; .PCT/.MSK text writer.
$ErrorActionPreference = 'Stop'
if (-not ('DV' -as [type])) {
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Drawing;
using System.Drawing.Imaging;
using System.Collections.Generic;

public static class DV {
  public static byte[,] DecodePic(string path) {
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
  public static void EncodePic(byte[,] px, string tmplPath, string outPath) {
    byte[] raw = File.ReadAllBytes(tmplPath);
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
  public static byte[,] QuantPng(string path, byte[,] alpha) {
    var bmp = new Bitmap(path);
    var px = new byte[bmp.Width, bmp.Height];
    int[][] pal = new int[][] { new int[]{0,0,0}, new int[]{85,85,85}, new int[]{0,0,170}, new int[]{170,85,0} };
    for (int y = 0; y < bmp.Height; y++) for (int x = 0; x < bmp.Width; x++) {
      Color c = bmp.GetPixel(x, y);
      if (alpha != null) alpha[x, y] = c.A;
      int best = 0; long bd = long.MaxValue;
      for (int a = 0; a < 4; a++) {
        long d = (long)(c.R-pal[a][0])*(c.R-pal[a][0]) + (long)(c.G-pal[a][1])*(c.G-pal[a][1]) + (long)(c.B-pal[a][2])*(c.B-pal[a][2]);
        if (d < bd) { bd = d; best = a; }
      }
      px[x, y] = (byte)best;
    }
    bmp.Dispose();
    return px;
  }
  public static int[] PngSize(string path) {
    var bmp = new Bitmap(path);
    var r = new int[] { bmp.Width, bmp.Height };
    bmp.Dispose();
    return r;
  }
  public static void Save(byte[,] px, int x0, int y0, int w, int h, int sc, string outPng) {
    Color[] pal = { Color.Black, Color.FromArgb(85,85,85), Color.FromArgb(0,0,170), Color.FromArgb(170,85,0) };
    using (var bmp = new Bitmap(w * sc, h * sc)) {
      using (var g = Graphics.FromImage(bmp))
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++)
          using (var br = new SolidBrush(pal[px[x0 + x, y0 + y]])) g.FillRectangle(br, x * sc, y * sc, sc, sc);
      bmp.Save(outPng, ImageFormat.Png);
    }
  }
  // GET-block ints for one frame: header w*2,h then row-packed 2bpp bytes -> LE int16 pairs
  public static short[] FrameInts(byte[,] px, byte[,] alpha, int w, int h, bool mask) {
    int bpr = (w * 2 + 7) / 8;
    var bytes = new byte[bpr * h];
    for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
      bool opaque = alpha == null || alpha[x, y] >= 128;
      int attr = mask ? (opaque ? 0 : 3) : (opaque ? px[x, y] : 0);
      int bi = y * bpr + (x * 2) / 8;
      int sh = 6 - 2 * (x % 4);
      bytes[bi] |= (byte)((attr & 3) << sh);
    }
    int n = (bytes.Length + 1) / 2;
    var ints = new short[n + 2];
    ints[0] = (short)(w * 2);
    ints[1] = (short)h;
    for (int i = 0; i < n; i++) {
      int lo = bytes[i * 2];
      int hi = (i * 2 + 1 < bytes.Length) ? bytes[i * 2 + 1] : 0;
      ints[i + 2] = unchecked((short)(lo | (hi << 8)));
    }
    return ints;
  }
  // write k frames interleaved as the .PCT/.MSK text format (k comma-joined ints per line)
  public static void WriteSet(string path, List<short[]> frames) {
    int n = frames[0].Length;
    var sb = new StringBuilder();
    for (int i = 0; i < n; i++) {
      for (int f = 0; f < frames.Count; f++) {
        if (f > 0) sb.Append(",");
        sb.Append(frames[f][i]);
      }
      sb.Append("\r\n");
    }
    File.WriteAllText(path, sb.ToString());
  }
  public static string DiffRect(byte[,] a, byte[,] b) {
    int x0=9999,y0=9999,x1=-1,y1=-1,n=0;
    for (int y = 0; y < 200; y++) for (int x = 0; x < 320; x++)
      if (a[x,y] != b[x,y]) { n++; if(x<x0)x0=x; if(x>x1)x1=x; if(y<y0)y0=y; if(y>y1)y1=y; }
    return n + " px differ, rect (" + x0 + "," + y0 + ")-(" + x1 + "," + y1 + ")";
  }
}
'@
}
