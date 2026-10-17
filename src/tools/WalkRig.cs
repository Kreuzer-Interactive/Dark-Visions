// WalkRig.cs - the 3D man's rig and keyed walk (see tools\man3danim.ps1): the rigid pieces of the
// converted model (CAR3D.MDL) to 13 bones, the joints from the pieces' rings, 12 keyed frames posed
// with forward kinematics. Used by man3danim.ps1 (MAN3D.ANI) and man3dfbx.ps1 (the walk as an FBX).
using System; using System.IO; using System.Collections.Generic; using System.Text;
public class WalkRig {
    public int NV, NP; public float[] X, Y, Z, U, V; public List<int[]> Polys = new List<int[]>();
    public float YMin, YMax, UPC;              // units per cm (the hair's top at 188 cm)
    public string Report = "";
    // bones: 0 root(pelvis) 1 chest 2 head 3 thighL 4 shinL 5 footL 6 thighR 7 shinR 8 footR 9 uarmL 10 farmL 11 uarmR 12 farmR
    public static readonly int[] Parent = { -1, 0, 1, 0, 3, 4, 0, 6, 7, 1, 9, 1, 11 };
    public double[][] Pivot = new double[13][];
    public int[] B1, B2; public float[] W1;   // each vertex: bone B1 with weight W1, the rest to B2
    public float[][] FX, FY, FZ; public int Cycle16; public int NF; public float[] DY; public int[] Cum16;
    public static readonly string[] BoneName = { "pelvis", "chest", "head", "thigh_L", "shin_L", "foot_L", "thigh_R", "shin_R", "foot_R", "upperarm_L", "forearm_L", "upperarm_R", "forearm_R" };

    public static WalkRig Load(string path) {
        WalkRig r = new WalkRig(); byte[] b = File.ReadAllBytes(path);
        if (b[0] != 'C' || b[1] != '3' || b[2] != 'D' || b[3] != '2') throw new Exception("not a C3D2 model");
        r.NV = BitConverter.ToInt16(b, 4); r.NP = BitConverter.ToInt16(b, 6);
        r.X = new float[r.NV]; r.Y = new float[r.NV]; r.Z = new float[r.NV]; r.U = new float[r.NV]; r.V = new float[r.NV];
        for (int i = 0; i < r.NV; i++) { int o = 10 + i * 20; r.X[i] = BitConverter.ToSingle(b, o); r.Y[i] = BitConverter.ToSingle(b, o + 4); r.Z[i] = BitConverter.ToSingle(b, o + 8); r.U[i] = BitConverter.ToSingle(b, o + 12); r.V[i] = BitConverter.ToSingle(b, o + 16); }
        int fo = 10 + r.NV * 20;
        for (int f = 0; f < r.NP; f++) { int o = fo + f * 10; int a = BitConverter.ToInt16(b, o), bb = BitConverter.ToInt16(b, o + 2), c = BitConverter.ToInt16(b, o + 4), d = BitConverter.ToInt16(b, o + 6); r.Polys.Add(d >= 0 ? new int[] { a, bb, c, d } : new int[] { a, bb, c }); }
        r.YMin = 1e9f; r.YMax = -1e9f; for (int i = 0; i < r.NV; i++) { r.YMin = Math.Min(r.YMin, r.Y[i]); r.YMax = Math.Max(r.YMax, r.Y[i]); }
        r.UPC = (r.YMax - r.YMin) / 188f;
        return r;
    }
    public double H(int i) { return (Y[i] - YMin) / UPC; }   // a vertex's height in cm
    double YofH(double cm) { return YMin + cm * UPC; }

