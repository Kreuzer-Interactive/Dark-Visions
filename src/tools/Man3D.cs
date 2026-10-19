// Man3D.cs - the mesh builder (lofted rings), atlas painter, 3DS writer and the preview renderer that
// mimics the C3DTRI engine (nearest texel, no lighting, painter's order). Used by man3d.ps1 and tdsview.ps1.
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;

public class ManRect { public int X, Y, W, H; public string Name; public ManRect(string n, int x, int y, int w, int h) { Name = n; X = x; Y = y; W = w; H = h; } }

public class Man3D
{
    // ---------------- mesh ----------------
    public List<float[]> V = new List<float[]>();   // x,y,z  (Y up, front = -Z)
    public List<float[]> UV = new List<float[]>();  // u,v in texels, top-down
    public List<int[]> F = new List<int[]>();
    public double S;                                 // units per cm
    public int TW = 128;
    public byte[] Tex;                               // palette indices, TW*TW, top-down
    public List<ManRect> Rects = new List<ManRect>();
    public Random Rnd;

    // palette of the atlas (the car's CGA set + the backdrop's grays)
    public static Color[] Pal = new Color[] {
        Color.FromArgb(7,7,7),        // 0 K  black fill
        Color.FromArgb(170,85,0),     // 1 O  orange / brown
        Color.FromArgb(85,85,85),     // 2 G  gray
        Color.FromArgb(170,170,170),  // 3 L  light gray
        Color.FromArgb(0,170,170),    // 4 C  cyan
        Color.FromArgb(0,170,0),      // 5 N  green
        Color.FromArgb(0,0,0),        // 6 B  ink black (outline, same look as 0 on screen)
        Color.FromArgb(0,0,170),      // 7 U  CGA blue (James's suit)
    };
    public const byte K = 0, O = 1, G = 2, L = 3, C = 4, N = 5, B = 6, T = 255;

    public Man3D(double unitsPerCm, int seed) { S = unitsPerCm; Rnd = new Random(seed); Tex = new byte[TW * TW]; for (int i = 0; i < Tex.Length; i++) Tex[i] = T; }

    int AddV(double x, double y, double z, double u, double v) { V.Add(new float[] { (float)(x * S), (float)(y * S), (float)(z * S) }); UV.Add(new float[] { (float)u, (float)v }); return V.Count - 1; }

    // a triangle wound so its normal points away from the reference point
    void Tri(int a, int b, int c, double[] refp)
    {
        float[] A = V[a], Bv = V[b], Cv = V[c];
        double ux = Bv[0] - A[0], uy = Bv[1] - A[1], uz = Bv[2] - A[2];
        double wx = Cv[0] - A[0], wy = Cv[1] - A[1], wz = Cv[2] - A[2];
        double nx = uy * wz - uz * wy, ny = uz * wx - ux * wz, nz = ux * wy - uy * wx;
        double mx = (A[0] + Bv[0] + Cv[0]) / 3 - refp[0] * S, my = (A[1] + Bv[1] + Cv[1]) / 3 - refp[1] * S, mz = (A[2] + Bv[2] + Cv[2]) / 3 - refp[2] * S;
        if (nx * mx + ny * my + nz * mz < 0) { int t = b; b = c; c = t; }
        F.Add(new int[] { a, b, c });
    }

