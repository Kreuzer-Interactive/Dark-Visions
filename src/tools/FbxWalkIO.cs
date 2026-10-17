// FbxWalkIO.cs - FBX in and out for the 3D man's walk (2026-10-16).
//   Fbx.Load        a binary (7.x, as 3ds Max writes it) or ASCII FBX into a node tree
//   FbxScene        objects, connections, node transforms (the FBX formula with pre/post
//                   rotation, pivots and offsets), animation curves (linear between keys:
//                   export from Max with Bake Animation on), skin clusters
//   FbxScene.Split  the mesh's vertices split by UV exactly as fbx2tds.ps1 splits them, so
//                   index i here = vertex i of the 3DS / CAR3D.MDL made from the same FBX
//   FbxWalkIO.Write an ASCII FBX 7.4: the source mesh, a "Rig" null with the mesh's own
//                   transform, 13 bones, the skin, the bind pose and the walk as keys
using System; using System.IO; using System.Text; using System.Collections.Generic; using System.IO.Compression; using System.Globalization;

public class FbxNode {
    public string Name; public List<object> Props = new List<object>(); public List<FbxNode> Kids = new List<FbxNode>();
    public FbxNode Kid(string n) { foreach (FbxNode k in Kids) if (k.Name == n) return k; return null; }
    public List<FbxNode> All(string n) { List<FbxNode> r = new List<FbxNode>(); foreach (FbxNode k in Kids) if (k.Name == n) r.Add(k); return r; }
}

