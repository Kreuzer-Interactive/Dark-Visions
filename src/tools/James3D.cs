// James3D.cs - paints a texture for the man's mesh in 3D: every texel a face's UV triangle covers is given
// the body point it lands on (rest pose, bone piece, height, front/back, side), and james3d.ps1's rules
// colour it from there. Same mesh = same rig, so the walk/idle/turn clips play on James unchanged.
using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;

public class JamesTex
{
    public List<float[]> V = new List<float[]>();   // x, y, z (Y up, front = -Z), as tdsview reads the 3DS
    public List<float[]> UV = new List<float[]>();  // texels, top-down
    public List<int[]> F = new List<int[]>();
    public int[] Piece;                              // per vertex: connected piece (welded positions)
    public int[] FacePiece;
    public int NPiece;
    public float[][] PBox;                           // per piece: xmin xmax ymin ymax zmin zmax
    public float YMin, YMax;
    public int TW = 128;
    // per texel: the face that covers it (-1 none), the 3D point, the face normal, count of covering faces
    public int[] TFace; public float[][] TPos; public float[][] TNrm; public int[] TCnt; public bool[] TConflict;

    public void Load3ds(string path)
    {
        byte[] b = File.ReadAllBytes(path);
        int o = 0, bas = 0;
        while (o < b.Length)
        {
            int id = BitConverter.ToUInt16(b, o); int len = (int)BitConverter.ToUInt32(b, o + 2);
            if (id == 0x4D4D || id == 0x3D3D || id == 0x4100) { o += 6; continue; }
            if (id == 0x4000) { int p = o + 6; while (b[p] != 0) p++; o = p + 1; bas = V.Count; continue; }
            if (id == 0x4110) { int n = BitConverter.ToUInt16(b, o + 6); for (int i = 0; i < n; i++) { V.Add(new float[] { BitConverter.ToSingle(b, o + 8 + i * 12), BitConverter.ToSingle(b, o + 16 + i * 12), -BitConverter.ToSingle(b, o + 12 + i * 12) }); UV.Add(new float[] { 0, 0 }); } }
            else if (id == 0x4140) { int n = BitConverter.ToUInt16(b, o + 6); for (int i = 0; i < n && bas + i < V.Count; i++) UV[bas + i] = new float[] { BitConverter.ToSingle(b, o + 8 + i * 8) * TW, (1 - BitConverter.ToSingle(b, o + 12 + i * 8)) * TW }; }
            else if (id == 0x4120) { int n = BitConverter.ToUInt16(b, o + 6); for (int i = 0; i < n; i++) F.Add(new int[] { bas + BitConverter.ToUInt16(b, o + 8 + i * 8), bas + BitConverter.ToUInt16(b, o + 10 + i * 8), bas + BitConverter.ToUInt16(b, o + 12 + i * 8) }); }
            o += len;
        }
        YMin = float.MaxValue; YMax = float.MinValue;
        foreach (var v in V) { YMin = Math.Min(YMin, v[1]); YMax = Math.Max(YMax, v[1]); }
        FindPieces();
        // outward winding check (centre on y) as tdsview does; the normals below assume outward
        float cy = (YMin + YMax) / 2; int inward = 0;
        foreach (var f in F) { var n = Normal(f); float mx = 0, my = 0, mz = 0; for (int k = 0; k < 3; k++) { mx += V[f[k]][0] / 3; my += V[f[k]][1] / 3 - cy / 3; mz += V[f[k]][2] / 3; } if (n[0] * mx + n[1] * my + n[2] * mz < 0) inward++; }
        if (inward > F.Count / 2) for (int i = 0; i < F.Count; i++) F[i] = new int[] { F[i][0], F[i][2], F[i][1] };
    }

    public float[] Normal(int[] f)
    {
        float[] a = V[f[0]], b = V[f[1]], c = V[f[2]];
        float ux = b[0] - a[0], uy = b[1] - a[1], uz = b[2] - a[2], wx = c[0] - a[0], wy = c[1] - a[1], wz = c[2] - a[2];
        float nx = uy * wz - uz * wy, ny = uz * wx - ux * wz, nz = ux * wy - uy * wx;
        float l = (float)Math.Sqrt(nx * nx + ny * ny + nz * nz); if (l < 1e-9f) l = 1;
        return new float[] { nx / l, ny / l, nz / l };
    }