    // ---- the pieces: connected components over welded positions
    public List<List<int>> Pieces() {
        int[] w = new int[NV]; var map = new Dictionary<string, int>();
        for (int i = 0; i < NV; i++) { string k = Math.Round(X[i], 3) + "|" + Math.Round(Y[i], 3) + "|" + Math.Round(Z[i], 3); int j; if (!map.TryGetValue(k, out j)) { j = i; map[k] = i; } w[i] = j; }
        int[] par = new int[NV]; for (int i = 0; i < NV; i++) par[i] = i;
        Func<int, int> find = null; find = q => { while (par[q] != q) { par[q] = par[par[q]]; q = par[q]; } return q; };
        foreach (int[] p in Polys) for (int k = 1; k < p.Length; k++) { int r1 = find(w[p[0]]), r2 = find(w[p[k]]); if (r1 != r2) par[r1] = r2; }
        for (int i = 0; i < NV; i++) { int r1 = find(i), r2 = find(w[i]); if (r1 != r2) par[r1] = r2; }
        var comp = new Dictionary<int, List<int>>();
        for (int i = 0; i < NV; i++) { int r = find(i); if (!comp.ContainsKey(r)) comp[r] = new List<int>(); comp[r].Add(i); }
        return new List<List<int>>(comp.Values);
    }
    double[] Centroid(List<int> vs, Func<int, bool> pick) { double x = 0, y = 0, z = 0; int n = 0; foreach (int i in vs) if (pick(i)) { x += X[i]; y += Y[i]; z += Z[i]; n++; } if (n == 0) return null; return new double[] { x / n, y / n, z / n }; }

    // ---- the rig: each piece to its bone, the joints from the pieces' rings
    public void Rig() {
        B1 = new int[NV]; B2 = new int[NV]; W1 = new float[NV];
        for (int i = 0; i < NV; i++) { B1[i] = 0; B2[i] = 0; W1[i] = 1; }
        StringBuilder sb = new StringBuilder();
        double zc = 0; for (int i = 0; i < NV; i++) zc += Z[i]; zc /= NV;
        Pivot[0] = new double[] { 0, YofH(96), zc };
        Pivot[1] = new double[] { 0, YofH(108), zc };
        Pivot[2] = new double[] { 0, YofH(157), zc };
        bool[] got = new bool[13];
        foreach (List<int> pc in Pieces()) {
            double lo = 1e9, hi = -1e9, xc = 0; foreach (int i in pc) { lo = Math.Min(lo, H(i)); hi = Math.Max(hi, H(i)); xc += X[i]; } xc /= pc.Count;
            bool side = Math.Abs(xc) > 1.5 * UPC; int s = xc < 0 ? 0 : 1;   // 0 = his left (x < 0), 1 = right
            string what; int bone;
            if (hi >= 180) { what = "head"; bone = 2; }
            else if (lo <= 3 && side) { what = "boot"; bone = 5 + 3 * s; }
            else if (lo <= 40 && hi >= 70 && side) { what = "leg"; bone = 3 + 3 * s; }
            else if (side && Math.Abs(xc) > 7 * UPC && lo >= 110) { what = "upper arm"; bone = 9 + 2 * s; }
            else if (side && Math.Abs(xc) > 7 * UPC && hi <= 130) { what = "forearm"; bone = 10 + 2 * s; }
            else if (lo >= 100) { what = "torso"; bone = 1; }
            else { what = "pelvis"; bone = 0; }
            sb.AppendLine("  piece " + pc.Count.ToString().PadLeft(3) + " verts, " + lo.ToString("0") + ".." + hi.ToString("0") + " cm, x " + (xc / UPC).ToString("0") + " cm -> " + what + (side ? (s == 0 ? " L" : " R") : ""));
            foreach (int i in pc) { B1[i] = bone; B2[i] = bone; W1[i] = 1; }
            got[bone] = true;
            if (what == "leg") {
                // the knee: the ring nearest the leg's middle; the hip 8 cm below the leg's top, over its top ring
                var rings = new SortedSet<int>(); foreach (int i in pc) rings.Add((int)Math.Round(H(i)));
                double mid = (lo + hi) / 2, kh = lo; foreach (int rh in rings) if (Math.Abs(rh - mid) < Math.Abs(kh - mid)) kh = rh;
                double[] kc = Centroid(pc, i => Math.Abs(H(i) - kh) < 1.5);
                double[] tc = Centroid(pc, i => H(i) > hi - 4);
                Pivot[3 + 3 * s] = new double[] { tc[0], YofH(hi - 8), tc[2] };
                Pivot[4 + 3 * s] = kc;
                foreach (int i in pc) { double h = H(i); if (Math.Abs(h - kh) < 1.5) { B1[i] = 3 + 3 * s; B2[i] = 4 + 3 * s; W1[i] = 0.5f; } else if (h < kh) { B1[i] = 4 + 3 * s; B2[i] = B1[i]; } }
                got[4 + 3 * s] = true;
                sb.AppendLine("     knee ring at " + kh + " cm");
            }
            if (what == "boot") { double[] tc = Centroid(pc, i => H(i) > hi - 3); Pivot[5 + 3 * s] = new double[] { tc[0], YofH(10), tc[2] }; }
            if (what == "upper arm") { double[] tc = Centroid(pc, i => H(i) > hi - 4); Pivot[9 + 2 * s] = new double[] { tc[0], YofH(hi - 5), tc[2] }; }
            if (what == "forearm") { double[] tc = Centroid(pc, i => H(i) > hi - 3); Pivot[10 + 2 * s] = new double[] { tc[0], YofH(hi - 1), tc[2] }; }
        }
        for (int bn = 0; bn < 13; bn++) if (!got[bn] || Pivot[bn] == null) throw new Exception("the rig found no piece for bone " + bn + " (the pieces are listed above)\n" + sb.ToString());
        Report = sb.ToString();
    }