public static class Fbx {
    static readonly CultureInfo IC = CultureInfo.InvariantCulture;
    public static FbxNode Load(string path) {
        byte[] b = File.ReadAllBytes(path);
        if (b.Length > 20 && Encoding.ASCII.GetString(b, 0, 18) == "Kaydara FBX Binary") return LoadBinary(b);
        return LoadAscii(Encoding.UTF8.GetString(b));
    }
    // ---- binary
    static byte[] bb; static int bp; static bool big;
    static FbxNode LoadBinary(byte[] b) {
        bb = b; uint ver = BitConverter.ToUInt32(b, 23); big = ver >= 7500; bp = 27;
        FbxNode root = new FbxNode { Name = "" };
        while (bp < bb.Length) { FbxNode n = BNode(); if (n == null) break; root.Kids.Add(n); }
        return root;
    }
    static ulong Off() { if (big) { ulong v = BitConverter.ToUInt64(bb, bp); bp += 8; return v; } uint w = BitConverter.ToUInt32(bb, bp); bp += 4; return w; }
    static FbxNode BNode() {
        ulong end = Off(); ulong np = Off(); Off();
        int nl = bb[bp++]; string name = Encoding.ASCII.GetString(bb, bp, nl); bp += nl;
        if (end == 0) return null;
        FbxNode n = new FbxNode { Name = name };
        for (ulong i = 0; i < np; i++) n.Props.Add(BProp());
        while ((ulong)bp < end) { FbxNode k = BNode(); if (k == null) break; n.Kids.Add(k); }
        bp = (int)end; return n;
    }
    static object BProp() {
        char t = (char)bb[bp++];
        switch (t) {
            case 'Y': { short v = BitConverter.ToInt16(bb, bp); bp += 2; return (long)v; }
            case 'C': { byte v = bb[bp++]; return (long)v; }
            case 'I': { int v = BitConverter.ToInt32(bb, bp); bp += 4; return (long)v; }
            case 'F': { float v = BitConverter.ToSingle(bb, bp); bp += 4; return (double)v; }
            case 'D': { double v = BitConverter.ToDouble(bb, bp); bp += 8; return v; }
            case 'L': { long v = BitConverter.ToInt64(bb, bp); bp += 8; return v; }
            case 'S': { int n = BitConverter.ToInt32(bb, bp); bp += 4; string s = Encoding.UTF8.GetString(bb, bp, n); bp += n; return s; }
            case 'R': { int n = BitConverter.ToInt32(bb, bp); bp += 4; bp += n; return null; }
            case 'f': case 'd': case 'l': case 'i': case 'b': {
                int n = BitConverter.ToInt32(bb, bp); int enc = BitConverter.ToInt32(bb, bp + 4); int clen = BitConverter.ToInt32(bb, bp + 8); bp += 12;
                int esz = (t == 'f' || t == 'i') ? 4 : (t == 'b' ? 1 : 8);
                byte[] data = new byte[n * esz];
                if (enc == 1) { using (MemoryStream ms = new MemoryStream(bb, bp + 2, clen - 2)) using (DeflateStream ds = new DeflateStream(ms, CompressionMode.Decompress)) { int got = 0; while (got < data.Length) { int r = ds.Read(data, got, data.Length - got); if (r <= 0) break; got += r; } } }
                else Array.Copy(bb, bp, data, 0, n * esz);
                bp += clen;
                if (t == 'd') { double[] a = new double[n]; for (int i = 0; i < n; i++) a[i] = BitConverter.ToDouble(data, i * 8); return a; }
                if (t == 'f') { double[] a = new double[n]; for (int i = 0; i < n; i++) a[i] = BitConverter.ToSingle(data, i * 4); return a; }
                if (t == 'i') { long[] a = new long[n]; for (int i = 0; i < n; i++) a[i] = BitConverter.ToInt32(data, i * 4); return a; }
                if (t == 'l') { long[] a = new long[n]; for (int i = 0; i < n; i++) a[i] = BitConverter.ToInt64(data, i * 8); return a; }
                long[] c = new long[n]; for (int i = 0; i < n; i++) c[i] = data[i]; return c;
            }
            default: throw new Exception("FBX: unknown property type " + t);
        }
    }
    // ---- ASCII: Name: prop, prop, ... { children }   arrays: *N { a: v, v, ... }
    static List<string> tk; static int ti;
    static FbxNode LoadAscii(string s) {
        tk = new List<string>(); int i = 0, n = s.Length;
        while (i < n) {
            char c = s[i];
            if (char.IsWhiteSpace(c)) { i++; continue; }
            if (c == ';') { while (i < n && s[i] != '\n') i++; continue; }
            if (c == '"') { int j = s.IndexOf('"', i + 1); if (j < 0) j = n; tk.Add(s.Substring(i, j - i + 1)); i = j + 1; continue; }
            if (c == ':' || c == ',' || c == '{' || c == '}' || c == '*') { tk.Add(c.ToString()); i++; continue; }
            int k = i; while (k < n && !char.IsWhiteSpace(s[k]) && s[k] != ':' && s[k] != ',' && s[k] != '{' && s[k] != '}' && s[k] != '"' && s[k] != ';') k++;
            tk.Add(s.Substring(i, k - i)); i = k;
        }
        ti = 0; FbxNode root = new FbxNode { Name = "" };
        while (ti < tk.Count) { FbxNode nd = ANode(); if (nd == null) break; root.Kids.Add(nd); }
        return root;
    }
    static bool IsName(int k) { return k + 1 < tk.Count && tk[k + 1] == ":" && tk[k].Length > 0 && (char.IsLetter(tk[k][0]) || tk[k][0] == '_'); }
    static FbxNode ANode() {
        if (ti >= tk.Count || tk[ti] == "}") return null;
        FbxNode n = new FbxNode { Name = tk[ti] }; ti += 2;   // name, ':'
        // properties: up to '{', the next "Name:", or '}'
        bool first = true;
        while (ti < tk.Count && tk[ti] != "{" && tk[ti] != "}" && !IsName(ti)) {
            if (!first) { if (tk[ti] != ",") break; ti++; }
            first = false;
            if (tk[ti] == "*") {   // an array: *N { a: values }
                ti += 2; if (tk[ti] != "{") throw new Exception("FBX ASCII: array without a block at " + n.Name);
                ti++; List<double> vals = new List<double>();
                if (tk[ti] == "a" && tk[ti + 1] == ":") { ti += 2; while (tk[ti] != "}") { if (tk[ti] != ",") vals.Add(double.Parse(tk[ti], NumberStyles.Float, IC)); ti++; } }
                ti++;   // '}'
                n.Props.Add(vals.ToArray());
                continue;
            }
            n.Props.Add(AValue(tk[ti])); ti++;
        }
        if (ti < tk.Count && tk[ti] == "{") { ti++; while (ti < tk.Count && tk[ti] != "}") { FbxNode k = ANode(); if (k == null) break; n.Kids.Add(k); } ti++; }
        return n;
    }
    static object AValue(string t) {
        if (t.StartsWith("\"")) return t.Substring(1, t.Length - 2);
        long l; if (long.TryParse(t, NumberStyles.Integer, IC, out l)) return l;
        double d; if (double.TryParse(t, NumberStyles.Float, IC, out d)) return d;
        return t;   // T, Y, W ... (flags)
    }
    // ---- values
    public static double D(object o) { if (o is long) return (long)o; if (o is double) return (double)o; if (o is string) return double.Parse((string)o, IC); return Convert.ToDouble(o, IC); }
    public static long L(object o) { if (o is long) return (long)o; if (o is double) return (long)Math.Round((double)o); return Convert.ToInt64(o, IC); }
    public static string S(object o) { return o == null ? "" : o.ToString(); }
    public static double[] Dbl(FbxNode n) { if (n == null || n.Props.Count == 0) return new double[0]; object o = n.Props[0]; if (o is double[]) return (double[])o; if (o is long[]) { long[] a = (long[])o; double[] r = new double[a.Length]; for (int i = 0; i < a.Length; i++) r[i] = a[i]; return r; } return new double[] { D(o) }; }
    public static long[] Lng(FbxNode n) { if (n == null || n.Props.Count == 0) return new long[0]; object o = n.Props[0]; if (o is long[]) return (long[])o; if (o is double[]) { double[] a = (double[])o; long[] r = new long[a.Length]; for (int i = 0; i < a.Length; i++) r[i] = (long)Math.Round(a[i]); return r; } return new long[] { L(o) }; }
    public static string Str(FbxNode n) { return n == null || n.Props.Count == 0 ? "" : S(n.Props[0]); }
}

