# fbx2tds.ps1 - a binary FBX (7.x, one mesh, as 3ds Max exports it) -> a 3DS file that
# car3dcnv.ps1 reads: the polygons triangulated (fans), the per-corner UVs turned into
# per-vertex ones by splitting vertices that are used with different UVs. The vertex
# data is written as it is in the FBX (Max puts a -90 deg PreRotation on the node and
# leaves the mesh Z-up, which is what 3DS is), so no axis change is made here.
# Usage: fbx2tds.ps1 -In src\ART\Man3d\Man3d_v2.fbx [-Out src\ART\Man3d\man_v2.3ds] [-FlipV]
param(
  [Parameter(Mandatory = $true)][string]$In,
  [string]$Out = "",
  [switch]$FlipV
)
$ErrorActionPreference = 'Stop'
if (-not $Out) { $Out = [IO.Path]::ChangeExtension($In, '.3ds') }

$code = @'
using System; using System.IO; using System.Text; using System.Collections.Generic; using System.IO.Compression;
public class FbxMesh {
    public double[] Verts; public int[] PolyIdx; public double[] UV; public int[] UVIdx; public string UVMap = "", UVRef = "";
    public string Report = "";
    byte[] b; int pos; bool big;
    public static FbxMesh Load(string path) { FbxMesh m = new FbxMesh(); m.b = File.ReadAllBytes(path); uint ver = BitConverter.ToUInt32(m.b, 23); m.big = ver >= 7500; m.pos = 27; while (m.pos < m.b.Length) { if (!m.Node("")) break; } return m; }
    ulong ReadOff() { if (big) { ulong v = BitConverter.ToUInt64(b, pos); pos += 8; return v; } else { uint v = BitConverter.ToUInt32(b, pos); pos += 4; return v; } }
    bool Node(string parent) {
        ulong end = ReadOff(); ulong nprops = ReadOff(); ulong plen = ReadOff();
        int nlen = b[pos++]; string name = Encoding.ASCII.GetString(b, pos, nlen); pos += nlen;
        if (end == 0) return false;
        object[] props = new object[nprops];
        for (ulong i = 0; i < nprops; i++) props[i] = Prop();
        if (parent == "Geometry" && name == "Vertices" && Verts == null) Verts = (double[])props[0];
        if (parent == "Geometry" && name == "PolygonVertexIndex" && PolyIdx == null) PolyIdx = (int[])props[0];
        if (parent == "LayerElementUV" && name == "UV" && UV == null) UV = (double[])props[0];
        if (parent == "LayerElementUV" && name == "UVIndex" && UVIdx == null) UVIdx = (int[])props[0];
        if (parent == "LayerElementUV" && name == "MappingInformationType" && UVMap == "") UVMap = (string)props[0];
        if (parent == "LayerElementUV" && name == "ReferenceInformationType" && UVRef == "") UVRef = (string)props[0];
        while ((ulong)pos < end) { if (!Node(name)) break; }
        pos = (int)end; return true;
    }
    object Prop() {
        char t = (char)b[pos++];
        switch (t) {
            case 'Y': { short v = BitConverter.ToInt16(b, pos); pos += 2; return v; }
            case 'C': { byte v = b[pos++]; return v != 0; }
            case 'I': { int v = BitConverter.ToInt32(b, pos); pos += 4; return v; }
            case 'F': { float v = BitConverter.ToSingle(b, pos); pos += 4; return v; }
            case 'D': { double v = BitConverter.ToDouble(b, pos); pos += 8; return v; }
            case 'L': { long v = BitConverter.ToInt64(b, pos); pos += 8; return v; }
            case 'S': { int n = BitConverter.ToInt32(b, pos); pos += 4; string s = Encoding.UTF8.GetString(b, pos, n); pos += n; return s; }
            case 'R': { int n = BitConverter.ToInt32(b, pos); pos += 4; pos += n; return null; }
            case 'f': case 'd': case 'l': case 'i': case 'b': {
                int n = BitConverter.ToInt32(b, pos); int enc = BitConverter.ToInt32(b, pos + 4); int clen = BitConverter.ToInt32(b, pos + 8); pos += 12;
                int esz = (t == 'f' || t == 'i') ? 4 : (t == 'b' ? 1 : 8);
                byte[] data = new byte[n * esz];
                if (enc == 1) { using (var ms = new MemoryStream(b, pos + 2, clen - 2)) using (var ds = new DeflateStream(ms, CompressionMode.Decompress)) { int got = 0; while (got < data.Length) { int r = ds.Read(data, got, data.Length - got); if (r <= 0) break; got += r; } } }
                else Array.Copy(b, pos, data, 0, n * esz);
                pos += clen;
                if (t == 'd') { double[] a = new double[n]; for (int i = 0; i < n; i++) a[i] = BitConverter.ToDouble(data, i * 8); return a; }
                if (t == 'f') { double[] a = new double[n]; for (int i = 0; i < n; i++) a[i] = BitConverter.ToSingle(data, i * 4); return a; }
                if (t == 'i') { int[] a = new int[n]; for (int i = 0; i < n; i++) a[i] = BitConverter.ToInt32(data, i * 4); return a; }
                if (t == 'l') { long[] a = new long[n]; for (int i = 0; i < n; i++) a[i] = BitConverter.ToInt64(data, i * 8); return a; }
                return data;
            }
            default: return null;
        }
    }
    // -> 3DS: vertices split per (vertex, uv) pair, polygons as triangle fans
    public string Write3ds(string path, bool flipV) {
        int nv0 = Verts.Length / 3;
        List<float[]> V = new List<float[]>(); List<float[]> T = new List<float[]>(); List<int[]> F = new List<int[]>();
        Dictionary<string, int> map = new Dictionary<string, int>();
        List<int> poly = new List<int>(); List<int> pvi = new List<int>(); List<double> pu = new List<double>(); List<double> pv = new List<double>(); int corner = 0; int npoly = 0, nquad = 0, nbig = 0, nwrap = 0, nseam = 0;
        for (int i = 0; i < PolyIdx.Length; i++) {
            int vi = PolyIdx[i]; bool last = vi < 0; if (last) vi = ~vi;
            double u = 0, v = 0;
            if (UV != null) {
                int ui;
                if (UVMap == "ByPolygonVertex") ui = (UVRef == "IndexToDirect" && UVIdx != null) ? UVIdx[corner] : corner;
                else ui = (UVRef == "IndexToDirect" && UVIdx != null) ? UVIdx[vi] : vi;   // ByControlPoint
                u = UV[ui * 2]; v = UV[ui * 2 + 1];
                if (flipV) v = 1 - v;
            }
            pvi.Add(vi); pu.Add(u); pv.Add(v); corner++;
            if (last) {
                npoly++; if (pvi.Count == 4) nquad++; if (pvi.Count > 4) nbig++;
                // the polygon's uv brought back into 0..1 by whole turns (the engine clamps, it does not wrap)
                double pmu = 1e9, pmv = 1e9; for (int k = 0; k < pvi.Count; k++) { pmu = Math.Min(pmu, pu[k]); pmv = Math.Min(pmv, pv[k]); }
                double qmu = -1e9, qmv = -1e9; for (int k = 0; k < pvi.Count; k++) { qmu = Math.Max(qmu, pu[k]); qmv = Math.Max(qmv, pv[k]); }
                double du = Math.Floor((pmu + qmu) / 2), dv = Math.Floor((pmv + qmv) / 2);   // by the centre, not the lowest corner if (du != 0 || dv != 0) nwrap++;
                // a polygon across the seam (u from ~0.97 to ~0.03): the small side moved up a turn, so the face spans
                // ~0.97..1.03 and the engine's clamp at 1 shows the seam column instead of the whole atlas
                double pxu = -1e9, pxv = -1e9; for (int k = 0; k < pvi.Count; k++) { pxu = Math.Max(pxu, pu[k] - du); pxv = Math.Max(pxv, pv[k] - dv); }
                bool seamU = (pxu - (pmu - du)) > 0.5, seamV = (pxv - (pmv - dv)) > 0.5; if (seamU || seamV) nseam++;
                for (int k = 0; k < pvi.Count; k++) {
                    double uu = pu[k] - du, vv = pv[k] - dv; if (seamU && uu < 0.5) uu += 1; if (seamV && vv < 0.5) vv += 1;
                    string key = pvi[k] + "|" + uu.ToString("R") + "|" + vv.ToString("R");
                    int idx;
                    if (!map.TryGetValue(key, out idx)) { idx = V.Count; map[key] = idx; V.Add(new float[] { (float)Verts[pvi[k] * 3], (float)Verts[pvi[k] * 3 + 1], (float)Verts[pvi[k] * 3 + 2] }); T.Add(new float[] { (float)uu, (float)vv }); }
                    poly.Add(idx);
                }
                for (int k = 1; k + 1 < poly.Count; k++) F.Add(new int[] { poly[0], poly[k], poly[k + 1] });
                poly.Clear(); pvi.Clear(); pu.Clear(); pv.Clear();
            }
        }
        int nv = V.Count, nf = F.Count;
        MemoryStream mesh = new MemoryStream(); BinaryWriter w = new BinaryWriter(mesh);
        w.Write((ushort)0x4110); w.Write((uint)(8 + nv * 12)); w.Write((ushort)nv);
        foreach (float[] p in V) { w.Write(p[0]); w.Write(p[1]); w.Write(p[2]); }
        w.Write((ushort)0x4140); w.Write((uint)(8 + nv * 8)); w.Write((ushort)nv);
        foreach (float[] t in T) { w.Write(t[0]); w.Write(t[1]); }
        w.Write((ushort)0x4120); w.Write((uint)(8 + nf * 8)); w.Write((ushort)nf);
        foreach (int[] f in F) { w.Write((ushort)f[0]); w.Write((ushort)f[1]); w.Write((ushort)f[2]); w.Write((ushort)7); }
        byte[] meshBytes = mesh.ToArray(); byte[] name = Encoding.ASCII.GetBytes("mesh\0");
        uint triLen = (uint)(6 + meshBytes.Length), objLen = (uint)(6 + name.Length + triLen), edLen = 6 + objLen, mainLen = 6 + edLen;
        using (BinaryWriter o = new BinaryWriter(File.Create(path))) {
            o.Write((ushort)0x4D4D); o.Write(mainLen); o.Write((ushort)0x3D3D); o.Write(edLen);
            o.Write((ushort)0x4000); o.Write(objLen); o.Write(name); o.Write((ushort)0x4100); o.Write(triLen); o.Write(meshBytes);
        }
        double minx = 1e9, maxx = -1e9, miny = 1e9, maxy = -1e9, minz = 1e9, maxz = -1e9, minu = 1e9, maxu = -1e9, minv = 1e9, maxv = -1e9;
        foreach (float[] p in V) { minx = Math.Min(minx, p[0]); maxx = Math.Max(maxx, p[0]); miny = Math.Min(miny, p[1]); maxy = Math.Max(maxy, p[1]); minz = Math.Min(minz, p[2]); maxz = Math.Max(maxz, p[2]); }
        foreach (float[] t in T) { minu = Math.Min(minu, t[0]); maxu = Math.Max(maxu, t[0]); minv = Math.Min(minv, t[1]); maxv = Math.Max(maxv, t[1]); }
        return "fbx: " + nv0 + " control points, " + npoly + " polygons (" + nquad + " quads, " + nbig + " bigger, " + nwrap + " shifted back into 0..1, " + nseam + " across the seam), uv " + UVMap + "/" + UVRef + "\n3ds: " + nv + " vertices (split by uv), " + nf + " triangles\nextent x " + minx.ToString("0.0") + ".." + maxx.ToString("0.0") + "  y " + miny.ToString("0.0") + ".." + maxy.ToString("0.0") + "  z " + minz.ToString("0.0") + ".." + maxz.ToString("0.0") + "  (file axes)\nuv u " + minu.ToString("0.000") + ".." + maxu.ToString("0.000") + "  v " + minv.ToString("0.000") + ".." + maxv.ToString("0.000");
    }
}
'@
Add-Type -TypeDefinition $code -ReferencedAssemblies System.IO.Compression
$m = [FbxMesh]::Load((Resolve-Path $In).Path)
if (-not $m.Verts -or -not $m.PolyIdx) { throw "no mesh in $In" }
$m.Write3ds($Out, $FlipV.IsPresent)
"-> $Out"