    // A ring: centre (cx,cy,cz), half-width rx, half-depth rz, n sides; angle 0 at the BACK (+z),
    // going round by his right (-x) to the front (-z) at u = half. n+1 vertices (the seam doubled).
    // uv: the rect's columns across u0..u1 and the row vrow. Returns the vertex indices.
    public class Ring { public int[] I; public double cx, cy, cz; }
    public Ring MakeRing(double cx, double cy, double cz, double rx, double rz, int n, ManRect r, double vrow, double squareness)
    {
        Ring g = new Ring(); g.I = new int[n + 1]; g.cx = cx; g.cy = cy; g.cz = cz;
        for (int k = 0; k <= n; k++)
        {
            double th = 2 * Math.PI * k / n;
            double sx = -Math.Sin(th), sz = Math.Cos(th);
            // squareness 0 = ellipse, 1 = rounded box
            if (squareness > 0) { double m = Math.Max(Math.Abs(sx), Math.Abs(sz)); if (m > 0) { sx = sx * (1 - squareness) + sx / m * squareness; sz = sz * (1 - squareness) + sz / m * squareness; } }
            double u = r.X + (double)k / n * r.W;
            g.I[k] = AddV(cx + rx * sx, cy, cz + rz * sz, u, vrow);
        }
        return g;
    }
    // the ring's front vertex pushed forward (a nose, a chin)
    public void Bump(Ring g, double dzCm) { int n = g.I.Length - 1; int k = n / 2; V[g.I[k]][2] -= (float)(dzCm * S); }
    public void Tube(Ring a, Ring b)
    {
        double[] refp = new double[] { (a.cx + b.cx) / 2, (a.cy + b.cy) / 2, (a.cz + b.cz) / 2 };
        int n = a.I.Length - 1;
        for (int k = 0; k < n; k++) { Tri(a.I[k], b.I[k], b.I[k + 1], refp); Tri(a.I[k], b.I[k + 1], a.I[k + 1], refp); }
    }
    // a cap over a ring: its centre vertex with the cap rect's middle texel; the reference point is inside the limb
    public void Cap(Ring a, double inY, ManRect r)
    {
        int n = a.I.Length - 1;
        int c = AddV(a.cx, a.cy, a.cz, r.X + r.W / 2.0, r.Y + r.H / 2.0);
        double[] refp = new double[] { a.cx, a.cy + inY, a.cz };
        int[] cv = new int[n + 1];
        for (int k = 0; k <= n; k++) { double th = 2 * Math.PI * k / n; float[] p = V[a.I[k]]; cv[k] = V.Count; V.Add(new float[] { p[0], p[1], p[2] }); UV.Add(new float[] { (float)(r.X + r.W / 2.0 - Math.Sin(th) * r.W * 0.48), (float)(r.Y + r.H / 2.0 + Math.Cos(th) * r.H * 0.48) }); }
        for (int k = 0; k < n; k++) Tri(c, cv[k], cv[k + 1], refp);
    }
    // a loft: rings along y (and offsets) as a flat list of 6 numbers each: cx, cy, cz, rx, rz, vfrac (0 = the
    // rect's top row .. 1 = its bottom); tubes between consecutive rings
    public List<Ring> Loft(double[] flat, int n, ManRect r, double squareness)
    {
        List<Ring> list = new List<Ring>();
        int nr = flat.Length / 6;
        for (int i = 0; i < nr; i++)
        {
            double[] q = new double[6]; Array.Copy(flat, i * 6, q, 0, 6);
            list.Add(MakeRing(q[0], q[1], q[2], q[3], q[4], n, r, r.Y + q[5] * r.H, squareness));
            if (i > 0) Tube(list[i - 1], list[i]);
        }
        return list;
    }

    // ---------------- texture painting ----------------
    public void Px(int x, int y, byte c) { if (x < 0 || y < 0 || x >= TW || y >= TW) return; Tex[y * TW + x] = c; }
    public byte Get(int x, int y) { if (x < 0 || y < 0 || x >= TW || y >= TW) return T; return Tex[y * TW + x]; }
    public void Fill(ManRect r, byte c) { for (int y = r.Y; y < r.Y + r.H; y++) for (int x = r.X; x < r.X + r.W; x++) Px(x, y, c); }
    public void HLine(int x0, int x1, int y, byte c) { for (int x = Math.Min(x0, x1); x <= Math.Max(x0, x1); x++) Px(x, y, c); }
    public void VLine(int x, int y0, int y1, byte c) { for (int y = Math.Min(y0, y1); y <= Math.Max(y0, y1); y++) Px(x, y, c); }
    public void Line(int x0, int y0, int x1, int y1, byte c)
    {
        int dx = Math.Abs(x1 - x0), dy = -Math.Abs(y1 - y0), sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1, err = dx + dy;
        while (true) { Px(x0, y0, c); if (x0 == x1 && y0 == y1) break; int e2 = 2 * err; if (e2 >= dy) { err += dy; x0 += sx; } if (e2 <= dx) { err += dx; y0 += sy; } }
    }
    public void Sprinkle(ManRect r, byte c, double density) { for (int y = r.Y; y < r.Y + r.H; y++) for (int x = r.X; x < r.X + r.W; x++) if (Rnd.NextDouble() < density) Px(x, y, c); }

    public ManRect R(string name, int x, int y, int w, int h) { ManRect r = new ManRect(name, x, y, w, h); Rects.Add(r); return r; }