    int Find(int[] p, int i) { while (p[i] != i) { p[i] = p[p[i]]; i = p[i]; } return i; }
    void FindPieces()
    {
        int n = V.Count; int[] p = new int[n]; for (int i = 0; i < n; i++) p[i] = i;
        var key = new Dictionary<string, int>();
        for (int i = 0; i < n; i++) { string k = Math.Round(V[i][0], 2) + "," + Math.Round(V[i][1], 2) + "," + Math.Round(V[i][2], 2); int j; if (key.TryGetValue(k, out j)) p[Find(p, i)] = Find(p, j); else key[k] = i; }
        foreach (var f in F) { p[Find(p, f[1])] = Find(p, f[0]); p[Find(p, f[2])] = Find(p, f[0]); }
        var ids = new Dictionary<int, int>(); Piece = new int[n];
        for (int i = 0; i < n; i++) { int r = Find(p, i); int id; if (!ids.TryGetValue(r, out id)) { id = ids.Count; ids[r] = id; } Piece[i] = id; }
        NPiece = ids.Count; PBox = new float[NPiece][];
        for (int i = 0; i < NPiece; i++) PBox[i] = new float[] { 1e9f, -1e9f, 1e9f, -1e9f, 1e9f, -1e9f };
        for (int i = 0; i < n; i++) { var bx = PBox[Piece[i]]; for (int a = 0; a < 3; a++) { bx[2 * a] = Math.Min(bx[2 * a], V[i][a]); bx[2 * a + 1] = Math.Max(bx[2 * a + 1], V[i][a]); } }
        FacePiece = new int[F.Count]; for (int i = 0; i < F.Count; i++) FacePiece[i] = Piece[F[i][0]];
    }

    // rasterise every face's UV triangle (texel centres inside, plus a half-texel grow so thin slivers get texels)
    public void MapTexels()
    {
        int N = TW * TW; TFace = new int[N]; TPos = new float[N][]; TNrm = new float[N][]; TCnt = new int[N]; TConflict = new bool[N];
        for (int i = 0; i < N; i++) TFace[i] = -1;
        double[] bestD = new double[N]; for (int i = 0; i < N; i++) bestD[i] = 1e9;
        for (int fi = 0; fi < F.Count; fi++)
        {
            int[] f = F[fi]; float[] a = UV[f[0]], b = UV[f[1]], c = UV[f[2]];
            double area = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
            if (Math.Abs(area) < 1e-9) continue;
            int x0 = (int)Math.Floor(Math.Min(a[0], Math.Min(b[0], c[0])) - 1), x1 = (int)Math.Ceiling(Math.Max(a[0], Math.Max(b[0], c[0])) + 1);
            int y0 = (int)Math.Floor(Math.Min(a[1], Math.Min(b[1], c[1])) - 1), y1 = (int)Math.Ceiling(Math.Max(a[1], Math.Max(b[1], c[1])) + 1);
            float[] nrm = Normal(f);
            for (int y = Math.Max(0, y0); y <= Math.Min(TW - 1, y1); y++)
                for (int x = Math.Max(0, x0); x <= Math.Min(TW - 1, x1); x++)
                {
                    double px = x + 0.5, py = y + 0.5;
                    double w1 = ((px - a[0]) * (c[1] - a[1]) - (py - a[1]) * (c[0] - a[0])) / area;
                    double w2 = ((b[0] - a[0]) * (py - a[1]) - (b[1] - a[1]) * (px - a[0])) / area;
                    double w0 = 1 - w1 - w2;
                    double outside = Math.Max(0, -Math.Min(w0, Math.Min(w1, w2)));
                    // distance outside in texels (rough): weight deficit * triangle size
                    double size = Math.Sqrt(Math.Abs(area));
                    double d = outside * size;
                    if (d > 0.71) continue;
                    int t = y * TW + x;
                    if (d == 0) TCnt[t]++;
                    if (d < bestD[t])
                    {
                        if (d == 0 && TFace[t] >= 0 && bestD[t] == 0 && FacePiece[TFace[t]] != FacePiece[fi]) TConflict[t] = true;
                        bestD[t] = d; TFace[t] = fi;
                        double cw0 = Math.Max(0, w0), cw1 = Math.Max(0, w1), cw2 = Math.Max(0, w2), s = cw0 + cw1 + cw2;
                        cw0 /= s; cw1 /= s; cw2 /= s;
                        float[] pa = V[f[0]], pb = V[f[1]], pc = V[f[2]];
                        TPos[t] = new float[] { (float)(pa[0] * cw0 + pb[0] * cw1 + pc[0] * cw2), (float)(pa[1] * cw0 + pb[1] * cw1 + pc[1] * cw2), (float)(pa[2] * cw0 + pb[2] * cw1 + pc[2] * cw2) };
                        TNrm[t] = nrm;
                    }
                    else if (d == 0 && bestD[t] == 0 && FacePiece[TFace[t]] != FacePiece[fi]) TConflict[t] = true;
                }
        }
    }
}
