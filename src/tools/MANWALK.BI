'----- MANWALK.BI: what MANWALK.BAS, MWROOM.BAS and MWANIM.BAS share -- the types, the constants,
'----- every procedure's DECLARE, and (COMMON SHARED) the data both modules use. The
'----- arrays here are DIMensioned once, in MANWALK.BAS. (One module had grown past what
'----- BC 4.5 can compile: 'Out of memory'.)
'----- his walking speed: x16 units a retrace (1.44 units, about 2 m/s)
CONST WALK16 = 23.04
'----- a turning step on the spot per this many degrees turned (about one a second)
CONST TURNDEG = 360
'----- his turning speed, radians a retrace (6 degrees: 420 a second)
CONST TURNRATE = .1047
'----- the path grid's cell (units, about 22 cm)
CONST GCELL = 10
TYPE Vtx
	x AS SINGLE
	y AS SINGLE
	z AS SINGLE
	u AS SINGLE
	v AS SINGLE
END TYPE
TYPE Fac
	a AS INTEGER
	b AS INTEGER
	c AS INTEGER
	d AS INTEGER
	ci AS INTEGER
END TYPE
TYPE Nrm
	x AS SINGLE
	y AS SINGLE
	z AS SINGLE
END TYPE
TYPE Hdr
	magic AS STRING * 4
	nv AS INTEGER
	nf AS INTEGER
	flags AS INTEGER