    // ---- 3x4 transforms: rotate about x (pitch) then y (yaw) at a pivot
    static double[] Mul(double[] a, double[] b) {   // a * b, both 3x4 row-major (r0 r1 r2 with translation in [3],[7],[11])
        double[] m = new double[12];
        for (int r = 0; r < 3; r++) { for (int c = 0; c < 3; c++) m[r * 4 + c] = a[r * 4] * b[c] + a[r * 4 + 1] * b[4 + c] + a[r * 4 + 2] * b[8 + c]; m[r * 4 + 3] = a[r * 4] * b[3] + a[r * 4 + 1] * b[7] + a[r * 4 + 2] * b[11] + a[r * 4 + 3]; }
        return m;
    }
    static double[] Local(double[] p, double pitchDeg, double yawDeg) {
        double a = pitchDeg * Math.PI / 180, bb = yawDeg * Math.PI / 180, ca = Math.Cos(a), sa = Math.Sin(a), cb = Math.Cos(bb), sb = Math.Sin(bb);
        // R = Ry(b) * Rx(a); Rx: y' = y ca - z sa, z' = y sa + z ca ; Ry: x' = x cb + z sb, z' = -x sb + z cb
        double[] rx = { 1, 0, 0, 0, 0, ca, -sa, 0, 0, sa, ca, 0 };
        double[] ry = { cb, 0, sb, 0, 0, 1, 0, 0, -sb, 0, cb, 0 };
        double[] r = Mul(ry, rx);
        // about the pivot: T(p) * R * T(-p)
        double[] tp = { 1, 0, 0, p[0], 0, 1, 0, p[1], 0, 0, 1, p[2] }, tn = { 1, 0, 0, -p[0], 0, 1, 0, -p[1], 0, 0, 1, -p[2] };
        return Mul(tp, Mul(r, tn));
    }
    static double[] Apply(double[] m, double x, double y, double z) { return new double[] { m[0] * x + m[1] * y + m[2] * z + m[3], m[4] * x + m[5] * y + m[6] * z + m[7], m[8] * x + m[9] * y + m[10] * z + m[11] }; }

    // the keyed walk, left leg; frame 0 = left heel strike (12 keys, interpolated for other counts)
    static readonly double[] HIP  = { 22, 17, 11, 5, -1, -7, -13, -9, 2, 12, 19, 23 };     // thigh forward, deg
    static readonly double[] KNEE = { 3, 12, 10, 6, 5, 9, 25, 50, 58, 42, 20, 6 };         // knee flexion, deg
    static readonly double[] FOOT = { 12, 2, 0, 0, 0, 0, -10, -28, -12, -2, 6, 12 };       // the foot's pitch in the world, + = toe up
    static double Key(double[] k, double t) { t = t - Math.Floor(t); double p = t * 12; int i = (int)Math.Floor(p); double f = p - i; double a = k[i % 12], b = k[(i + 1) % 12]; return a + (b - a) * f; }