// ---- 3x4 affine matrices, row-major: m[r*4+c], translation in m[3], m[7], m[11]
public static class M34 {
    public static double[] Id() { return new double[] { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0 }; }
    public static double[] Mul(double[] a, double[] b) {
        double[] m = new double[12];
        for (int r = 0; r < 3; r++) { for (int c = 0; c < 3; c++) m[r * 4 + c] = a[r * 4] * b[c] + a[r * 4 + 1] * b[4 + c] + a[r * 4 + 2] * b[8 + c]; m[r * 4 + 3] = a[r * 4] * b[3] + a[r * 4 + 1] * b[7] + a[r * 4 + 2] * b[11] + a[r * 4 + 3]; }
        return m;
    }
    public static double[] T(double x, double y, double z) { return new double[] { 1, 0, 0, x, 0, 1, 0, y, 0, 0, 1, z }; }
    public static double[] S(double x, double y, double z) { return new double[] { x, 0, 0, 0, 0, y, 0, 0, 0, 0, z, 0 }; }
    // Euler XYZ in degrees (FBX eEulerXYZ: X applied first): R = Rz * Ry * Rx
    public static double[] Euler(double xd, double yd, double zd) {
        double a = xd * Math.PI / 180, b = yd * Math.PI / 180, c = zd * Math.PI / 180;
        double[] rx = { 1, 0, 0, 0, 0, Math.Cos(a), -Math.Sin(a), 0, 0, Math.Sin(a), Math.Cos(a), 0 };
        double[] ry = { Math.Cos(b), 0, Math.Sin(b), 0, 0, 1, 0, 0, -Math.Sin(b), 0, Math.Cos(b), 0 };
        double[] rz = { Math.Cos(c), -Math.Sin(c), 0, 0, Math.Sin(c), Math.Cos(c), 0, 0, 0, 0, 1, 0 };
        return Mul(rz, Mul(ry, rx));
    }
    public static double[] Inv(double[] m) {
        double a = m[0], b = m[1], c = m[2], d = m[4], e = m[5], f = m[6], g = m[8], h = m[9], i = m[10];
        double A = e * i - f * h, B = -(d * i - f * g), C = d * h - e * g;
        double det = a * A + b * B + c * C; if (Math.Abs(det) < 1e-12) throw new Exception("singular matrix");
        double[] r = new double[12];
        r[0] = A / det; r[1] = -(b * i - c * h) / det; r[2] = (b * f - c * e) / det;
        r[4] = B / det; r[5] = (a * i - c * g) / det; r[6] = -(a * f - c * d) / det;
        r[8] = C / det; r[9] = -(a * h - b * g) / det; r[10] = (a * e - b * d) / det;
        r[3] = -(r[0] * m[3] + r[1] * m[7] + r[2] * m[11]); r[7] = -(r[4] * m[3] + r[5] * m[7] + r[6] * m[11]); r[11] = -(r[8] * m[3] + r[9] * m[7] + r[10] * m[11]);
        return r;
    }
    public static double[] Apply(double[] m, double x, double y, double z) { return new double[] { m[0] * x + m[1] * y + m[2] * z + m[3], m[4] * x + m[5] * y + m[6] * z + m[7], m[8] * x + m[9] * y + m[10] * z + m[11] }; }
    // FBX's 16 doubles: column-major for column vectors, translation in [12..14]
    public static double[] FromFbx(double[] a) { double[] m = new double[12]; for (int r = 0; r < 3; r++) { for (int c = 0; c < 3; c++) m[r * 4 + c] = a[c * 4 + r]; m[r * 4 + 3] = a[12 + r]; } return m; }
    public static double[] ToFbx(double[] m) { double[] a = new double[16]; for (int r = 0; r < 3; r++) { for (int c = 0; c < 3; c++) a[c * 4 + r] = m[r * 4 + c]; a[12 + r] = m[r * 4 + 3]; } a[15] = 1; return a; }
}