END TYPE
DECLARE SUB LoadModel ()
DECLARE SUB LoadBackdrop ()
DECLARE SUB LoadPalette ()
DECLARE SUB LoadTexture ()
DECLARE SUB LoadOvl (fil AS STRING, s AS STRING)
DECLARE SUB LoSplit (v AS LONG, lo AS INTEGER, hi AS INTEGER)
DECLARE SUB Prep (yaw AS SINGLE)
DECLARE SUB Project (px AS LONG, py AS LONG, pz AS LONG)
DECLARE SUB PathPos (ts AS INTEGER, px AS LONG, py AS LONG, pz AS LONG, zm AS INTEGER)
DECLARE FUNCTION PitNow& ()
DECLARE SUB RoadEdge (side AS INTEGER)
DECLARE SUB DrawCar (px AS LONG, py AS LONG, pz AS LONG)
DECLARE SUB RectCopy (sg AS INTEGER, so AS LONG, dg AS INTEGER, dof AS LONG, rows AS INTEGER, nb AS INTEGER, sst AS INTEGER, dst AS INTEGER)
DECLARE SUB RectCopyM (sg AS INTEGER, so AS LONG, dg AS INTEGER, dof AS LONG, rows AS INTEGER, nb AS INTEGER, sst AS INTEGER, dst AS INTEGER, col AS INTEGER)
DECLARE FUNCTION NormSeg% (sg AS INTEGER, ofs AS INTEGER)
DECLARE FUNCTION TexWidth% ()
DECLARE SUB BandAlloc (b AS INTEGER, w AS INTEGER)
DECLARE SUB Fail (msg AS STRING)
DECLARE SUB SaveShot (fil AS STRING)
DECLARE SUB ShowFps (n AS INTEGER)
DECLARE SUB DrawAll ()
DECLARE SUB Ink (w1 AS INTEGER, stride AS INTEGER, rw AS INTEGER, rh AS INTEGER)
DECLARE SUB OutlineCol (c AS INTEGER)
DECLARE SUB ProjInst (i AS INTEGER)
DECLARE FUNCTION RoomK! (z AS LONG)
DECLARE FUNCTION RoomX! (z AS LONG)
DECLARE SUB PrepAsm (yaw AS SINGLE)
DECLARE SUB LoadAnim ()
DECLARE SUB SetPose (f AS INTEGER)
DECLARE SUB RotTo (i AS INTEGER)
DECLARE SUB PoseInst (i AS INTEGER, f AS INTEGER, yaw AS SINGLE)
DECLARE FUNCTION AnimFrame% (ph AS LONG)
DECLARE SUB LoadIdle ()
DECLARE SUB IdleSkin (g AS INTEGER)
DECLARE FUNCTION IdlePose% (i AS INTEGER, d AS SINGLE, hold AS INTEGER)
DECLARE FUNCTION TurnPose% (r AS INTEGER, dd AS SINGLE)
DECLARE SUB Mouse ()
DECLARE SUB FloorPick (qx AS INTEGER, qy AS INTEGER, clampit AS INTEGER, tx AS LONG, tz AS LONG)
DECLARE FUNCTION Atn2! (y AS SINGLE, x AS SINGLE)
DECLARE SUB CurCopy (x AS INTEGER, y AS INTEGER)
DECLARE SUB CurDraw (x AS INTEGER, y AS INTEGER)
DECLARE SUB CurBlit (x AS INTEGER, y AS INTEGER)
DECLARE SUB LoadWalk ()
DECLARE FUNCTION MaskAt% (x16 AS LONG, z16 AS LONG)
DECLARE FUNCTION CellOf% (x16 AS LONG, z16 AS LONG)
DECLARE FUNCTION LineClear% (ax AS LONG, az AS LONG, bx AS LONG, bz AS LONG)
DECLARE SUB FindPath (sx16 AS LONG, sz16 AS LONG, tx AS LONG, tz AS LONG)
DECLARE SUB LoadOcc ()
DECLARE SUB OccApply (o AS INTEGER, bx AS INTEGER, by AS INTEGER, ex AS INTEGER, ey AS INTEGER)
DECLARE SUB InkBox (i AS INTEGER, bx AS INTEGER, by AS INTEGER, ex AS INTEGER, ey AS INTEGER)
DECLARE SUB LoadPac ()
DECLARE FUNCTION PacHit% (x AS INTEGER, y AS INTEGER, v AS STRING)
DECLARE SUB SayObj (h AS INTEGER)
DECLARE SUB DigitAim (d AS INTEGER, px AS LONG, pz AS LONG, tx AS LONG, tz AS LONG)
DECLARE SUB DrawLabel (s1 AS STRING, s2 AS STRING)
DECLARE SUB Bench ()
DECLARE FUNCTION Ms! (t1 AS LONG, t2 AS LONG)
DECLARE SUB SetInst (i AS INTEGER)
DECLARE SUB PlaceCopy (px AS LONG, py AS LONG, pz AS LONG)
CONST MAXV = 1023
CONST MAXF = 1023
CONST WKW = 320
CONST WKH = 200
CONST MAXI = 8
'----- the drive: a straight, level world line (x16 units) from screen (77,154)
'----- at depth 420 (the sprite started at x 57; the turned car is wider, so
'----- 20 px further in keeps its tail on screen) to depth 740 under the
'----- sprite's last x (269); the car heads along it, so the camera sits
'----- behind and beside it (ATN(PDZ/PDX))
CONST PX0 = -2178
CONST PDX = 7219
CONST PY0 = -1418
CONST PDY = 0
CONST PZ0 = 6720
CONST PDZ = 5120
'----- the ground plane the car's wheels ride on (units, camera height above
'----- it: the car's centre PY0/16 less half its height) and the road's half
'----- width; the backdrop's road edges are drawn as lines on that plane
'----- parallel to the drive, so they meet at the car's own vanishing point
CONST GROUNDY = -124
CONST ROADW2 = 90
'----- the data the room module (MWROOM.BAS) and the main one share
COMMON SHARED roomOn AS INTEGER, rcx AS SINGLE, rcy AS SINGLE, rch AS SINGLE, rzn AS SINGLE, rzf AS SINGLE
COMMON SHARED rfx AS SINGLE, rxn AS SINGLE, rxf AS SINGLE, rbs AS SINGLE, rsc AS SINGLE, wmk() AS INTEGER
COMMON SHARED gwk() AS INTEGER, gpar() AS INTEGER, gq() AS INTEGER, wpx() AS LONG, wpz() AS LONG, pcx() AS LONG
COMMON SHARED pcz() AS LONG, ddx() AS INTEGER, ddz() AS INTEGER, bitv() AS INTEGER, wmOn AS INTEGER, gnx AS INTEGER
COMMON SHARED gnz AS INTEGER, gx0 AS INTEGER, gz0 AS INTEGER, nwp AS INTEGER, iwp AS INTEGER, pathms AS SINGLE
COMMON SHARED ocm() AS INTEGER, ocx0() AS INTEGER, ocy0() AS INTEGER, ocw() AS INTEGER, och() AS INTEGER, ooff() AS INTEGER
COMMON SHARED odep() AS LONG, oord() AS INTEGER, nocc AS INTEGER, ovlMcpy AS STRING, hpx() AS INTEGER, hpy() AS INTEGER
COMMON SHARED hpo() AS INTEGER, oky() AS STRING * 1, obs() AS INTEGER, omsg() AS STRING * 120, ospx() AS INTEGER, ospy() AS INTEGER
COMMON SHARED ospd() AS INTEGER, nhot AS INTEGER, hsaid AS INTEGER, hlast AS INTEGER, phx AS INTEGER, phy AS INTEGER
COMMON SHARED bgseg AS INTEGER, bgo AS INTEGER, wseg AS INTEGER, wko AS INTEGER, curs() AS STRING, mreg() AS INTEGER
COMMON SHARED ovlMse AS STRING
'----- the data the animation module (MWANIM.BAS) and the main one share
COMMON SHARED ovlSkin AS STRING, inc AS INTEGER, nv AS INTEGER, nf AS INTEGER, ibw() AS INTEGER, icst() AS INTEGER
COMMON SHARED icnt() AS INTEGER, ilp() AS INTEGER, icum() AS INTEGER, ilen() AS INTEGER, idm() AS INTEGER, iclp() AS INTEGER
COMMON SHARED itm() AS SINGLE, iwt() AS SINGLE, ilst() AS INTEGER, nfid AS INTEGER, tcf() AS INTEGER, tcl AS INTEGER
COMMON SHARED tfx() AS SINGLE, tfz() AS SINGLE, mx() AS INTEGER, my() AS INTEGER, mz() AS INTEGER, prs() AS INTEGER
COMMON SHARED kx() AS INTEGER, ky() AS INTEGER, kz() AS INTEGER, idlechk AS INTEGER, tph AS SINGLE, afr() AS INTEGER
COMMON SHARED anf AS INTEGER, acyc AS INTEGER, acum() AS INTEGER, prr() AS INTEGER, ovlRot AS STRING, rx() AS INTEGER
COMMON SHARED ry() AS INTEGER, rz() AS INTEGER, ord() AS INTEGER, rxs() AS INTEGER, rys() AS INTEGER, rzs() AS INTEGER
COMMON SHARED ords() AS INTEGER