    // the bones' local rotations at cycle time t: [bone] = { pitch (about x), yaw (about y) }, degrees
    public double[][] Angles(double t) {
        double hipL = Key(HIP, t), kneeL = Key(KNEE, t), footL = Key(FOOT, t);
        double hipR = Key(HIP, t + 0.5), kneeR = Key(KNEE, t + 0.5), footR = Key(FOOT, t + 0.5);
        double rootYaw = -3.0 * (hipL - hipR) / 44.0;
        double armL = -0.6 * hipL + 2, armR = -0.6 * hipR + 2;
        return new double[][] {
            new double[] { 0, rootYaw }, new double[] { -2, -1.6 * rootYaw }, new double[] { 2, 0.6 * rootYaw },
            new double[] { hipL, 0 }, new double[] { -kneeL, 0 }, new double[] { footL - (hipL - kneeL), 0 },
            new double[] { hipR, 0 }, new double[] { -kneeR, 0 }, new double[] { footR - (hipR - kneeR), 0 },
            new double[] { armL, 0 }, new double[] { 8 + 0.5 * Math.Max(0, armL), 0 },
            new double[] { armR, 0 }, new double[] { 8 + 0.5 * Math.Max(0, armR), 0 } };
    }
    public double[][] Pose(double t) {
        double[][] A = Angles(t); double[][] W = new double[13][]; double[][] L = new double[13][];
        for (int bn = 0; bn < 13; bn++) L[bn] = Local(Pivot[bn], A[bn][0], A[bn][1]);
        for (int bn = 0; bn < 13; bn++) W[bn] = Parent[bn] < 0 ? L[bn] : Mul(W[Parent[bn]], L[bn]);
        return W;
    }
    public double[][] PoseOld(double t) {
        double[] m = new double[13]; double[][] W = new double[13][];
        double hipL = Key(HIP, t), kneeL = Key(KNEE, t), footL = Key(FOOT, t);
        double hipR = Key(HIP, t + 0.5), kneeR = Key(KNEE, t + 0.5), footR = Key(FOOT, t + 0.5);
        double rootYaw = -3.0 * (hipL - hipR) / 44.0;        // the pelvis turns with the forward leg
        double[][] L = new double[13][];
        L[0] = Local(Pivot[0], 0, rootYaw);
        L[1] = Local(Pivot[1], -2, -1.6 * rootYaw);          // the chest leans a little forward and turns against the pelvis
        L[2] = Local(Pivot[2], 2, 0.6 * rootYaw);            // the head keeps looking ahead
        L[3] = Local(Pivot[3], hipL, 0); L[4] = Local(Pivot[4], -kneeL, 0); L[5] = Local(Pivot[5], footL - (hipL - kneeL), 0);
        L[6] = Local(Pivot[6], hipR, 0); L[7] = Local(Pivot[7], -kneeR, 0); L[8] = Local(Pivot[8], footR - (hipR - kneeR), 0);
        double armL = -0.6 * hipL + 2, armR = -0.6 * hipR + 2;   // the arms swing against the legs
        L[9] = Local(Pivot[9], armL, 0); L[10] = Local(Pivot[10], 8 + 0.5 * Math.Max(0, armL), 0);
        L[11] = Local(Pivot[11], armR, 0); L[12] = Local(Pivot[12], 8 + 0.5 * Math.Max(0, armR), 0);
        for (int bn = 0; bn < 13; bn++) W[bn] = Parent[bn] < 0 ? L[bn] : Mul(W[Parent[bn]], L[bn]);
        return W;
    }
    public double[] Posed(double[][] W, int i) {
        double[] a = Apply(W[B1[i]], X[i], Y[i], Z[i]);
        if (W1[i] >= 1) return a;
        double[] b = Apply(W[B2[i]], X[i], Y[i], Z[i]);
        return new double[] { a[0] * W1[i] + b[0] * (1 - W1[i]), a[1] * W1[i] + b[1] * (1 - W1[i]), a[2] * W1[i] + b[2] * (1 - W1[i]) };
    }
    public void Bake(int nf) {
        NF = nf; FX = new float[nf][]; FY = new float[nf][]; FZ = new float[nf][]; DY = new float[nf];
        double[] ankleZ = new double[nf];
        for (int f = 0; f < nf; f++) {
            double[][] W = Pose((double)f / nf);
            FX[f] = new float[NV]; FY[f] = new float[NV]; FZ[f] = new float[NV];
            double lowest = 1e9;
            for (int i = 0; i < NV; i++) { double[] p = Posed(W, i); FX[f][i] = (float)p[0]; FY[f][i] = (float)p[1]; FZ[f][i] = (float)p[2]; lowest = Math.Min(lowest, p[1]); }
            float dy = (float)(YMin - lowest);              // the lowest boot stands on the ground
            for (int i = 0; i < NV; i++) FY[f][i] += dy;
            DY[f] = dy;
            ankleZ[f] = Apply(W[5], Pivot[5][0], Pivot[5][1], Pivot[5][2])[2];
        }
        Report += "  " + ComputeStride() + "\n";
    }
    // the stride, frame by frame: the vertices on the ground in a frame and the next (each frame's own
    // lowest + 0.6) move back with the ground; their median travel is how far he walks while that frame
    // shows. A frame where the feet change over (no such vertices, or none going back) gets the mean.
    // Cum16[f] = where frame f starts in the cycle, Cycle16 = the cycle (x16 units): played by distance
    // this way the planted foot stays put however unevenly the keys move it
    public string ComputeStride() {
        double[] d = new double[NF]; int valid = 0; double sum = 0;
        for (int f = 0; f < NF; f++) {
            int g = (f + 1) % NF; float lf = float.MaxValue, lg = float.MaxValue;
            for (int i = 0; i < NV; i++) { lf = Math.Min(lf, FY[f][i]); lg = Math.Min(lg, FY[g][i]); }
            List<double> dz = new List<double>();
            for (int i = 0; i < NV; i++) if (FY[f][i] < lf + 0.6 && FY[g][i] < lg + 0.6) dz.Add(FZ[g][i] - FZ[f][i]);
            d[f] = -1;
            if (dz.Count >= 3) { dz.Sort(); double m = dz[dz.Count / 2]; if (m > 0.05) { d[f] = m; valid++; sum += m; } }
        }
        double mean = valid > 0 ? sum / valid : 5;
        Cum16 = new int[NF]; double c = 0;
        for (int f = 0; f < NF; f++) { if (d[f] < 0) d[f] = mean; Cum16[f] = (int)Math.Round(c * 16); c += d[f]; }
        Cycle16 = (int)Math.Round(c * 16);
        StringBuilder s = new StringBuilder("stride: one cycle = " + c.ToString("0.0") + " units (" + (c / UPC).ToString("0") + " cm), " + NF + " frames, per frame");
        for (int f = 0; f < NF; f++) s.Append(' ').Append(d[f].ToString("0.0"));
        if (valid < NF) s.Append("  (" + (NF - valid) + " change-over frames at the mean)");
        return s.ToString();
    }
    public void SetUniform(double cycleUnits) { Cycle16 = (int)Math.Round(cycleUnits * 16); Cum16 = new int[NF]; for (int f = 0; f < NF; f++) Cum16[f] = (int)Math.Round(cycleUnits * 16 * f / NF); }
    // MAN3D.ANI "C3A2": nv%, nframes%, cycle% (x16 units), nframes x start% (x16), then the frames
    public void Save(string path) {
        using (BinaryWriter w = new BinaryWriter(File.Create(path))) {
            w.Write(Encoding.ASCII.GetBytes("C3A2")); w.Write((short)NV); w.Write((short)NF); w.Write((short)Cycle16);
            for (int f = 0; f < NF; f++) w.Write((short)Cum16[f]);
            for (int f = 0; f < NF; f++) {
                for (int i = 0; i < NV; i++) w.Write((short)Math.Round(FX[f][i] * 16));
                for (int i = 0; i < NV; i++) w.Write((short)Math.Round(FY[f][i] * 16));
                for (int i = 0; i < NV; i++) w.Write((short)Math.Round(FZ[f][i] * 16));
            }
        }
    }
}