public class FbxScene {
    public FbxNode Root; public Dictionary<long, FbxNode> Obj = new Dictionary<long, FbxNode>();
    public class Conn { public string T; public long Child, Parent; public string Prop; }
    public List<Conn> Conns = new List<Conn>();
    public List<string> Notes = new List<string>();
    public static FbxScene Load(string path) {
        FbxScene s = new FbxScene(); s.Root = Fbx.Load(path);
        FbxNode objs = s.Root.Kid("Objects"); if (objs == null) throw new Exception("FBX: no Objects");
        foreach (FbxNode o in objs.Kids) if (o.Props.Count > 0) s.Obj[Fbx.L(o.Props[0])] = o;
        FbxNode cs = s.Root.Kid("Connections");
        if (cs != null) foreach (FbxNode c in cs.All("C")) s.Conns.Add(new Conn { T = Fbx.S(c.Props[0]), Child = Fbx.L(c.Props[1]), Parent = Fbx.L(c.Props[2]), Prop = c.Props.Count > 3 ? Fbx.S(c.Props[3]) : "" });
        return s;
    }
    public static string NameOf(FbxNode n) { string s = n.Props.Count > 1 ? Fbx.S(n.Props[1]) : ""; int z = s.IndexOf('\0'); if (z >= 0) return s.Substring(0, z); int c = s.IndexOf("::"); return c >= 0 ? s.Substring(c + 2) : s; }
    public static string ClassOf(FbxNode n) { return n.Props.Count > 2 ? Fbx.S(n.Props[2]) : ""; }
    public static long IdOf(FbxNode n) { return Fbx.L(n.Props[0]); }
    public List<long> Kids(long parent, string objName) { List<long> r = new List<long>(); foreach (Conn c in Conns) if (c.Parent == parent && Obj.ContainsKey(c.Child) && (objName == null || Obj[c.Child].Name == objName)) r.Add(c.Child); return r; }
    public List<long> Parents(long child, string objName) { List<long> r = new List<long>(); foreach (Conn c in Conns) if (c.Child == child && Obj.ContainsKey(c.Parent) && (objName == null || Obj[c.Parent].Name == objName)) r.Add(c.Parent); return r; }
    public static FbxNode P(FbxNode n, string prop) { FbxNode p70 = n.Kid("Properties70"); if (p70 == null) return null; foreach (FbxNode p in p70.All("P")) if (Fbx.S(p.Props[0]) == prop) return p; return null; }
    public static double[] Vec(FbxNode n, string prop, double dx, double dy, double dz) { FbxNode p = P(n, prop); if (p == null || p.Props.Count < 7) return new double[] { dx, dy, dz }; return new double[] { Fbx.D(p.Props[4]), Fbx.D(p.Props[5]), Fbx.D(p.Props[6]) }; }
    public static double Num(FbxNode n, string prop, double def) { FbxNode p = P(n, prop); if (p == null || p.Props.Count < 5) return def; return Fbx.D(p.Props[4]); }