    // ---------------- output ----------------
    public void SavePng(string path)
    {
        Bitmap bm = new Bitmap(TW, TW, PixelFormat.Format32bppArgb);
        for (int y = 0; y < TW; y++) for (int x = 0; x < TW; x++) { byte c = Tex[y * TW + x]; bm.SetPixel(x, y, c == T ? Color.FromArgb(0, 255, 255, 255) : Pal[c]); }
        bm.Save(path, ImageFormat.Png); bm.Dispose();
    }
    public void SaveAtlas(string path, int scale)
    {
        Bitmap bm = new Bitmap(TW * scale, TW * scale);
        using (Graphics g = Graphics.FromImage(bm))
        {
            g.Clear(Color.FromArgb(40, 40, 60));
            for (int y = 0; y < TW; y++) for (int x = 0; x < TW; x++) { byte c = Tex[y * TW + x]; if (c != T) using (SolidBrush b = new SolidBrush(Pal[c])) g.FillRectangle(b, x * scale, y * scale, scale, scale); }
            using (Pen p = new Pen(Color.FromArgb(255, 0, 255))) using (Font f = new Font("Segoe UI", 7)) foreach (ManRect r in Rects) { g.DrawRectangle(p, r.X * scale, r.Y * scale, r.W * scale - 1, r.H * scale - 1); g.DrawString(r.Name, f, Brushes.Magenta, r.X * scale + 1, r.Y * scale); }
        }
        bm.Save(path, ImageFormat.Png); bm.Dispose();
    }
    // 3DS: MAIN { EDITOR { OBJECT "man" { TRIMESH { VERTS, UV, FACES } } } } ; file is Z-up: (x, y, z) -> (x, -z, y)
    public void Save3ds(string path)
    {
        MemoryStream mesh = new MemoryStream(); BinaryWriter w = new BinaryWriter(mesh);
        int nv = V.Count, nf = F.Count;
        w.Write((ushort)0x4110); w.Write((uint)(8 + nv * 12)); w.Write((ushort)nv);
        foreach (float[] p in V) { w.Write(p[0]); w.Write(-p[2]); w.Write(p[1]); }
        w.Write((ushort)0x4140); w.Write((uint)(8 + nv * 8)); w.Write((ushort)nv);
        foreach (float[] t in UV) { w.Write((float)(t[0] / TW)); w.Write((float)(1.0 - t[1] / TW)); }
        w.Write((ushort)0x4120); w.Write((uint)(8 + nf * 8)); w.Write((ushort)nf);
        foreach (int[] f in F) { w.Write((ushort)f[0]); w.Write((ushort)f[1]); w.Write((ushort)f[2]); w.Write((ushort)7); }
        byte[] meshBytes = mesh.ToArray();
        byte[] name = System.Text.Encoding.ASCII.GetBytes("man\0");
        uint triLen = (uint)(6 + meshBytes.Length), objLen = (uint)(6 + name.Length + triLen), edLen = 6 + objLen, mainLen = 6 + edLen;
        using (BinaryWriter o = new BinaryWriter(File.Create(path)))
        {
            o.Write((ushort)0x4D4D); o.Write(mainLen);
            o.Write((ushort)0x3D3D); o.Write(edLen);
            o.Write((ushort)0x4000); o.Write(objLen); o.Write(name);
            o.Write((ushort)0x4100); o.Write(triLen); o.Write(meshBytes);
        }
    }