    // ---- the mesh: the first Geometry "Mesh", its Model, its UV layer
    public long GeomId, MeshModelId;
    public double[] CP; public long[] PVI; public double[] UV; public long[] UVI; public string UVMap = "", UVRef = "";
    public void FindMesh() {
        foreach (KeyValuePair<long, FbxNode> kv in Obj) if (kv.Value.Name == "Geometry" && ClassOf(kv.Value) == "Mesh" && kv.Value.Kid("Vertices") != null) { GeomId = kv.Key; break; }
        if (GeomId == 0) throw new Exception("FBX: no mesh");
        FbxNode g = Obj[GeomId];
        CP = Fbx.Dbl(g.Kid("Vertices")); PVI = Fbx.Lng(g.Kid("PolygonVertexIndex"));
        FbxNode uvl = g.Kid("LayerElementUV");
        if (uvl != null) { UV = Fbx.Dbl(uvl.Kid("UV")); UVI = Fbx.Lng(uvl.Kid("UVIndex")); UVMap = Fbx.Str(uvl.Kid("MappingInformationType")); UVRef = Fbx.Str(uvl.Kid("ReferenceInformationType")); }
        List<long> ms = Parents(GeomId, "Model"); if (ms.Count == 0) throw new Exception("FBX: the mesh has no model"); MeshModelId = ms[0];
    }
    // ---- the split, exactly as fbx2tds.ps1 does it: SplitCP[i] = the control point of 3DS vertex i
    public List<int> SplitCP = new List<int>(); public List<float[]> SplitPos = new List<float[]>(); public List<double[]> SplitUV = new List<double[]>();
    public void Split() {
        Dictionary<string, int> map = new Dictionary<string, int>();
        List<int> pvi = new List<int>(); List<double> pu = new List<double>(), pv = new List<double>(); int corner = 0;
        for (int i = 0; i < PVI.Length; i++) {
            int vi = (int)PVI[i]; bool last = vi < 0; if (last) vi = ~vi;
            double u = 0, v = 0;
            if (UV != null && UV.Length > 0) {
                int ui;
                if (UVMap == "ByPolygonVertex") ui = (UVRef == "IndexToDirect" && UVI != null && UVI.Length > 0) ? (int)UVI[corner] : corner;
                else ui = (UVRef == "IndexToDirect" && UVI != null && UVI.Length > 0) ? (int)UVI[vi] : vi;
                u = UV[ui * 2]; v = UV[ui * 2 + 1];
            }
            pvi.Add(vi); pu.Add(u); pv.Add(v); corner++;
            if (last) {
                double pmu = 1e9, pmv = 1e9; for (int k = 0; k < pvi.Count; k++) { pmu = Math.Min(pmu, pu[k]); pmv = Math.Min(pmv, pv[k]); }
                double qmu = -1e9, qmv = -1e9; for (int k = 0; k < pvi.Count; k++) { qmu = Math.Max(qmu, pu[k]); qmv = Math.Max(qmv, pv[k]); }
                double du = Math.Floor((pmu + qmu) / 2), dv = Math.Floor((pmv + qmv) / 2);   // by the centre, not the lowest corner
                double pxu = -1e9, pxv = -1e9; for (int k = 0; k < pvi.Count; k++) { pxu = Math.Max(pxu, pu[k] - du); pxv = Math.Max(pxv, pv[k] - dv); }
                bool seamU = (pxu - (pmu - du)) > 0.5, seamV = (pxv - (pmv - dv)) > 0.5;
                for (int k = 0; k < pvi.Count; k++) {
                    double uu = pu[k] - du, vv = pv[k] - dv; if (seamU && uu < 0.5) uu += 1; if (seamV && vv < 0.5) vv += 1;
                    string key = pvi[k] + "|" + uu.ToString("R") + "|" + vv.ToString("R");
                    if (!map.ContainsKey(key)) { map[key] = SplitCP.Count; SplitCP.Add(pvi[k]); SplitPos.Add(new float[] { (float)CP[pvi[k] * 3], (float)CP[pvi[k] * 3 + 1], (float)CP[pvi[k] * 3 + 2] }); SplitUV.Add(new double[] { uu, vv }); }
                }
                pvi.Clear(); pu.Clear(); pv.Clear();
            }
        }
    }

    // ---- node transforms: L = T * Roff * Rp * Rpre * R * Rpost^-1 * Rp^-1 * Soff * Sp * S * Sp^-1
    public class Curve { public long[] Time; public double[] Val; public bool Step; }
    public Dictionary<long, Dictionary<string, Curve[]>> Anim = new Dictionary<long, Dictionary<string, Curve[]>>();
    public long Start, Stop; public double FrameTicks = 46186158000.0 / 30;
    public void FindAnim() {
        foreach (Conn c in Conns) {
            if (c.T != "OP" || !Obj.ContainsKey(c.Child) || Obj[c.Child].Name != "AnimationCurveNode") continue;
            if (!Obj.ContainsKey(c.Parent) || Obj[c.Parent].Name != "Model") continue;
            string prop = c.Prop; if (prop != "Lcl Translation" && prop != "Lcl Rotation" && prop != "Lcl Scaling") continue;
            FbxNode cn = Obj[c.Child]; Curve[] ch = new Curve[3];
            foreach (Conn c2 in Conns) {
                if (c2.T != "OP" || c2.Parent != c.Child || !Obj.ContainsKey(c2.Child)) continue;
                int axis = c2.Prop.EndsWith("X") ? 0 : c2.Prop.EndsWith("Y") ? 1 : c2.Prop.EndsWith("Z") ? 2 : -1; if (axis < 0) continue;
                FbxNode cv = Obj[c2.Child];
                Curve k = new Curve { Time = Fbx.Lng(cv.Kid("KeyTime")), Val = Fbx.Dbl(cv.Kid("KeyValueFloat")) };
                long[] fl = Fbx.Lng(cv.Kid("KeyAttrFlags")); k.Step = fl.Length > 0 && (fl[0] & 2) != 0;
                if (k.Time.Length > 0 && k.Val.Length == k.Time.Length) ch[axis] = k;
            }
            if (!Anim.ContainsKey(c.Parent)) Anim[c.Parent] = new Dictionary<string, Curve[]>();
            Anim[c.Parent][prop] = ch;
        }
        long mn = long.MaxValue, mx = long.MinValue;
        foreach (var a in Anim.Values) foreach (var ch in a.Values) foreach (Curve k in ch) if (k != null) { mn = Math.Min(mn, k.Time[0]); mx = Math.Max(mx, k.Time[k.Time.Length - 1]); }
        if (mn == long.MaxValue) { mn = 0; mx = 0; }
        Start = mn; Stop = mx;
        foreach (KeyValuePair<long, FbxNode> kv in Obj) if (kv.Value.Name == "AnimationStack") {
            FbxNode ls = P(kv.Value, "LocalStart"), le = P(kv.Value, "LocalStop");
            if (ls != null && le != null && Fbx.L(le.Props[4]) > Fbx.L(ls.Props[4])) { Start = Fbx.L(ls.Props[4]); Stop = Fbx.L(le.Props[4]); }
            break;
        }
        FbxNode gs = Root.Kid("GlobalSettings");
        if (gs != null) {
            int mode = (int)Num(gs, "TimeMode", 6);
            double[] fps = { 30, 120, 100, 60, 50, 48, 30, 30, 29.97, 29.97, 25, 24, 1000, 23.976, -1, 96, 72, 59.94, 119.88 };
            double r = mode >= 0 && mode < fps.Length ? fps[mode] : 30; if (r < 0) r = Num(gs, "CustomFrameRate", 30); if (r <= 0) r = 30;
            FrameTicks = 46186158000.0 / r;
        }
    }
    static double Eval(Curve k, long t, double def) {
        if (k == null) return def;
        if (t <= k.Time[0]) return k.Val[0];
        int n = k.Time.Length; if (t >= k.Time[n - 1]) return k.Val[n - 1];
        int i = 0; while (i < n - 2 && k.Time[i + 1] <= t) i++;
        if (k.Step) return k.Val[i];
        double f = (double)(t - k.Time[i]) / (k.Time[i + 1] - k.Time[i]); return k.Val[i] + (k.Val[i + 1] - k.Val[i]) * f;
    }
    double[] Chan(long id, FbxNode n, string prop, double d, long t) {
        double[] v = Vec(n, prop, d, d, d);
        Dictionary<string, Curve[]> a; Curve[] ch;
        if (Anim.TryGetValue(id, out a) && a.TryGetValue(prop, out ch)) for (int i = 0; i < 3; i++) v[i] = Eval(ch[i], t, v[i]);
        return v;
    }
    public double[] Local(long id, long t) {
        FbxNode n = Obj[id];
        double[] tr = Chan(id, n, "Lcl Translation", 0, t), rot = Chan(id, n, "Lcl Rotation", 0, t), sc = Chan(id, n, "Lcl Scaling", 1, t);
        double[] pre = Vec(n, "PreRotation", 0, 0, 0), post = Vec(n, "PostRotation", 0, 0, 0);
        double[] roff = Vec(n, "RotationOffset", 0, 0, 0), rp = Vec(n, "RotationPivot", 0, 0, 0), soff = Vec(n, "ScalingOffset", 0, 0, 0), sp = Vec(n, "ScalingPivot", 0, 0, 0);
        if ((int)Num(n, "RotationOrder", 0) != 0 && !Notes.Contains("order")) { Notes.Add("order"); Notes.Add("note: " + NameOf(n) + " has rotation order " + Num(n, "RotationOrder", 0) + " (read as XYZ)"); }
        double[] m = M34.T(tr[0], tr[1], tr[2]);
        m = M34.Mul(m, M34.T(roff[0], roff[1], roff[2])); m = M34.Mul(m, M34.T(rp[0], rp[1], rp[2]));
        m = M34.Mul(m, M34.Euler(pre[0], pre[1], pre[2])); m = M34.Mul(m, M34.Euler(rot[0], rot[1], rot[2]));
        m = M34.Mul(m, M34.Inv(M34.Euler(post[0], post[1], post[2]))); m = M34.Mul(m, M34.T(-rp[0], -rp[1], -rp[2]));
        m = M34.Mul(m, M34.T(soff[0], soff[1], soff[2])); m = M34.Mul(m, M34.T(sp[0], sp[1], sp[2]));
        m = M34.Mul(m, M34.S(sc[0], sc[1], sc[2])); m = M34.Mul(m, M34.T(-sp[0], -sp[1], -sp[2]));
        return m;
    }
    public double[] Global(long id, long t) {
        double[] m = Local(id, t);
        foreach (long p in Parents(id, "Model")) return M34.Mul(Global(p, t), m);
        return m;
    }
    // ---- the skin
    public class Cluster { public long Bone; public long[] Idx; public double[] W; public double[] Tr, TL; public string Name; }
    public List<Cluster> Clusters = new List<Cluster>();
    public void FindSkin() {
        foreach (long sk in Kids(GeomId, "Deformer")) {
            if (ClassOf(Obj[sk]) != "Skin") continue;
            foreach (long cl in Kids(sk, "Deformer")) {
                FbxNode c = Obj[cl]; if (ClassOf(c) != "Cluster") continue;
                List<long> bones = Kids(cl, "Model"); if (bones.Count == 0) continue;
                Clusters.Add(new Cluster { Bone = bones[0], Name = NameOf(Obj[bones[0]]), Idx = Fbx.Lng(c.Kid("Indexes")), W = Fbx.Dbl(c.Kid("Weights")), Tr = M34.FromFbx(Fbx.Dbl(c.Kid("Transform"))), TL = M34.FromFbx(Fbx.Dbl(c.Kid("TransformLink"))) });
            }
        }
    }
    // the control points deformed at time t, back in the mesh's own (bind) space.
    // Two conventions for a cluster's Transform: the FBX definition (the mesh's global at bind, so the
    // mesh in the bone's space is inv(TransformLink) * Transform), and 3ds Max's (Transform written as
    // that product already: inv(TransformLink) * the mesh's global). Each cluster is read the way its
    // matrices fit, the mesh's global taken from its node
    static double Diff(double[] a, double[] b) { double d = 0; for (int i = 0; i < 12; i++) d += Math.Abs(a[i] - b[i]); return d; }
    public string Convention = "";
    public double[][] Deform(long t) {
        int n = CP.Length / 3; double[][] acc = new double[n][]; double[] ws = new double[n];
        for (int i = 0; i < n; i++) acc[i] = new double[3];
        double[] meshG = Global(MeshModelId, Start), inv = M34.Inv(meshG);
        int nstd = 0, nmax = 0;
        foreach (Cluster c in Clusters) {
            double[] asMax = M34.Mul(M34.Inv(c.TL), meshG);
            double[] boneFromMesh;
            if (Diff(c.Tr, asMax) < Diff(c.Tr, meshG)) { boneFromMesh = c.Tr; nmax++; } else { boneFromMesh = M34.Mul(M34.Inv(c.TL), c.Tr); nstd++; }
            double[] m = M34.Mul(inv, M34.Mul(Global(c.Bone, t), boneFromMesh));
            for (int k = 0; k < c.Idx.Length; k++) {
                int i = (int)c.Idx[k]; double w = c.W[k]; if (i < 0 || i >= n || w == 0) continue;
                double[] p = M34.Apply(m, CP[i * 3], CP[i * 3 + 1], CP[i * 3 + 2]);
                acc[i][0] += w * p[0]; acc[i][1] += w * p[1]; acc[i][2] += w * p[2]; ws[i] += w;
            }
        }
        Convention = nmax > 0 && nstd == 0 ? "3ds Max" : nstd > 0 && nmax == 0 ? "FBX standard" : "mixed (" + nmax + " Max, " + nstd + " standard)";
        double[][] r = new double[n][];
        for (int i = 0; i < n; i++) {
            if (ws[i] <= 1e-9) r[i] = new double[] { CP[i * 3], CP[i * 3 + 1], CP[i * 3 + 2] };
            else r[i] = new double[] { acc[i][0] / ws[i], acc[i][1] / ws[i], acc[i][2] / ws[i] };
        }
        return r;
    }
}