    // ---------------- preview renderer (what C3DTRI does: nearest texel, no light, painter's order) ----------------
    // the game camera is at the origin looking down +z, the model at camDist; yaw 0 = his front (-z) towards the camera
    public Bitmap Render(double yaw, double camDist, int W, int H, double f, double stretchY, double pitchDeg, double yOffCm)
    {
        float minx = 1e9f, maxx = -1e9f, miny = 1e9f, maxy = -1e9f, minz = 1e9f, maxz = -1e9f;
        foreach (float[] p in V) { minx = Math.Min(minx, p[0]); maxx = Math.Max(maxx, p[0]); miny = Math.Min(miny, p[1]); maxy = Math.Max(maxy, p[1]); minz = Math.Min(minz, p[2]); maxz = Math.Max(maxz, p[2]); }
        double cx = (minx + maxx) / 2, cy = (miny + maxy) / 2, cz = (minz + maxz) / 2;
        double cs = Math.Cos(yaw), sn = Math.Sin(yaw), cp = Math.Cos(pitchDeg * Math.PI / 180), sp = Math.Sin(pitchDeg * Math.PI / 180);
        int n = V.Count; double[] sx = new double[n], sy = new double[n], sz = new double[n];
        for (int i = 0; i < n; i++)
        {
            double x = V[i][0] - cx, y = V[i][1] - cy - yOffCm * S, z = V[i][2] - cz;
            double rx = x * cs - z * sn, rz = x * sn + z * cs;
            double ry = y * cp - rz * sp; rz = y * sp + rz * cp;
            rz += camDist;
            sx[i] = W / 2.0 + f * rx / rz; sy[i] = H / 2.0 - f * ry / rz; sz[i] = rz;
        }
        Bitmap bm = new Bitmap(W, H);
        byte[] px = new byte[W * H]; for (int i = 0; i < px.Length; i++) px[i] = 254;
        int[] order = new int[F.Count]; double[] depth = new double[F.Count];
        for (int i = 0; i < F.Count; i++) { order[i] = i; depth[i] = (sz[F[i][0]] + sz[F[i][1]] + sz[F[i][2]]) / 3; }
        Array.Sort(depth, order); Array.Reverse(order);
        foreach (int fi in order)
        {
            int[] fc = F[fi];
            double ax = sx[fc[0]], ay = sy[fc[0]], bx = sx[fc[1]], by = sy[fc[1]], cxx = sx[fc[2]], cyy = sy[fc[2]];
            double area = (bx - ax) * (cyy - ay) - (cxx - ax) * (by - ay);
            if (area <= 0) continue;   // back face: a face whose normal points at the camera has a positive screen area (y down)
            int x0 = (int)Math.Floor(Math.Min(ax, Math.Min(bx, cxx))), x1 = (int)Math.Ceiling(Math.Max(ax, Math.Max(bx, cxx)));
            int y0 = (int)Math.Floor(Math.Min(ay, Math.Min(by, cyy))), y1 = (int)Math.Ceiling(Math.Max(ay, Math.Max(by, cyy)));
            for (int y = Math.Max(0, y0); y <= Math.Min(H - 1, y1); y++) for (int x = Math.Max(0, x0); x <= Math.Min(W - 1, x1); x++)
            {
                double pxc = x + 0.5, pyc = y + 0.5;
                double w0 = ((bx - pxc) * (cyy - pyc) - (cxx - pxc) * (by - pyc)) / area;
                double w1 = ((cxx - pxc) * (ay - pyc) - (ax - pxc) * (cyy - pyc)) / area;
                double w2 = 1 - w0 - w1;
                if (w0 < 0 || w1 < 0 || w2 < 0) continue;
                double u = w0 * UV[fc[0]][0] + w1 * UV[fc[1]][0] + w2 * UV[fc[2]][0];
                double v = w0 * UV[fc[0]][1] + w1 * UV[fc[1]][1] + w2 * UV[fc[2]][1];
                int tx = Math.Min(TW - 1, Math.Max(0, (int)u)), ty = Math.Min(TW - 1, Math.Max(0, (int)v));
                byte c = Tex[ty * TW + tx];
                if (c == T) continue;
                px[y * W + x] = c;
            }
        }
        // the silhouette ink (C3DEDGE): an outline where the model meets the background; the engine draws it orange
        byte[] px2 = (byte[])px.Clone();
        for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) if (px[y * W + x] == 254)
            { bool edge = false; if (x > 0 && px[y * W + x - 1] != 254) edge = true; if (x < W - 1 && px[y * W + x + 1] != 254) edge = true; if (y > 0 && px[(y - 1) * W + x] != 254) edge = true; if (y < H - 1 && px[(y + 1) * W + x] != 254) edge = true; if (edge) px2[y * W + x] = O; }
        Color bg = Color.FromArgb(60, 60, 60);
        for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) { byte c = px2[y * W + x]; bm.SetPixel(x, y, c == 254 ? bg : Pal[c]); }
        if (stretchY != 1) { Bitmap s = new Bitmap(W, (int)(H * stretchY)); using (Graphics g = Graphics.FromImage(s)) { g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.NearestNeighbor; g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.Half; g.DrawImage(bm, 0, 0, W, (int)(H * stretchY)); } bm.Dispose(); return s; }
        return bm;
    }
}
