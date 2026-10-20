# build_car3d_asm.ps1 -- hand-assembled 386 real-mode routines for the 3D car
# (CAR3D.BAS): FPU-free textured triangles with a 1-bit colour key, and the vertex
# projection. Emitted as .OVL binaries in src\ (velocity_2_se-style: loaded into QB
# strings, invoked via DEF SEG = VARSEG(code$): CALL ABSOLUTE(..., SADD(code$))).
# Same convention as build_shadow_asm.ps1: params BYVAL WORD pushed left to right,
# after push bp / mov bp,sp the LAST param is at [bp+6]. 386 instructions (66h
# operand-size prefix, movsx, imul r,r/m, cdq, idiv r32, Jcc near) are fine on the
# 486SX and in DOSBox-X; what the SX lacks is only the FPU.
#
# C3DTRI.OVL  -- CALL ABSOLUTE(BYVAL pseg, BYVAL poff, SADD(tri$))     (RETF 4)
#   (64-texel textures; C3DT128.OVL is the same routine for 128 x 128 textures)
#   parameter block (24 INTEGERs at pseg:poff):
#    0 dseg  1 doff      work buffer (w*h bytes, row stride w)
#    2 w     3 h
#    4/23 band seg/off   INTEGER table: the segment of each lighting band's texture
#                        copy (width x width bytes at segment:0000, rows top-down)
#    5/6  sx seg/off    projected x per vertex (INTEGER array, 1/16 pixel)
#    7/8  sy seg/off
#    9/10 tu seg/off    texel u per vertex, 8.8 fixed (0..16383 = 0..63.99)
#   11/12 tv seg/off
#   13/14 fa seg/off    face records a,b,c,d,ci (5 INTEGERs; d = -1 for a triangle)
#   15/16 band seg/off  texture band per face (INTEGER 0..7)
#   17/18 ord seg/off   face indices in drawing order (far to near)
#   19 count            number of entries in ord
#   20 dx  21 dy        screen position of the work buffer in 1/16 pixel: buffer x = sx - dx
#   22 out: faces drawn   23 band table offset (see 4)
#   24 low byte: the flat threshold -- a face narrower and shorter than this (1/16 px) is filled
#                        flat with one texel (inside it: (2 v0 + v1 + v2) / 4 in UV): no gradients,
#                        no divides, rep stosb rows. 0 = never. (a 50 px man is nearly all such faces)
#      high byte: the dot threshold -- a face smaller than this both ways is one pixel, its
#                        centre, in that texel: no edges at all. 0 = never.
#   25 quad threshold    a quad's second triangle shorter than this reuses the first one's texture
#                        gradients (the same plane; the perspective difference is below a texel on
#                        a small quad). 0 = never. Bit 15 set = the vertices are ONE interleaved
#                        array x,y,u,v (8 bytes each) at 5/6 (7..12 unused): 3 segment loads a face
#                        instead of 18.
#   15 = 0               (band seg 0) every face is band 0: the texture segment is read once
#   26..63 out: the rasteriser's locals [bp-80..bp-5] after the call (debug: C3DTEST prints them)
#   A face is drawn when (x1-x0)*(y2-y0)-(x2-x0)*(y1-y0) > 0 (screen y down,
#   converter's outward winding). Texel index 255 = transparent.
#
# C3DPRJ.OVL  -- CALL ABSOLUTE(BYVAL qseg, BYVAL qoff, SADD(prj$))     (RETF 4)
#   block (21 INTEGERs): 0/1 rx seg/off  2/3 ry  4/5 rz  6/7 sx  8/9 sy  10 n
#   11/12 px lo/hi  13/14 py  15/16 pz (LONG, x16 units)  17..20 out: minx maxx miny maxy
#   21 output stride in bytes (0 = 2: separate sx/sy arrays; 8: the interleaved vertex array, 8/9 = base + 2)
#   22/23 the picture centre in 1/16 px (0 = 160, 100): a level camera with its centre shifted, as the
#   house rooms are drawn (the verticals stay vertical, the horizon above the back wall)
#   24 the horizontal focal length x16 (0 = 256 x16 = 4096, as vertically): 320x200 pixels are 1.2 times
#   taller than wide on a 4:3 screen, so a true-proportion view wants 307 across (4915); 25 is cleared
#   26 the model's scale x256 (0 = 256 = 1; 27 is cleared): rx, ry, rz times k/256 before the place is added
#   (the house rooms let him shrink less with depth than true perspective)
#   sx = (160 + (rx+px)*256 \ max(rz+pz,16)) * 16 ; sy = (100 - (ry+py)*256 \ ...) * 16  (1/16 pixel)
#
# C3DTEST.OVL -- encoding self-test, see C3DTEST.BAS.
$ErrorActionPreference = 'Stop'

# ---- tiny two-pass assembler: literal bytes, rel8 and rel16 jumps/calls -----
class Asm {
  [System.Collections.Generic.List[object]]$items = @()
  [hashtable]$labels = @{}
  [void]B([byte[]]$b) { foreach ($x in $b) { $this.items.Add([int]$x) } }
  [void]L([string]$name) { if ($this.labels.ContainsKey($name)) { throw "duplicate label $name" }; $this.labels[$name] = -1; $this.items.Add(@('label', $name)) }
  [void]J([byte]$opcode, [string]$target) { $this.items.Add(@('jmp', $opcode, $target)) }        # rel8
  [void]J16([byte[]]$opcode, [string]$target) { $this.items.Add(@('jmp16', $opcode, $target)) } # rel16 (E8 call, E9 jmp, 0F 8x Jcc)
  [byte[]]Resolve() {
    $addr = 0
    foreach ($it in $this.items) {
      if ($it -is [array]) {
        if ($it[0] -eq 'label') { $this.labels[$it[1]] = $addr }
        elseif ($it[0] -eq 'jmp') { $addr += 2 }
        else { $addr += ([byte[]]$it[1]).Length + 2 }
      } else { $addr++ }
    }
    $out = New-Object System.Collections.Generic.List[byte]
    $addr = 0
    foreach ($it in $this.items) {
      if ($it -is [array]) {
        if ($it[0] -eq 'label') { continue }
        if (-not $this.labels.ContainsKey($it[2]) -or $this.labels[$it[2]] -lt 0) { throw "unknown label $($it[2])" }
        if ($it[0] -eq 'jmp') {
          $rel = $this.labels[$it[2]] - ($addr + 2)
          if ($rel -lt -128 -or $rel -gt 127) { throw "rel8 out of range to $($it[2]) ($rel)" }
          $out.Add([byte]$it[1]); $out.Add([byte](($rel + 256) % 256)); $addr += 2
        } else {
          $op = [byte[]]$it[1]; $len = $op.Length + 2
          $rel = $this.labels[$it[2]] - ($addr + $len)
          foreach ($o in $op) { $out.Add($o) }
          $r = ($rel + 65536) % 65536
          $out.Add([byte]($r -band 255)); $out.Add([byte](($r -shr 8) -band 255)); $addr += $len
        }
      } else { $out.Add([byte]$it); $addr++ }
    }
    return $out.ToArray()
  }
}

# ---- emitter helpers (all memory operands are [bp+disp8]) --------------------
$script:a = $null
function E([byte[]]$b) { $script:a.B($b) }
function D8($v) { $v = [int]$v; if ($v -lt -128 -or $v -gt 127) { throw "disp8 out of range: $v" }; return [byte](($v + 256) % 256) }
function W16($v) { $v = [int]$v; if ($v -lt 0) { $v += 65536 }; return [byte[]]@([byte]($v -band 255), [byte](($v -shr 8) -band 255)) }
$R = @{ ax = 0; cx = 1; dx = 2; bx = 3; sp = 4; bp = 5; si = 6; di = 7 }
function MB($reg, $d8) { return [byte[]]@([byte](0x40 -bor ($reg -shl 3) -bor 6), (D8 $d8)) }   # modrm for [bp+disp8]
function MovRM($reg, $d8)   { E (@(0x8B) + (MB $R[$reg] $d8)) }        # mov r16,[bp+d]
function MovMR($d8, $reg)   { E (@(0x89) + (MB $R[$reg] $d8)) }        # mov [bp+d],r16
function AddRM($reg, $d8)   { E (@(0x03) + (MB $R[$reg] $d8)) }
function SubRM($reg, $d8)   { E (@(0x2B) + (MB $R[$reg] $d8)) }
function CmpRM($reg, $d8)   { E (@(0x3B) + (MB $R[$reg] $d8)) }
function MovDsM($d8)        { E (@(0x8E) + (MB 3 $d8)) }               # mov ds,[bp+d]
function MovEsM($d8)        { E (@(0x8E) + (MB 0 $d8)) }               # mov es,[bp+d]
function MovMI($d8, $imm)   { E (@(0xC7) + (MB 0 $d8) + (W16 $imm)) }  # mov word [bp+d],imm16
function IncM($d8)          { E (@(0xFF) + (MB 0 $d8)) }               # inc word [bp+d]
function CmpMI8($d8, $imm)  { E (@(0x83) + (MB 7 $d8) + @((D8 $imm))) } # cmp word [bp+d],imm8
function ImulM16($d8)       { E (@(0xF7) + (MB 5 $d8)) }               # imul r/m16 -> dx:ax
function ImulRM($reg, $d8)  { E (@(0x0F, 0xAF) + (MB $R[$reg] $d8)) }  # imul r16,[bp+d]
function Movsx32RM($reg, $d8) { E (@(0x66, 0x0F, 0xBF) + (MB $R[$reg] $d8)) } # movsx r32,word [bp+d]
function Mov32RM($reg, $d8) { E (@(0x66, 0x8B) + (MB $R[$reg] $d8)) }  # mov r32,[bp+d]
function Mov32MR($d8, $reg) { E (@(0x66, 0x89) + (MB $R[$reg] $d8)) }  # mov [bp+d],r32
function Add32RM($reg, $d8) { E (@(0x66, 0x03) + (MB $R[$reg] $d8)) }  # add r32,[bp+d]
function Add32MR($d8, $reg) { E (@(0x66, 0x01) + (MB $R[$reg] $d8)) }  # add [bp+d],r32
function Idiv32M($d8)       { E (@(0x66, 0xF7) + (MB 7 $d8)) }         # idiv dword [bp+d]
function LeaDI($d8)         { E (@(0x8D) + (MB 7 $d8)) }               # lea di,[bp+d]
function LeaSI($d8)         { E (@(0x8D) + (MB 6 $d8)) }               # lea si,[bp+d]
function Lbl($n) { $script:a.L($n) }
function Jr($op, $n) { $script:a.J($op, $n) }
function Jn([byte[]]$op, $n) { $script:a.J16($op, $n) }
function CallN($n) { $script:a.J16(@(0xE8), $n) }
function JmpN($n) { $script:a.J16(@(0xE9), $n) }
# eax = word[a]*word[b] - word[c]*word[d]   (sign-extended 32-bit)
function Cross32($pa, $pb, $pc, $pd) {
  Movsx32RM 'ax' $pa; Movsx32RM 'cx' $pb; E @(0x66, 0x0F, 0xAF, 0xC1)   # imul eax,ecx
  Movsx32RM 'cx' $pc; Movsx32RM 'dx' $pd; E @(0x66, 0x0F, 0xAF, 0xCA)   # imul ecx,edx
  E @(0x66, 0x2B, 0xC1)                                                 # sub eax,ecx
}

# =============================================================================
# C3DTRI
# =============================================================================
# locals: param block copy P(k) at [bp-128+2k]; rasteriser slots and temps above it
function P($k) { return -128 + 2 * $k }
$X0 = -80; $Y0 = -78; $U0 = -76; $V0 = -74
$X1 = -72; $Y1 = -70; $U1 = -68; $V1 = -66
$X2 = -64; $Y2 = -62; $U2 = -60; $V2 = -58
$DX1 = -56; $DY1 = -54; $DX2 = -52; $DY2 = -50
$DU1 = -48; $DU2 = -46; $DV1 = -44; $DV2 = -42
$DET = -40                      # dword
$DUDX = -36; $DVDX = -34; $DUDY = -32; $DVDY = -30
$XACCL = -28; $XSTEPL = -24; $XACCS = -20; $XSTEPS = -16   # dwords
$CY = -12; $YEND = -10; $LLEFT = -8; $ORDI = -6; $FOFF = -4; $TSEG = -2; $TMP = -40   # TMP reuses DET (dead once the gradients exist)

# ---- [bp+disp16] emitters for the locals below -128 ----------------------------
function MB16($reg, $d16) { return [byte[]]@([byte](0x80 -bor ($reg -shl 3) -bor 6)) + (W16 $d16) }   # modrm for [bp+disp16]
function MovRMw($reg, $d16)    { E (@(0x8B) + (MB16 $R[$reg] $d16)) }
function MovMRw($d16, $reg)    { E (@(0x89) + (MB16 $R[$reg] $d16)) }
function MovMIw($d16, $imm)    { E (@(0xC7) + (MB16 0 $d16) + (W16 $imm)) }
function CmpRMw($reg, $d16)    { E (@(0x3B) + (MB16 $R[$reg] $d16)) }
function CmpMI8w($d16, $imm)   { E (@(0x83) + (MB16 7 $d16) + @((D8 $imm))) }
function Mov32RMw($reg, $d16)  { E (@(0x66, 0x8B) + (MB16 $R[$reg] $d16)) }
function Mov32MRw($d16, $reg)  { E (@(0x66, 0x89) + (MB16 $R[$reg] $d16)) }
function Add32MRw($d16, $reg)  { E (@(0x66, 0x01) + (MB16 $R[$reg] $d16)) }
function Add32RMw($reg, $d16)  { E (@(0x66, 0x03) + (MB16 $R[$reg] $d16)) }
# the locals below the disp8 frame (2026-10-16): the two thresholds (block words 24, 25),
# the flat fill's flag and colour, the quad's gradient sharing, the row accumulators
$FLATT = -130; $QUADT = -132; $FLATF = -134; $FCOL = -136; $GRADOK = -138; $GRADDONE = -140
$TUY = -144; $TVY = -148; $DUDY16 = -152; $DVDY16 = -156         # dwords
$LAYOUT = -158; $UNLIT = -160                                      # bit 15 of word 25: interleaved vertices; band seg 0: one texture
$DOTT = -162; $W16 = -164; $H16 = -166                              # the dot threshold (high byte of word 24); the face box
$FRAME = 168

# one blob per texture size: $tsh = log2(texture width), 6 = 64 texels, 7 = 128
function Build-Tri([int]$tsh) {
$tmask = [byte]((1 -shl $tsh) - 1)
$script:a = [Asm]::new()
E @(0x55); E @(0x8B, 0xEC); E (@(0x81, 0xEC) + (W16 $FRAME))   # push bp; mov bp,sp; sub sp,FRAME
E @(0x1E, 0x56, 0x57, 0x06)                                    # push ds,si,di,es
MovDsM 8; MovRM 'si' 6                                         # ds:si = pseg:poff
E @(0x8C, 0xD0); E @(0x8E, 0xC0)                               # mov ax,ss; mov es,ax
LeaDI (P 0); E @(0xB9, 0x18, 0x00); E @(0xF3, 0xA5)            # lea di,[bp-128]; mov cx,24; rep movsw
E @(0xAD); E @(0x8B, 0xC8); E @(0x32, 0xED); E @(0x8A, 0xCC); MovMRw $DOTT 'cx'   # word 24: high byte = the dot threshold
E @(0x32, 0xE4); MovMRw $FLATT 'ax'; E @(0xAD)                              # low byte = the flat threshold; word 25
E @(0x8B, 0xC8); E @(0x81, 0xE1, 0x00, 0x80); MovMRw $LAYOUT 'cx'   # bit 15 of word 25 = the interleaved vertex layout
E @(0x25, 0xFF, 0x7F); MovMRw $QUADT 'ax'
MovMIw $UNLIT 0
CmpMI8 (P 15) 0; Jr 0x75 'lit'                                        # band seg 0: every face band 0 -> one texture segment, read once
MovDsM (P 4); MovRM 'si' (P 23); E @(0x8B, 0x04); MovMR $TSEG 'ax'; MovMIw $UNLIT 1
Lbl 'lit'
MovMI (P 22) 0                                                 # drawn = 0
MovMI $ORDI 0
Lbl 'outer'
MovRM 'ax' $ORDI; CmpRM 'ax' (P 19); Jn @(0x0F, 0x8D) 'done'  # jge done
MovDsM (P 17); MovRM 'si' (P 18); E @(0xD1, 0xE0); E @(0x03, 0xF0)   # ds:si = ord + i*2
E @(0x8B, 0x1C)                                                # mov bx,[si]  (face f)
CmpMI8w $UNLIT 0; Jr 0x75 'band1'                               # (unlit: TSEG is set once at entry)
MovDsM (P 15); MovRM 'si' (P 16); E @(0x8B, 0xC3); E @(0xD1, 0xE0); E @(0x03, 0xF0)   # band[f]
E @(0x8B, 0x04); E @(0xD1, 0xE0)                               # mov ax,[si]; shl ax,1
MovDsM (P 4); MovRM 'si' (P 23); E @(0x03, 0xF0); E @(0x8B, 0x04)   # band segment table [P4:P23]
MovMR $TSEG 'ax'                                               # tseg for this face
Lbl 'band1'
E @(0x8B, 0xC3); E @(0xD1, 0xE0); E @(0xD1, 0xE0); E @(0x03, 0xC3); E @(0xD1, 0xE0)   # ax = 10*f
AddRM 'ax' (P 14); MovMR $FOFF 'ax'
# load a,b,c into slots 0,1,2
foreach ($pair in @(@(0, $X0), @(2, $X1), @(4, $X2))) {
  MovDsM (P 13); MovRM 'si' $FOFF
  if ($pair[0] -eq 0) { E @(0x8B, 0x04) } else { E @(0x8B, 0x44, [byte]$pair[0]) }   # mov ax,[si+k]
  E (@(0xBF) + (W16 $pair[1])); CallN 'LDV'                                        # mov di,slot; call LDV
}
# cull
MovRM 'ax' $X1; SubRM 'ax' $X0; MovMR $DX1 'ax'
MovRM 'ax' $Y1; SubRM 'ax' $Y0; MovMR $DY1 'ax'
MovRM 'ax' $X2; SubRM 'ax' $X0; MovMR $DX2 'ax'
MovRM 'ax' $Y2; SubRM 'ax' $Y0; MovMR $DY2 'ax'
Cross32 $DX1 $DY2 $DX2 $DY1
E @(0x66, 0x0B, 0xC0); Jn @(0x0F, 0x8E) 'nextpoly'             # or eax,eax; jle nextpoly
MovMIw $GRADOK 0; MovMIw $GRADDONE 0
CallN 'TRI'
# quad: d >= 0 -> triangle (a,c,d); its texture gradients are the first triangle's when the
# quad is small (word 25: the second triangle's height in 1/16 px below which they are shared)
MovDsM (P 13); MovRM 'si' $FOFF; E @(0x8B, 0x44, 0x06); E @(0x0B, 0xC0); Jr 0x78 'nextpoly'   # js
foreach ($pair in @(@(0, $X0), @(4, $X1), @(6, $X2))) {
  MovDsM (P 13); MovRM 'si' $FOFF
  if ($pair[0] -eq 0) { E @(0x8B, 0x04) } else { E @(0x8B, 0x44, [byte]$pair[0]) }
  E (@(0xBF) + (W16 $pair[1])); CallN 'LDV'
}
MovRMw 'ax' $GRADDONE; MovMRw $GRADOK 'ax'
CallN 'TRI'
Lbl 'nextpoly'
IncM $ORDI; JmpN 'outer'
Lbl 'done'
# write back: word 22 = faces drawn; words 26..63 = the rasteriser locals [bp-80..bp-5] (debug)
MovEsM 8; MovRM 'di' 6
MovRM 'ax' (P 22); E @(0x26, 0x89, 0x45, 0x2C)                  # mov es:[di+44],ax
E @(0x83, 0xC7, 0x34); E @(0x8C, 0xD0); E @(0x8E, 0xD8); LeaSI -80; E @(0xB9, 0x26, 0x00); E @(0xF3, 0xA5)
E @(0x07, 0x5F, 0x5E, 0x1F); E @(0x8B, 0xE5); E @(0x5D); E @(0xCA, 0x04, 0x00)   # pops; mov sp,bp; pop bp; retf 4

# ---- LDV: ax = vertex index, di = slot offset (bp-relative) --------------------
Lbl 'LDV'
CmpMI8w $LAYOUT 0; Jn @(0x0F, 0x85) 'LDV8'                     # the interleaved layout: one segment, four words a vertex
E @(0xD1, 0xE0); E @(0x8B, 0xC8)                               # shl ax,1; mov cx,ax
MovDsM (P 5);  E @(0x8B, 0xF1); AddRM 'si' (P 6);  E @(0x8B, 0x04); SubRM 'ax' (P 20); E @(0x89, 0x03)         # x = sx-dx -> [bp+di]
MovDsM (P 7);  E @(0x8B, 0xF1); AddRM 'si' (P 8);  E @(0x8B, 0x04); SubRM 'ax' (P 21); E @(0x89, 0x43, 0x02)   # y = sy-dy
MovDsM (P 9);  E @(0x8B, 0xF1); AddRM 'si' (P 10); E @(0x8B, 0x04); E @(0x89, 0x43, 0x04)                      # u
MovDsM (P 11); E @(0x8B, 0xF1); AddRM 'si' (P 12); E @(0x8B, 0x04); E @(0x89, 0x43, 0x06)                      # v
E @(0xC3)
# ---- LDV8: the same from an interleaved array x,y,u,v (8 bytes a vertex) at P5:P6 ------
Lbl 'LDV8'
E @(0xC1, 0xE0, 0x03); MovDsM (P 5); E @(0x8B, 0xF0); AddRM 'si' (P 6)              # ds:si = base + i*8
E @(0xAD); SubRM 'ax' (P 20); E @(0x89, 0x03)                                       # x - dx
E @(0xAD); SubRM 'ax' (P 21); E @(0x89, 0x43, 0x02)                                 # y - dy
E @(0xAD); E @(0x89, 0x43, 0x04); E @(0xAD); E @(0x89, 0x43, 0x06)                  # u, v
E @(0xC3)

# ---- SWAP: 4 words at [bp+di] <-> [bp+si] -------------------------------------
Lbl 'SWAP'
E @(0x8B, 0x03); E @(0x87, 0x02); E @(0x89, 0x03)
foreach ($k in 2, 4, 6) { E @(0x8B, 0x43, [byte]$k); E @(0x87, 0x42, [byte]$k); E @(0x89, 0x43, [byte]$k) }
E @(0xC3)

# ---- TRI: rasterise the triangle in slots 0..2 ---------------------------------
Lbl 'TRI'
E (@(0xBF) + (W16 $X0))                                        # mov di,-80
# vertex coordinates are in 1/16 pixel; clamp to 0..(w-1)*16, 0..(h-1)*16
Lbl 'clampl'
E @(0x8B, 0x03); E @(0x0B, 0xC0); Jr 0x79 'c1'; E @(0x33, 0xC0); Lbl 'c1'          # x<0 -> 0
MovRM 'cx' (P 2); E @(0x49); E @(0xC1, 0xE1, 0x04); E @(0x3B, 0xC1); Jr 0x7E 'c2'; E @(0x8B, 0xC1); Lbl 'c2'
E @(0x89, 0x03)
E @(0x8B, 0x43, 0x02); E @(0x0B, 0xC0); Jr 0x79 'c3'; E @(0x33, 0xC0); Lbl 'c3'
MovRM 'cx' (P 3); E @(0x49); E @(0xC1, 0xE1, 0x04); E @(0x3B, 0xC1); Jr 0x7E 'c4'; E @(0x8B, 0xC1); Lbl 'c4'
E @(0x89, 0x43, 0x02)
E @(0x83, 0xC7, 0x08); E @(0x83, 0xFF, (D8 -56)); Jr 0x7C 'clampl'                 # add di,8; cmp di,-56; jl
# sort by y (3-element network)
foreach ($s in @(@($Y0, $Y1, $X0, $X1, 's1'), @($Y1, $Y2, $X1, $X2, 's2'), @($Y0, $Y1, $X0, $X1, 's3'))) {
  MovRM 'ax' $s[0]; CmpRM 'ax' $s[1]; Jr 0x7E $s[4]
  E (@(0xBF) + (W16 $s[2])); E (@(0xBE) + (W16 $s[3])); CallN 'SWAP'
  Lbl $s[4]
}
MovRM 'ax' $Y2; CmpRM 'ax' $Y0; Jr 0x75 't1'; E @(0xC3); Lbl 't1'                  # y2 == y0 -> ret
MovRM 'ax' $X1; SubRM 'ax' $X0; MovMR $DX1 'ax'
MovRM 'ax' $Y1; SubRM 'ax' $Y0; MovMR $DY1 'ax'
MovRM 'ax' $X2; SubRM 'ax' $X0; MovMR $DX2 'ax'
MovRM 'ax' $Y2; SubRM 'ax' $Y0; MovMR $DY2 'ax'
Cross32 $DX1 $DY2 $DX2 $DY1; Mov32MR $DET 'ax'
E @(0x66, 0x0B, 0xC0); Jr 0x75 't2'; E @(0xC3); Lbl 't2'                            # det == 0 -> ret
MovMI $LLEFT 1; Jr 0x7F 'lf'; MovMI $LLEFT 0; Lbl 'lf'                               # (flags still det's sign)
MovMIw $FLATF 0
# ---- the face's box: H16 = y2-y0 (sorted), W16 = max x - min x, in 1/16 px
MovRM 'ax' $Y2; SubRM 'ax' $Y0; MovMRw $H16 'ax'
MovRM 'ax' $X0; MovRM 'cx' $X0                                                       # ax = min x, cx = max x
CmpRM 'ax' $X1; Jr 0x7E 'f1'; MovRM 'ax' $X1; Lbl 'f1'
CmpRM 'ax' $X2; Jr 0x7E 'f2'; MovRM 'ax' $X2; Lbl 'f2'
CmpRM 'cx' $X1; Jr 0x7D 'f3'; MovRM 'cx' $X1; Lbl 'f3'
CmpRM 'cx' $X2; Jr 0x7D 'f4'; MovRM 'cx' $X2; Lbl 'f4'
E @(0x2B, 0xC8); MovMRw $W16 'cx'
# ---- the dot: a face smaller than the dot threshold both ways is one pixel, its centre,
# in the texel inside it at (2 v0 + v1 + v2) / 4 (a key texel drops it)
CmpMI8w $DOTT 0; Jn @(0x0F, 0x8E) 'notdot'
MovRMw 'ax' $H16; CmpRMw 'ax' $DOTT; Jn @(0x0F, 0x8D) 'notdot'
MovRMw 'ax' $W16; CmpRMw 'ax' $DOTT; Jn @(0x0F, 0x8D) 'notdot'
CallN 'MIDTEX'; Jr 0x75 'd1'; E @(0xC3); Lbl 'd1'                                     # al = the texel (zf: the key)
E @(0x8B, 0xD8)                                                                      # bx = colour
MovRM 'ax' $Y0; AddRM 'ax' $Y1; AddRM 'ax' $Y2; E @(0xB9, 0x55, 0x55); E @(0xF7, 0xE9)   # dx:ax = sum*21845 (/3 << 16)
E @(0x8B, 0xC2); E @(0xC1, 0xF8, 0x04); ImulM16 (P 2)                                   # ax = (sum/3 >> 4) * w
E @(0x8B, 0xC8)                                                                      # cx = row offset
MovRM 'ax' $X0; AddRM 'ax' $X1; AddRM 'ax' $X2; E @(0xBA, 0x55, 0x55); E @(0xF7, 0xEA)   # dx:ax = sum*21845
E @(0x8B, 0xC2); E @(0xC1, 0xF8, 0x04); E @(0x03, 0xC1); AddRM 'ax' (P 1); E @(0x8B, 0xF8)   # di = doff + row + x
MovEsM (P 0); E @(0x8B, 0xC3); E @(0x26, 0x88, 0x05)                                  # es:[di] = colour
IncM (P 22)
E @(0xC3)
Lbl 'notdot'
# ---- the flat fill: a face smaller than the flat threshold (1/16 px) in both directions
# is filled with that one texel (no gradients, no divides, a rep stosb per row)
CmpMI8w $FLATT 0; Jn @(0x0F, 0x8E) 'textured'                                        # threshold 0: never
MovRMw 'ax' $H16; CmpRMw 'ax' $FLATT; Jn @(0x0F, 0x8D) 'textured'
MovRMw 'ax' $W16; CmpRMw 'ax' $FLATT; Jn @(0x0F, 0x8D) 'textured'
CallN 'MIDTEX'; Jr 0x75 'f5'; E @(0xC3); Lbl 'f5'                                     # the texel; the key -> the face is not drawn
MovMRw $FCOL 'ax'; MovMIw $FLATF 1
JmpN 'edges'
Lbl 'textured'
# gradients per pixel (8.8): the numerators are in texel*(1/16 px) and det in (1/16 px)^2,
# so the quotient is 1/16 of the per-pixel value: scale the numerator by 16 first.
# A quad's second triangle keeps the first one's gradients when the quad is small (word 25)
CmpMI8w $GRADOK 0; Jr 0x74 'grads'
MovRM 'ax' $Y2; SubRM 'ax' $Y0; CmpRMw 'ax' $QUADT; Jn @(0x0F, 0x8C) 'gradsok'
Lbl 'grads'
MovRM 'ax' $U1; SubRM 'ax' $U0; MovMR $DU1 'ax'
MovRM 'ax' $U2; SubRM 'ax' $U0; MovMR $DU2 'ax'
MovRM 'ax' $V1; SubRM 'ax' $V0; MovMR $DV1 'ax'
MovRM 'ax' $V2; SubRM 'ax' $V0; MovMR $DV2 'ax'
Cross32 $DU1 $DY2 $DU2 $DY1; E @(0x66, 0xC1, 0xE0, 0x04); E @(0x66, 0x99); Idiv32M $DET; MovMR $DUDX 'ax'
Cross32 $DV1 $DY2 $DV2 $DY1; E @(0x66, 0xC1, 0xE0, 0x04); E @(0x66, 0x99); Idiv32M $DET; MovMR $DVDX 'ax'
Cross32 $DU2 $DX1 $DU1 $DX2; E @(0x66, 0xC1, 0xE0, 0x04); E @(0x66, 0x99); Idiv32M $DET; MovMR $DUDY 'ax'
Cross32 $DV2 $DX1 $DV1 $DX2; E @(0x66, 0xC1, 0xE0, 0x04); E @(0x66, 0x99); Idiv32M $DET; MovMR $DVDY 'ax'
MovMIw $GRADDONE 1
Lbl 'gradsok'
# the row accumulators: dudy*(cy0*16+8-y0) at the first row, + dudy*16 a row (v alike)
Movsx32RM 'ax' $DUDY; E @(0x66, 0xC1, 0xE0, 0x04); Mov32MRw $DUDY16 'ax'
Movsx32RM 'ax' $DVDY; E @(0x66, 0xC1, 0xE0, 0x04); Mov32MRw $DVDY16 'ax'
Lbl 'edges'
# rows: a row cy is covered when its centre (cy*16+8) lies in [y0, y2); first row = (y0+7)>>4
MovRM 'ax' $Y0; E @(0x05, 0x07, 0x00); E @(0xC1, 0xF8, 0x04); MovMR $CY 'ax'       # cy0
MovRM 'ax' $Y1; E @(0x05, 0x07, 0x00); E @(0xC1, 0xF8, 0x04); MovMR $YEND 'ax'     # cy1
CmpMI8w $FLATF 0; Jr 0x75 'tuyskip'                                              # (a flat face has no texture rows)
MovRM 'cx' $CY; E @(0xC1, 0xE1, 0x04); E @(0x83, 0xC1, 0x08); SubRM 'cx' $Y0; E @(0x66, 0x0F, 0xBF, 0xC9)   # ecx = cy0*16+8-y0
Movsx32RM 'ax' $DUDY; E @(0x66, 0x0F, 0xAF, 0xC1); Mov32MRw $TUY 'ax'
Movsx32RM 'ax' $DVDY; E @(0x66, 0x0F, 0xAF, 0xC1); Mov32MRw $TVY 'ax'
Lbl 'tuyskip'
# long edge DDA: slope (16.16 px per row) = (dx2<<16)/dy2; start x = x0 + slope*(centre of row cy0 - y0)/16
Movsx32RM 'ax' $DX2; E @(0x66, 0xC1, 0xE0, 0x10); E @(0x66, 0x99); Movsx32RM 'cx' $DY2; E @(0x66, 0xF7, 0xF9); Mov32MR $XSTEPL 'ax'
MovRM 'cx' $CY; E @(0xC1, 0xE1, 0x04); E @(0x83, 0xC1, 0x08); SubRM 'cx' $Y0; E @(0x66, 0x0F, 0xBF, 0xC9)   # ecx = sub-row offset 0..15
Mov32RM 'ax' $XSTEPL; E @(0x66, 0x0F, 0xAF, 0xC1); E @(0x66, 0xC1, 0xF8, 0x04)                            # eax = slope*offset/16
Movsx32RM 'cx' $X0; E @(0x66, 0xC1, 0xE1, 0x0C); E @(0x66, 0x03, 0xC1)                                     # + x0 as 16.16 px
E @(0x66, 0x05, 0x00, 0x80, 0x00, 0x00); Mov32MR $XACCL 'ax'                                               # + half a pixel (rounding)
# half 1: rows cy0..cy1-1 along the short edge 0-1
MovRM 'ax' $YEND; CmpRM 'ax' $CY; Jr 0x7E 'half2'
Movsx32RM 'ax' $DX1; E @(0x66, 0xC1, 0xE0, 0x10); E @(0x66, 0x99); Movsx32RM 'cx' $DY1; E @(0x66, 0xF7, 0xF9); Mov32MR $XSTEPS 'ax'
MovRM 'cx' $CY; E @(0xC1, 0xE1, 0x04); E @(0x83, 0xC1, 0x08); SubRM 'cx' $Y0; E @(0x66, 0x0F, 0xBF, 0xC9)
Mov32RM 'ax' $XSTEPS; E @(0x66, 0x0F, 0xAF, 0xC1); E @(0x66, 0xC1, 0xF8, 0x04)
Movsx32RM 'cx' $X0; E @(0x66, 0xC1, 0xE1, 0x0C); E @(0x66, 0x03, 0xC1)
E @(0x66, 0x05, 0x00, 0x80, 0x00, 0x00); Mov32MR $XACCS 'ax'
CallN 'SPANS'
Lbl 'half2'
# half 2: rows cy1..cy2-1 along the short edge 1-2 (the long edge carries on)
MovRM 'ax' $Y1; E @(0x05, 0x07, 0x00); E @(0xC1, 0xF8, 0x04); MovMR $CY 'ax'
MovRM 'ax' $Y2; E @(0x05, 0x07, 0x00); E @(0xC1, 0xF8, 0x04); MovMR $YEND 'ax'
CmpRM 'ax' $CY; Jr 0x7E 'tridone'
MovRM 'ax' $X2; SubRM 'ax' $X1; E @(0x66, 0x0F, 0xBF, 0xC0); E @(0x66, 0xC1, 0xE0, 0x10); E @(0x66, 0x99)
MovRM 'cx' $Y2; SubRM 'cx' $Y1; E @(0x66, 0x0F, 0xBF, 0xC9); E @(0x66, 0xF7, 0xF9); Mov32MR $XSTEPS 'ax'
MovRM 'cx' $CY; E @(0xC1, 0xE1, 0x04); E @(0x83, 0xC1, 0x08); SubRM 'cx' $Y1; E @(0x66, 0x0F, 0xBF, 0xC9)   # offset 1..16 from y1
Mov32RM 'ax' $XSTEPS; E @(0x66, 0x0F, 0xAF, 0xC1); E @(0x66, 0xC1, 0xF8, 0x04)
Movsx32RM 'cx' $X1; E @(0x66, 0xC1, 0xE1, 0x0C); E @(0x66, 0x03, 0xC1)
E @(0x66, 0x05, 0x00, 0x80, 0x00, 0x00); Mov32MR $XACCS 'ax'
CallN 'SPANS'
Lbl 'tridone'
IncM (P 22)
E @(0xC3)

# ---- MIDTEX: al = the texel at (2 slot 0 + slot 1 + slot 2) / 4 (ah = 0), zf = it is the key -- a point
# inside the triangle (halfway along its median from vertex 0), not on an edge: an edge lies on its UV
# island's border, where the texel next door belongs to another part of the texture (the colour spill on
# the seams of small, flat-filled faces)
Lbl 'MIDTEX'
Movsx32RM 'ax' $U0; E @(0x66, 0x03, 0xC0); Movsx32RM 'cx' $U1; E @(0x66, 0x03, 0xC1); Movsx32RM 'cx' $U2; E @(0x66, 0x03, 0xC1)
E @(0x66, 0xC1, 0xF8, 0x0A)                                                                  # eax = (2 u0 + u1 + u2)/4 >> 8
E @(0x25, $tmask, 0x00); E @(0x8B, 0xD8)                                                     # bx = u & mask
Movsx32RM 'ax' $V0; E @(0x66, 0x03, 0xC0); Movsx32RM 'cx' $V1; E @(0x66, 0x03, 0xC1); Movsx32RM 'cx' $V2; E @(0x66, 0x03, 0xC1)
E @(0x66, 0xC1, 0xF8, 0x0A)
E @(0x25, $tmask, 0x00); E @(0xC1, 0xE0, [byte]$tsh); E @(0x03, 0xC3); E @(0x8B, 0xF0)      # si = v*width + u
MovDsM $TSEG; E @(0x8A, 0x04); E @(0x32, 0xE4); E @(0x3C, 0xFF)                            # al = texel; cmp al,255
E @(0xC3)

# ---- SPANS: scanlines CY..YEND-1 --------------------------------------------------
Lbl 'SPANS'
MovRM 'ax' $CY; CmpRM 'ax' $YEND; Jr 0x7C 'sp0'; E @(0xC3); Lbl 'sp0'
Lbl 'sploop'
MovRM 'ax' ($XACCL + 2); MovRM 'cx' ($XACCS + 2)                 # integer parts
CmpMI8 $LLEFT 0; Jr 0x75 'l1'; E @(0x91); Lbl 'l1'               # long on right -> swap
E @(0x2B, 0xC8); Jn @(0x0F, 0x8E) 'spnext'                        # cx = xr-xl; jle spnext
MovMR $TMP 'ax'; E @(0x8B, 0xF1)                                  # xl; si = count
MovRM 'ax' $CY; ImulM16 (P 2); AddRM 'ax' (P 1); AddRM 'ax' $TMP; E @(0x8B, 0xF8)   # di = doff + y*w + xl
MovEsM (P 0)
CmpMI8w $FLATF 0; Jr 0x74 'spantex'
MovRMw 'ax' $FCOL; E @(0x8B, 0xCE); E @(0xF3, 0xAA); JmpN 'spnext'   # the flat row: mov cx,count; rep stosb
Lbl 'spantex'
# texel start at the first pixel's centre: u = u0 + (dudx*(xl*16+8-x0) + TUY)/16, TUY = dudy*(cy*16+8-y0)
MovRM 'ax' $TMP; E @(0xC1, 0xE0, 0x04); E @(0x05, 0x08, 0x00); SubRM 'ax' $X0; E @(0x66, 0x0F, 0xBF, 0xC8)   # ecx = dx16
Movsx32RM 'ax' $DUDX; E @(0x66, 0x0F, 0xAF, 0xC1); Add32RMw 'ax' $TUY                              # dudx*dx16 + TUY
E @(0x66, 0xC1, 0xF8, 0x04); AddRM 'ax' $U0; E @(0x8B, 0xD8)                                       # bx = u
Movsx32RM 'ax' $DVDX; E @(0x66, 0x0F, 0xAF, 0xC1); Add32RMw 'ax' $TVY
E @(0x66, 0xC1, 0xF8, 0x04); AddRM 'ax' $V0; E @(0x8B, 0xD0)                                       # dx = v
E @(0x8B, 0xCE)                                                   # cx = count
MovDsM $TSEG
Lbl 'pix'
E @(0x8A, 0xC6); E @(0x25, $tmask, 0x00); E @(0xC1, 0xE0, [byte]$tsh); E @(0x8B, 0xF0)   # si = (v & mask) * width
E @(0x8A, 0xC7); E @(0x25, $tmask, 0x00); E @(0x03, 0xF0)                                 # + (u & mask), ah cleared
E @(0x8A, 0x04); E @(0x3C, 0xFF); Jr 0x74 'skip'                                   # texel; key?
E @(0xAA); Jr 0xEB 'nxt'
Lbl 'skip'; E @(0x47)
Lbl 'nxt'
AddRM 'bx' $DUDX; AddRM 'dx' $DVDX; Jr 0xE2 'pix'
Lbl 'spnext'
Mov32RM 'ax' $XSTEPL; Add32MR $XACCL 'ax'
Mov32RM 'ax' $XSTEPS; Add32MR $XACCS 'ax'
Mov32RMw 'ax' $DUDY16; Add32MRw $TUY 'ax'
Mov32RMw 'ax' $DVDY16; Add32MRw $TVY 'ax'
IncM $CY; MovRM 'ax' $CY; CmpRM 'ax' $YEND; Jn @(0x0F, 0x8C) 'sploop'
E @(0xC3)
return $script:a.Resolve()
}
$tri = Build-Tri 6
$tri128 = Build-Tri 7

# =============================================================================
# C3DPRJ
# =============================================================================
function Q($k) { return -64 + 2 * $k }
$script:a = [Asm]::new()
E @(0x55); E @(0x8B, 0xEC); E @(0x81, 0xEC, 0x40, 0x00); E @(0x1E, 0x56, 0x57, 0x06)
MovDsM 8; MovRM 'si' 6; E @(0x8C, 0xD0); E @(0x8E, 0xC0); LeaDI (Q 0); E @(0xB9, 0x1C, 0x00); E @(0xF3, 0xA5)
CmpMI8 (Q 26) 0; Jr 0x75 'ks1'; MovMI (Q 26) 256; Lbl 'ks1'        # the model's scale x256 (word 26, 27 = 0): 0 -> 1
MovMI (Q 27) 0
CmpMI8 (Q 24) 0; Jr 0x75 'fx1'; MovMI (Q 24) 4096; Lbl 'fx1'       # the horizontal focal length x16 (word 24, 25 = 0): 0 -> 256
MovMI (Q 25) 0
CmpMI8 (Q 21) 0; Jr 0x75 'st1'; MovMI (Q 21) 2; Lbl 'st1'          # the output stride (word 21): 0 -> 2
CmpMI8 (Q 22) 0; Jr 0x75 'cx1'; MovMI (Q 22) 2560; Lbl 'cx1'       # the picture centre (words 22/23, 1/16 px): 0 -> 160, 100
CmpMI8 (Q 23) 0; Jr 0x75 'cy1'; MovMI (Q 23) 1600; Lbl 'cy1'
MovMI (Q 17) 32767; MovMI (Q 18) -32768; MovMI (Q 19) 32767; MovMI (Q 20) -32768
MovMI -4 0
Lbl 'ploop'
MovRM 'ax' -4; CmpRM 'ax' (Q 10); Jn @(0x0F, 0x8D) 'pdone'
E @(0xD1, 0xE0); MovMR -6 'ax'                                   # [bp-6] = i*2
MovRM 'ax' -4; ImulRM 'ax' (Q 21); MovMR -8 'ax'                  # [bp-8] = i*stride (the outputs)
MovDsM (Q 4); MovRM 'si' -6; AddRM 'si' (Q 5); E @(0x66, 0x0F, 0xBF, 0x04); E (@(0x66, 0x0F, 0xAF) + (MB $R['ax'] (Q 26))); E @(0x66, 0xC1, 0xF8, 0x08); Add32RM 'ax' (Q 15)   # eax = rz*k/256 + pz
E @(0x66, 0x83, 0xF8, 0x10); Jr 0x7D 'z1'; E @(0x66, 0xB8, 0x10, 0x00, 0x00, 0x00); Lbl 'z1'      # min 16
E @(0x66, 0x8B, 0xC8)                                            # ecx = zz
MovDsM (Q 0); MovRM 'si' -6; AddRM 'si' (Q 1); E @(0x66, 0x0F, 0xBF, 0x04); E (@(0x66, 0x0F, 0xAF) + (MB $R['ax'] (Q 26))); E @(0x66, 0xC1, 0xF8, 0x08); Add32RM 'ax' (Q 11)
E (@(0x66, 0x0F, 0xAF) + (MB $R['ax'] (Q 24))); E @(0x66, 0x99); E @(0x66, 0xF7, 0xF9); AddRM 'ax' (Q 22)   # ax = (cx + fx*x/z) * 16 (imul eax, dword [Q24])
MovDsM (Q 6); MovRM 'si' -8; AddRM 'si' (Q 7); E @(0x89, 0x04)
CmpRM 'ax' (Q 17); Jr 0x7D 'm1'; MovMR (Q 17) 'ax'; Lbl 'm1'
CmpRM 'ax' (Q 18); Jr 0x7E 'm2'; MovMR (Q 18) 'ax'; Lbl 'm2'
MovDsM (Q 2); MovRM 'si' -6; AddRM 'si' (Q 3); E @(0x66, 0x0F, 0xBF, 0x04); E (@(0x66, 0x0F, 0xAF) + (MB $R['ax'] (Q 26))); E @(0x66, 0xC1, 0xF8, 0x08); Add32RM 'ax' (Q 13)
E @(0x66, 0xC1, 0xE0, 0x0C); E @(0x66, 0x99); E @(0x66, 0xF7, 0xF9)
E @(0x8B, 0xC8); MovRM 'ax' (Q 23); E @(0x2B, 0xC1)              # ax = (cy - 256y/z) * 16
MovDsM (Q 8); MovRM 'si' -8; AddRM 'si' (Q 9); E @(0x89, 0x04)
CmpRM 'ax' (Q 19); Jr 0x7D 'm3'; MovMR (Q 19) 'ax'; Lbl 'm3'
CmpRM 'ax' (Q 20); Jr 0x7E 'm4'; MovMR (Q 20) 'ax'; Lbl 'm4'
IncM -4; JmpN 'ploop'
Lbl 'pdone'
MovEsM 8; MovRM 'di' 6; E @(0x83, 0xC7, 0x22); E @(0x8C, 0xD0); E @(0x8E, 0xD8); LeaSI (Q 17); E @(0xB9, 0x04, 0x00); E @(0xF3, 0xA5)
E @(0x07, 0x5F, 0x5E, 0x1F); E @(0x8B, 0xE5); E @(0x5D); E @(0xCA, 0x04, 0x00)
$prj = $script:a.Resolve()

# =============================================================================
# C3DEDGE: CALL ABSOLUTE(BYVAL seg, BYVAL off, BYVAL stride, BYVAL w, BYVAL h, SADD(edge$)) RETF 10
#   silhouette ink, pass 1: inside the w x h block at seg:off (row stride given), a car
#   pixel (index >= 16) whose left or upper neighbour is background (< 16) is marked 254,
#   and vice versa (the car-side pixel of the pair is marked). Marks are >= 16 so they
#   never cascade. Starts at (1,1): the caller's box has a free margin round the car.
#   [bp+6]=h [bp+8]=w [bp+10]=stride [bp+12]=off [bp+14]=seg
# =============================================================================
$script:a = [Asm]::new()
E @(0x55); E @(0x8B, 0xEC); E @(0x1E, 0x56, 0x57, 0x53)                 # push bp; mov bp,sp; push ds,si,di,bx
MovDsM 14; MovRM 'si' 12
MovRM 'bx' 10; E @(0xF7, 0xDB)                                            # bx = -stride
AddRM 'si' 10; E @(0x46)                                                  # si -> row 1, col 1
MovRM 'di' 6; E @(0x4F)                                                   # di = h-1 rows
Lbl 'erow'
MovRM 'cx' 8; E @(0x49); Jr 0xE3 'eadv'                                   # cx = w-1; jcxz
Lbl 'epix'
E @(0x8B, 0x44, 0xFF); E @(0xA9, 0xF0, 0xF0); Jr 0x75 'ework'             # ax = [si-1]: al left, ah current
E @(0xF6, 0x00, 0xF0); Jr 0x74 'enext'                                    # up also background -> nothing
Lbl 'ework'
E @(0x8A, 0xD4); E @(0xF6, 0xC2, 0xF0); E @(0x0F, 0x95, 0xC2)             # dl = current is car
E @(0xA8, 0xF0); E @(0x0F, 0x95, 0xC6)                                    # dh = left is car
E @(0x3A, 0xD6); Jr 0x74 'enoL'
E @(0x84, 0xD2); Jr 0x74 'emarkL'
E @(0xC6, 0x04, 0xFE); Jr 0xEB 'enoL'                                     # mark current
Lbl 'emarkL'; E @(0xC6, 0x44, 0xFF, 0xFE)                                 # mark left
Lbl 'enoL'
E @(0x8A, 0x20); E @(0xF6, 0xC4, 0xF0); E @(0x0F, 0x95, 0xC6)             # dh = up is car
E @(0x3A, 0xD6); Jr 0x74 'enext'
E @(0x84, 0xD2); Jr 0x74 'emarkU'
E @(0xC6, 0x04, 0xFE); Jr 0xEB 'enext'
Lbl 'emarkU'; E @(0xC6, 0x00, 0xFE)                                       # mark up
Lbl 'enext'
E @(0x46); Jr 0xE2 'epix'
Lbl 'eadv'
AddRM 'si' 10; SubRM 'si' 8; E @(0x46)                                    # next row, col 1
E @(0x4F); Jr 0x75 'erow'
E @(0x5B, 0x5F, 0x5E, 0x1F); E @(0x5D); E @(0xCA, 0x0A, 0x00)
$edge = $script:a.Resolve()

# =============================================================================
# C3DEDGO: CALL ABSOLUTE(BYVAL seg, BYVAL off, BYVAL stride, BYVAL w, BYVAL h, BYVAL thr + mark*256, SADD(edgo$)) RETF 12
#   outer outline: inside the w x h block, a background pixel (index < thr) with a solid
#   left, right, upper or lower neighbour (index >= thr) becomes mark. The ring sits
#   outside the model, its own edge pixels kept. mark < thr, so marks never count as
#   solid in the same pass (no cascade); a second pass with thr = the first mark and a
#   lower mark adds a second ring (thr 16 mark 15, then thr 15 mark 14 = 2 px). Skips
#   the block's border rows and columns: the caller's box has that margin.
#   [bp+6]=thr|mark [bp+8]=h [bp+10]=w [bp+12]=stride [bp+14]=off [bp+16]=seg
# =============================================================================
$script:a = [Asm]::new()
E @(0x55); E @(0x8B, 0xEC); E @(0x1E, 0x56, 0x57, 0x53)                 # push bp; mov bp,sp; push ds,si,di,bx
MovDsM 16; MovRM 'si' 14
MovRM 'bx' 12                                                             # bx = stride
E @(0x03, 0xF3); E @(0x46)                                                # si -> row 1, col 1
MovRM 'dx' 6                                                              # dl = thr, dh = mark
MovRM 'di' 8; E @(0x83, 0xEF, 0x02); Jr 0x7E 'odone'                     # di = h-2 rows
Lbl 'orow'
MovRM 'cx' 10; E @(0x83, 0xE9, 0x02); Jr 0x7E 'oadv'                     # cx = w-2
Lbl 'opix'
E @(0x8A, 0x04); E @(0x3A, 0xC2); Jr 0x73 'onext'                        # solid (or marked) itself -> nothing
E @(0x38, 0x54, 0xFF); Jr 0x73 'omark'                                    # left
E @(0x38, 0x54, 0x01); Jr 0x73 'omark'                                    # right
E @(0x2B, 0xF3); E @(0x38, 0x14); E @(0x8D, 0x30); Jr 0x73 'omark'        # up (sub si,bx; cmp; lea si,[si+bx] keeps the flags)
E @(0x38, 0x10); Jr 0x72 'onext'                                          # down
Lbl 'omark'; E @(0x88, 0x34)                                              # [si] = mark
Lbl 'onext'
E @(0x46); Jr 0xE2 'opix'
Lbl 'oadv'
E @(0x03, 0xF3); SubRM 'si' 10; E @(0x83, 0xC6, 0x02)                     # next row, col 1
E @(0x4F); Jr 0x75 'orow'
Lbl 'odone'
E @(0x5B, 0x5F, 0x5E, 0x1F); E @(0x5D); E @(0xCA, 0x0C, 0x00)
$edgo = $script:a.Resolve()

# =============================================================================
# C3DEDGK: CALL ABSOLUTE(BYVAL seg, BYVAL off, BYVAL stride, BYVAL w, BYVAL h, BYVAL thr + mark*256, BYVAL tseg, SADD(edgk$)) RETF 14
#   C3DEDGO's ring, but only where it is needed to see him: a BLACK background pixel (index < thr,
#   dark in the table) next to a BLACK pixel of his (left/right/up/down, index >= thr, dark) becomes
#   mark -- a black coat on a black floor gets its edge, his coloured parts and anything over a
#   coloured background none. The table: 256 flag bytes at tseg:0000 (bit 0 = a dark colour) and
#   one word after it at tseg:0100 the routine uses itself (w - 2). Skips the block's border.
#   [bp+6]=tseg [bp+8]=thr|mark [bp+10]=h [bp+12]=w [bp+14]=stride [bp+16]=off [bp+18]=seg
#   registers: ds:si the pixel, es the table, bp the stride (after the parameters are read), bl
#   a pixel (bh 0: es:[bx] its flags), dl thr dh mark, di rows, cx columns
# =============================================================================
#   C3DEDGI (-Inside): the same with his side and the floor's swapped -- his own BLACK edge pixel next to a
#   BLACK background pixel becomes mark (an inside line: his silhouette keeps its size). Same call.
function Build-Edgk([bool]$inside) {
$pj = if ($inside) { 0x82 } else { 0x83 }; $nj = if ($inside) { 0x73 } else { 0x72 }   # the pixel's side test, a neighbour's
$script:a = [Asm]::new()
E @(0x55); E @(0x8B, 0xEC); E @(0x1E, 0x56, 0x57, 0x53, 0x06)           # push bp; mov bp,sp; push ds,si,di,bx,es
MovEsM 6; MovDsM 18; MovRM 'si' 16
MovRM 'dx' 8                                                              # dl = thr, dh = mark
MovRM 'di' 10; E @(0x83, 0xEF, 0x02); Jn @(0x0F, 0x8E) 'kdone'           # di = h-2 rows
MovRM 'ax' 12; E @(0x83, 0xE8, 0x02); Jn @(0x0F, 0x8E) 'kdone'           # ax = w-2
E @(0x26, 0xA3, 0x00, 0x01)                                               # mov es:[0100],ax
MovRM 'ax' 14; E @(0x8B, 0xE8)                                            # bp = stride
E @(0x03, 0xF5); E @(0x46)                                                # si -> row 1, col 1
E @(0x32, 0xFF)                                                           # xor bh,bh
Lbl 'krow'
E @(0x26, 0x8B, 0x0E, 0x00, 0x01)                                         # cx = w-2
Lbl 'kpix'
E @(0x8A, 0x1C); E @(0x38, 0xD3); Jn @(0x0F, $pj) 'knext'               # his (or marked) -> nothing
E @(0x26, 0xF6, 0x07, 0x01); Jn @(0x0F, 0x84) 'knext'                    # a coloured background -> nothing
E @(0x8A, 0x5C, 0xFF); E @(0x38, 0xD3); Jr $nj 'kl'; E @(0x26, 0xF6, 0x07, 0x01); Jn @(0x0F, 0x85) 'kmark'; Lbl 'kl'   # left
E @(0x8A, 0x5C, 0x01); E @(0x38, 0xD3); Jr $nj 'kr'; E @(0x26, 0xF6, 0x07, 0x01); Jn @(0x0F, 0x85) 'kmark'; Lbl 'kr'   # right
E @(0x2B, 0xF5); E @(0x8A, 0x1C); E @(0x03, 0xF5)                         # up: sub si,bp; mov bl,[si]; add si,bp
E @(0x38, 0xD3); Jr $nj 'ku'; E @(0x26, 0xF6, 0x07, 0x01); Jn @(0x0F, 0x85) 'kmark'; Lbl 'ku'
E @(0x3E, 0x8A, 0x1A)                                                     # down: mov bl,ds:[bp+si]
E @(0x38, 0xD3); Jr $nj 'knext'; E @(0x26, 0xF6, 0x07, 0x01); Jr 0x74 'knext'
Lbl 'kmark'; E @(0x88, 0x34)                                              # [si] = mark
Lbl 'knext'
E @(0x46); E @(0x49); Jn @(0x0F, 0x85) 'kpix'                             # inc si; dec cx; jnz
E @(0x03, 0xF5); E @(0x26, 0x2B, 0x36, 0x00, 0x01)                        # next row, col 1: si += stride - (w-2)
E @(0x4F); Jn @(0x0F, 0x85) 'krow'
Lbl 'kdone'
E @(0x07, 0x5B, 0x5F, 0x5E, 0x1F); E @(0x5D); E @(0xCA, 0x0E, 0x00)
return $script:a.Resolve()
}
$edgk = Build-Edgk $false
$edgi = Build-Edgk $true
# =============================================================================
# C3DCOMP: CALL ABSOLUTE(BYVAL seg, BYVAL off, SADD(comp$)) RETF 4 -- a block of 9 words:
#   0 op  1/2 dest seg/off  3/4 src seg/off  5/6 mask seg/off  7 dest byte column  8 dest row
#   The dest and src are QB SCREEN 1 GET arrays (word 0 width in bits, word 1 rows, then rows of
#   bytes), the src at 4-pixel boundaries in the dest (so whole bytes; widths in whole bytes):
#   op 0 PASTE    src's rows into dest at (col, row)
#   op 1 EXTRACT  dest's bytes at (col, row) into src (its header already sized)
#   op 2 COMPOSE  dest = (dest AND mask) OR src  (mask: the src's same-sized mask array)
#   op 3 CLEAR    word 8 = a count of bytes zeroed at dest seg:off (no header)
#   op 4 COPY     word 8 = a count of bytes copied from src seg:off to dest seg:off (raw)
#   op 5 MERGE    dest's pixels in the rectangle columns 5..6, rows 7..8 (pixels and rows from its
#                 top left, inside it) taken from src, a GET array of the same size (words 5..8 are
#                 c0 c1 r0 r1, no mask): an animation's new frame into his save-under, pixel-exact
#   op 6 OVERLAY  a sprite pair at any pixel offset composed into dest, clipped: dest = (dest AND
#                 mask) OR src pixel by pixel as PUT AND then PUT OR would leave it; word 7 = the
#                 src's left less dest's in pixels, word 8 its top less dest's in rows (either may
#                 be negative); mask seg 0 = no mask (PUT PSET). The furniture in front of him
#                 composed into the frame before its one PUT, not put over it afterwards#   Composing a frame in RAM, then one PUT PSET of it, puts the new picture up with no
#   erased or half-drawn state ever on the screen (GAME8's flicker-free show).
# =============================================================================
$script:a = [Asm]::new()
E @(0x55); E @(0x8B, 0xEC); E @(0x1E, 0x56, 0x57, 0x53, 0x06); E @(0x0F, 0xA0); E @(0xFC)   # push bp ds si di bx es fs; cld
E @(0x8E, 0x5E, 0x08); E @(0x8B, 0x76, 0x06)                              # ds:si = the block
E @(0x8E, 0x44, 0x02); E @(0x8B, 0x7C, 0x04)                              # es:di = dest
E @(0x8B, 0x04); E @(0x83, 0xF8, 0x05); Jn @(0x0F, 0x83) 'cop56'          # ops 5, 6
E @(0x83, 0xF8, 0x04); Jn @(0x0F, 0x85) 'cnotcpy'                         # op 4: copy
E @(0x8B, 0x4C, 0x10); E @(0x8B, 0x44, 0x06); E @(0x8B, 0x74, 0x08); E @(0x8E, 0xD8); E @(0xF3, 0xA4); JmpN 'cdone'   # cx = count; ds:si = src; rep movsb
Lbl 'cnotcpy'
E @(0x83, 0xF8, 0x03); Jn @(0x0F, 0x85) 'cnotclr'                         # op 3: clear
E @(0x8B, 0x4C, 0x10); E @(0x32, 0xC0); E @(0xF3, 0xAA); JmpN 'cdone'     # cx = count; al = 0; rep stosb
Lbl 'cnotclr'
E @(0x8B, 0x44, 0x0A); E @(0x8E, 0xE0); E @(0x8B, 0x5C, 0x0C)            # fs:bx = mask
E @(0x26, 0x8B, 0x05); E @(0x83, 0xC0, 0x07); E @(0xC1, 0xE8, 0x03); E @(0x8B, 0xD0)   # dx = dest bytes a row
E @(0x8B, 0x44, 0x10); E @(0x0F, 0xAF, 0xC2); E @(0x03, 0xF8); E @(0x03, 0x7C, 0x0E); E @(0x83, 0xC7, 0x04)   # di += row*dx + col + 4
E @(0x83, 0xC3, 0x04)                                                     # bx past the mask's header
E @(0x8B, 0x04); E @(0x50)                                                # push op
E @(0x8B, 0x44, 0x06); E @(0x8B, 0x74, 0x08); E @(0x8E, 0xD8)            # ds:si = src
E @(0x8B, 0x04); E @(0x83, 0xC0, 0x07); E @(0xC1, 0xE8, 0x03); E @(0x8B, 0xE8)   # bp = src bytes a row
E @(0x8B, 0x44, 0x02); E @(0x83, 0xC6, 0x04)                              # ax = rows; si past the header
E @(0x2B, 0xD5); E @(0x59); E @(0x8A, 0xE0)                               # dx = dest skip; cx = op; ah = rows
E @(0x0A, 0xE4); Jn @(0x0F, 0x84) 'cdone'                                 # no rows
E @(0x83, 0xF9, 0x01); Jn @(0x0F, 0x84) 'cext'; Jn @(0x0F, 0x87) 'ccomp'
Lbl 'cpaste'
E @(0x8B, 0xCD); E @(0xF3, 0xA4); E @(0x03, 0xFA); E @(0xFE, 0xCC); Jn @(0x0F, 0x85) 'cpaste'
JmpN 'cdone'
Lbl 'cext'
E @(0x1E, 0x06, 0x1F, 0x07); E @(0x87, 0xF7)                              # swap: ds:si = dest place, es:di = src array
Lbl 'cextr'
E @(0x8B, 0xCD); E @(0xF3, 0xA4); E @(0x03, 0xF2); E @(0xFE, 0xCC); Jn @(0x0F, 0x85) 'cextr'
JmpN 'cdone'
Lbl 'ccomp'
E @(0x8B, 0xCD)
Lbl 'ccpx'
E @(0x26, 0x8A, 0x05); E @(0x64, 0x22, 0x07); E @(0x0A, 0x04); E @(0xAA); E @(0x46); E @(0x43)   # al = (dest AND mask) OR src
E @(0x49); Jn @(0x0F, 0x85) 'ccpx'
E @(0x03, 0xFA); E @(0xFE, 0xCC); Jn @(0x0F, 0x85) 'ccomp'
JmpN 'cdone'
# ---- ops 5, 6: 40 bytes of locals below the pushes (sp = bp-12): the block copied to bp-52..-36
#      (word k at bp-52+2k), then nb -34 (dest bytes a row), drows -32, snb -30, pad -28,
#      srows -26, bo -24, sh -22, r -20, j -18, soff -16, doff -14; op 5: lm -28, rm -26 (bytes),
#      b0 -24, b1 -22, r -20
Lbl 'cop56'
E @(0x83, 0xEC, 0x28)                                                     # sub sp,40
E @(0x16, 0x07); E @(0x8D, 0x7E, 0xCC); E @(0xB9, 0x09, 0x00); E @(0xF3, 0xA5)   # es = ss; the block -> [bp-52]
E @(0x8B, 0x46, 0xCC); E @(0x83, 0xF8, 0x06); Jn @(0x0F, 0x84) 'cop6'
# op 5 MERGE: es:di = dest, ds:si = src
E @(0x8E, 0x46, 0xCE); E @(0x8B, 0x7E, 0xD0); E @(0x8E, 0x5E, 0xD2); E @(0x8B, 0x76, 0xD4)
E @(0x26, 0x8B, 0x05); E @(0x83, 0xC0, 0x07); E @(0xC1, 0xE8, 0x03); E @(0x89, 0x46, 0xDE)   # nb
E @(0x8B, 0x4E, 0xD6); E @(0x83, 0xE1, 0x03); E @(0xD1, 0xE1); E @(0xB0, 0xFF); E @(0xD2, 0xE8); E @(0x88, 0x46, 0xE4)   # lm = FF >> 2(c0 & 3)
E @(0x8B, 0x4E, 0xD8); E @(0x83, 0xE1, 0x03); E @(0xF7, 0xD9); E @(0x83, 0xC1, 0x03); E @(0xD1, 0xE1); E @(0xB0, 0xFF); E @(0xD2, 0xE0); E @(0x88, 0x46, 0xE6)   # rm = FF << 2(3 - c1 & 3)
E @(0x8B, 0x46, 0xD6); E @(0xC1, 0xF8, 0x02); E @(0x89, 0x46, 0xE8)       # b0 = c0 >> 2
E @(0x8B, 0x46, 0xD8); E @(0xC1, 0xF8, 0x02); E @(0x89, 0x46, 0xEA)       # b1 = c1 >> 2
E @(0x8B, 0x46, 0xDA); E @(0x89, 0x46, 0xEC)                              # r = r0
Lbl 'c5row'
E @(0x8B, 0x46, 0xEC); E @(0x3B, 0x46, 0xDC); Jn @(0x0F, 0x8F) 'c56end'  # r > r1: done
E @(0x0F, 0xAF, 0x46, 0xDE); E @(0x03, 0x46, 0xE8); E @(0x83, 0xC0, 0x04); E @(0x8B, 0xD8)   # bx = 4 + r*nb + b0
E @(0x8B, 0x4E, 0xEA); E @(0x2B, 0x4E, 0xE8); E @(0x41)                   # cx = b1 - b0 + 1
E @(0x8A, 0x56, 0xE4)                                                     # dl = lm
Lbl 'c5byte'
E @(0x83, 0xF9, 0x01); Jr 0x75 'c5nr'; E @(0x22, 0x56, 0xE6); Lbl 'c5nr'   # the last byte: and rm
E @(0x8A, 0x00); E @(0x22, 0xC2); E @(0x8A, 0xE2); E @(0xF6, 0xD4); E @(0x26, 0x22, 0x21); E @(0x0A, 0xC4); E @(0x26, 0x88, 0x01)   # d = (d AND NOT m) OR (s AND m)
E @(0x43); E @(0xB2, 0xFF); E @(0x49); Jr 0x75 'c5byte'
E @(0xFF, 0x46, 0xEC); JmpN 'c5row'
# op 6 OVERLAY: es:di = dest; per src byte: ds:si -> art (bl), mask (bh, inverted: the cover)
Lbl 'cop6'
E @(0x8E, 0x46, 0xCE); E @(0x8B, 0x7E, 0xD0)
E @(0x26, 0x8B, 0x05); E @(0x83, 0xC0, 0x07); E @(0xC1, 0xE8, 0x03); E @(0x89, 0x46, 0xDE)   # nb
E @(0x26, 0x8B, 0x45, 0x02); E @(0x89, 0x46, 0xE0)                        # drows
E @(0x8E, 0x5E, 0xD2); E @(0x8B, 0x76, 0xD4)
E @(0x8B, 0x04); E @(0x8B, 0xD0); E @(0x83, 0xC0, 0x07); E @(0xC1, 0xE8, 0x03); E @(0x89, 0x46, 0xE2)   # snb (dx = src bits)
E @(0x8B, 0xC8); E @(0x49); E @(0xC1, 0xE1, 0x03); E @(0xF7, 0xD9); E @(0x03, 0xCA)        # cx = the last byte's bits
E @(0xB0, 0xFF); E @(0xD2, 0xE8); E @(0x88, 0x46, 0xE4)                   # pad = FF >> them (its unused low bits)
E @(0x8B, 0x44, 0x02); E @(0x89, 0x46, 0xE6)                              # srows
E @(0x8B, 0x46, 0xDA); E @(0x8B, 0xC8); E @(0xC1, 0xF8, 0x02); E @(0x89, 0x46, 0xE8)   # bo = dx >> 2 (floor)
E @(0x83, 0xE1, 0x03); E @(0xD1, 0xE1); E @(0x89, 0x4E, 0xEA)             # sh = 2(dx & 3)
E @(0xC7, 0x46, 0xEC, 0x00, 0x00)                                         # r = 0
Lbl 'c6row'
E @(0x8B, 0x46, 0xEC); E @(0x3B, 0x46, 0xE6); Jn @(0x0F, 0x8D) 'c56end'
E @(0x03, 0x46, 0xDC); Jn @(0x0F, 0x88) 'c6nrow'; E @(0x3B, 0x46, 0xE0); Jn @(0x0F, 0x8D) 'c6nrow'   # dest row dy + r inside?
E @(0x0F, 0xAF, 0x46, 0xDE); E @(0x83, 0xC0, 0x04); E @(0x89, 0x46, 0xF2)   # doff = 4 + row*nb
E @(0x8B, 0x46, 0xEC); E @(0x0F, 0xAF, 0x46, 0xE2); E @(0x83, 0xC0, 0x04); E @(0x89, 0x46, 0xF0)   # soff = 4 + r*snb
E @(0xC7, 0x46, 0xEE, 0x00, 0x00)                                         # j = 0
Lbl 'c6byte'
E @(0x8B, 0x46, 0xEE); E @(0x3B, 0x46, 0xE2); Jn @(0x0F, 0x8D) 'c6nrow'
E @(0x8E, 0x5E, 0xD2); E @(0x8B, 0x76, 0xD4); E @(0x03, 0x76, 0xF0); E @(0x03, 0xF0); E @(0x8A, 0x1C)   # bl = art
E @(0xB7, 0xFF)                                                           # bh = cover (no mask: all)
E @(0x83, 0x7E, 0xD6, 0x00); Jr 0x74 'c6op'
E @(0x8E, 0x5E, 0xD6); E @(0x8B, 0x76, 0xD8); E @(0x03, 0x76, 0xF0); E @(0x03, 0xF0); E @(0x8A, 0x3C); E @(0xF6, 0xD7)   # bh = NOT mask
Lbl 'c6op'
E @(0x8B, 0x4E, 0xE2); E @(0x49); E @(0x3B, 0xC1); Jr 0x75 'c6np'        # the row's last byte:
E @(0x8A, 0x4E, 0xE4); E @(0xF6, 0xD1); E @(0x22, 0xD9); E @(0x22, 0xF9)   #   its padding neither covers nor draws
Lbl 'c6np'
E @(0x8B, 0x4E, 0xEA)                                                     # cl = sh
E @(0x33, 0xD2); E @(0x8A, 0xF7); E @(0xD3, 0xEA)                         # dx = cover << 8 >> sh
E @(0x8A, 0xFB); E @(0x32, 0xDB); E @(0xD3, 0xEB)                         # bx = art << 8 >> sh
E @(0x03, 0x46, 0xE8)                                                     # ax = dest byte column bo + j
E @(0x8E, 0x46, 0xCE); E @(0x8B, 0x7E, 0xD0); E @(0x03, 0x7E, 0xF2)       # es:di = the dest row
E @(0x0B, 0xC0); Jr 0x78 'c6b2'; E @(0x3B, 0x46, 0xDE); Jr 0x7D 'c6b2'
E @(0x57); E @(0x03, 0xF8); E @(0x8A, 0xCE); E @(0xF6, 0xD1); E @(0x26, 0x20, 0x0D); E @(0x26, 0x08, 0x3D); E @(0x5F)   # [col] = ([col] AND NOT dh) OR bh
Lbl 'c6b2'
E @(0x40); E @(0x0B, 0xC0); Jr 0x78 'c6nx'; E @(0x3B, 0x46, 0xDE); Jr 0x7D 'c6nx'
E @(0x03, 0xF8); E @(0x8A, 0xCA); E @(0xF6, 0xD1); E @(0x26, 0x20, 0x0D); E @(0x26, 0x08, 0x1D)   # [col + 1] with dl, bl
Lbl 'c6nx'
E @(0xFF, 0x46, 0xEE); JmpN 'c6byte'
Lbl 'c6nrow'
E @(0xFF, 0x46, 0xEC); JmpN 'c6row'
Lbl 'c56end'
E @(0x8D, 0x66, 0xF4); JmpN 'cdone'                                       # lea sp,[bp-12]
Lbl 'cdone'
E @(0x0F, 0xA1); E @(0x07, 0x5B, 0x5F, 0x5E, 0x1F); E @(0x5D); E @(0xCA, 0x04, 0x00)
$comp = $script:a.Resolve()

# =============================================================================
# C3DSKIN: CALL ABSOLUTE(BYVAL pseg, BYVAL poff, SADD(skin$)) RETF 4  -- block of 17 words:
#   0/1 mx seg/off  2/3 my  4/5 mz    the rest pose (x16 units)
#   6/7 out x seg/off  8/9 out y  10/11 out z
#   12 nv   13/14 bones seg/off: a word per vertex, low byte bone 1, high byte bone 2 (equal = rigid,
#           else the two results averaged)
#   15/16 matrices seg/off: 12 words per bone, r00 r01 r02 tx r10 r11 r12 ty r20 r21 r22 tz
#           (rotation x16384, translation x16 units)
#   out = (r . v + 8192) >> 14 + t per row (the idle poses of MANWALK, MANIDLE.ANI)
#   locals: the block copied to [bp-34..-1] (word k at bp-34+2k); x y z dwords at bp-38/-42/-46,
#   results at bp-50/-54/-58, i*2 at bp-60, the count at bp-62
# =============================================================================
$script:a = [Asm]::new()
E @(0x55); E @(0x8B, 0xEC); E @(0x83, 0xEC, 0x40); E @(0x1E, 0x56, 0x57, 0x53, 0x06)
E @(0x16, 0x07)                                                           # es = ss
MovDsM 8; MovRM 'si' 6
E @(0x8D, 0x7E, 0xDE); E @(0xB9, 0x11, 0x00); E @(0xFC); E @(0xF3, 0xA5)  # the block -> [bp-34]
E @(0xC7, 0x46, 0xC4, 0x00, 0x00)                                         # i*2 = 0
MovRM 'ax' -10; MovMR -62 'ax'
E @(0x85, 0xC0); Jn @(0x0F, 0x8E) 'sdone'
Lbl 'sv'
MovRM 'bx' -60
MovDsM -34; MovRM 'si' -32; E @(0x03, 0xF3); E @(0x66, 0x0F, 0xBF, 0x04); E @(0x66, 0x89, 0x46, 0xDA)   # x
MovDsM -30; MovRM 'si' -28; E @(0x03, 0xF3); E @(0x66, 0x0F, 0xBF, 0x04); E @(0x66, 0x89, 0x46, 0xD6)   # y
MovDsM -26; MovRM 'si' -24; E @(0x03, 0xF3); E @(0x66, 0x0F, 0xBF, 0x04); E @(0x66, 0x89, 0x46, 0xD2)   # z
MovDsM -8; MovRM 'si' -6; E @(0x03, 0xF3); E @(0x8B, 0x14)                # dl, dh = the bones
MovDsM -4
E @(0x8A, 0xC2); CallN 'sxf'
E @(0x3A, 0xD6); Jr 0x74 'sone'
E @(0x66, 0xFF, 0x76, 0xCE); E @(0x66, 0xFF, 0x76, 0xCA); E @(0x66, 0xFF, 0x76, 0xC6)
E @(0x8A, 0xC6); CallN 'sxf'
E @(0x66, 0x59); E @(0x66, 0x01, 0x4E, 0xC6); E @(0x66, 0xD1, 0x7E, 0xC6)  # z = (z1 + z2) >> 1
E @(0x66, 0x59); E @(0x66, 0x01, 0x4E, 0xCA); E @(0x66, 0xD1, 0x7E, 0xCA)
E @(0x66, 0x59); E @(0x66, 0x01, 0x4E, 0xCE); E @(0x66, 0xD1, 0x7E, 0xCE)
Lbl 'sone'
MovDsM -22; MovRM 'si' -20; E @(0x03, 0xF3); E @(0x8B, 0x46, 0xCE); E @(0x89, 0x04)
MovDsM -18; MovRM 'si' -16; E @(0x03, 0xF3); E @(0x8B, 0x46, 0xCA); E @(0x89, 0x04)
MovDsM -14; MovRM 'si' -12; E @(0x03, 0xF3); E @(0x8B, 0x46, 0xC6); E @(0x89, 0x04)
E @(0x83, 0x46, 0xC4, 0x02)                                               # i*2 += 2
E @(0xFF, 0x4E, 0xC2); Jn @(0x0F, 0x85) 'sv'
Lbl 'sdone'
E @(0x07, 0x5B, 0x5F, 0x5E, 0x1F); E @(0x8B, 0xE5); E @(0x5D); E @(0xCA, 0x04, 0x00)
# sxf: bone al's matrix (ds = its segment) applied to x, y, z -> [bp-50], [bp-54], [bp-58]
Lbl 'sxf'
MovRM 'si' -2; E @(0x32, 0xE4); E @(0x6B, 0xC0, 0x18); E @(0x03, 0xF0)     # si = matrices + bone*24
foreach ($sr in 0, 1, 2) {
  $d = 8 * $sr
  E @(0x66, 0x0F, 0xBF, 0x44, $d); E @(0x66, 0x0F, 0xAF, 0x46, 0xDA)
  E @(0x66, 0x0F, 0xBF, 0x4C, ($d + 2)); E @(0x66, 0x0F, 0xAF, 0x4E, 0xD6); E @(0x66, 0x03, 0xC1)
  E @(0x66, 0x0F, 0xBF, 0x4C, ($d + 4)); E @(0x66, 0x0F, 0xAF, 0x4E, 0xD2); E @(0x66, 0x03, 0xC1)
  E @(0x66, 0x05, 0x00, 0x20, 0x00, 0x00); E @(0x66, 0xC1, 0xF8, 0x0E)
  E @(0x66, 0x0F, 0xBF, 0x4C, ($d + 6)); E @(0x66, 0x03, 0xC1)
  E @(0x66, 0x89, 0x46, (0xCE - 4 * $sr))
}
E @(0xC3)
$skin = $script:a.Resolve()

# =============================================================================
# C3DMSE: CALL ABSOLUTE(BYVAL seg, BYVAL off, SADD(mse$)) RETF 4 -- the mouse driver (INT 33h):
#   words 0..3 = ax, bx, cx, dx in, and the driver's ax, bx, cx, dx back (MANWALK: QB's CALL
#   INTERRUPT lives in QB.LIB, which the tools do not link). The caller checks the vector first.
# =============================================================================
$script:a = [Asm]::new()
E @(0x55); E @(0x8B, 0xEC); E @(0x1E, 0x56, 0x57, 0x53, 0x06)
MovDsM 8; MovRM 'si' 6
E @(0x8B, 0x04); E @(0x8B, 0x5C, 0x02); E @(0x8B, 0x4C, 0x04); E @(0x8B, 0x54, 0x06)   # ax bx cx dx = the block
E @(0x1E, 0x56, 0x55); E @(0xCD, 0x33); E @(0x5D, 0x5E, 0x1F)               # int 33h (ds, si, bp kept)
E @(0x89, 0x04); E @(0x89, 0x5C, 0x02); E @(0x89, 0x4C, 0x04); E @(0x89, 0x54, 0x06)   # back to the block
E @(0x07, 0x5B, 0x5F, 0x5E, 0x1F); E @(0x5D); E @(0xCA, 0x04, 0x00)
$mse = $script:a.Resolve()

# =============================================================================
# C3DMCPY: CALL ABSOLUTE(BYVAL sseg, BYVAL soff, BYVAL dseg, BYVAL doff, BYVAL mseg, BYVAL moff,
#                        BYVAL rows, BYVAL cols, BYVAL stride, BYVAL mstride, SADD(mcpy$)) RETF 20
#   a rows x cols block copied from source to destination (row stride `stride`) where the mask's byte
#   (its own row stride `mstride`) is not 0: MANWALK's furniture put back over the men behind it
#   [bp+6]=mstride [bp+8]=stride [bp+10]=cols [bp+12]=rows [bp+14]=moff [bp+16]=mseg [bp+18]=doff
#   [bp+20]=dseg [bp+22]=soff [bp+24]=sseg. The mask is read through FS (a 386 register QB leaves alone)
# =============================================================================
$script:a = [Asm]::new()
E @(0x55); E @(0x8B, 0xEC); E @(0x1E, 0x56, 0x57, 0x53, 0x06)
MovDsM 24; MovRM 'si' 22; MovEsM 20; MovRM 'di' 18; E (@(0x8E) + (MB 4 16)); MovRM 'bx' 14   # ds:si, es:di, fs:bx
MovRM 'dx' 12
Lbl 'mrow'
MovRM 'cx' 10; Jr 0xE3 'madv'
Lbl 'mpix'
E @(0x64, 0x8A, 0x07); E @(0x84, 0xC0); Jr 0x74 'mskip'                   # mask byte 0: leave it
E @(0x8A, 0x04); E @(0x26, 0x88, 0x05)                                    # es:[di] = [si]
Lbl 'mskip'
E @(0x46, 0x47, 0x43); Jr 0xE2 'mpix'
Lbl 'madv'
AddRM 'si' 8; SubRM 'si' 10; AddRM 'di' 8; SubRM 'di' 10; AddRM 'bx' 6; SubRM 'bx' 10
E @(0x4A); Jr 0x75 'mrow'
E @(0x07, 0x5B, 0x5F, 0x5E, 0x1F); E @(0x5D); E @(0xCA, 0x14, 0x00)
$mcpy = $script:a.Resolve()

# =============================================================================
# C3DCGA: CALL ABSOLUTE(BYVAL bseg, BYVAL boff, BYVAL w, BYVAL h, BYVAL lseg, BYVAL loff,
#                       BYVAL aseg, BYVAL aoff, BYVAL mseg, BYVAL moff, SADD(cga$)) RETF 20
#   the game's 3D man (GAME8): a w x h byte box (row stride w; 0 = nothing there) -> a CGA
#   SCREEN 1 GET/PUT pair: art (2 bits a pixel, the colour) and mask (11 where nothing is,
#   00 where he is), each "w*2, h" then rows of (w*2+7)\8 bytes, high bits first. Pass 1 maps
#   every byte through the 256-byte table at lseg:loff (0 -> 0, else 80h + colour 0..3); pass 2
#   packs, and leaves the box all 0 for the next render. Drawn with PUT mask AND, PUT art OR.
#   [bp+6]=moff [bp+8]=mseg [bp+10]=aoff [bp+12]=aseg [bp+14]=loff [bp+16]=lseg [bp+18]=h
#   [bp+20]=w [bp+22]=boff [bp+24]=bseg; [bp-2] = rows left
# =============================================================================
$script:a = [Asm]::new()
E @(0x55); E @(0x8B, 0xEC); E @(0x83, 0xEC, 0x04); E @(0x1E, 0x56, 0x57, 0x53, 0x06)
# pass 1: es:di the box, ds:bx the table; xlat every byte
MovEsM 24; MovRM 'di' 22; MovDsM 16; MovRM 'bx' 14
MovRM 'ax' 20; E @(0xF7, 0x66, 0x12); E @(0x8B, 0xC8); E @(0xFC); Jr 0xE3 'cskip'   # cx = w*h
Lbl 'cmap'
E @(0x26, 0x8A, 0x05); E @(0xD7); E @(0xAA); Jr 0xE2 'cmap'                 # al = es:[di]; xlat; stosb
Lbl 'cskip'
# the two headers: w*2, h
MovEsM 12; MovRM 'di' 10
MovRM 'ax' 20; E @(0xD1, 0xE0); E @(0xAB); MovRM 'ax' 18; E @(0xAB)
E (@(0x8E) + (MB 4 8)); MovRM 'bx' 6                                       # fs:bx the mask
MovRM 'ax' 20; E @(0xD1, 0xE0); E @(0x64, 0x89, 0x07); E @(0x83, 0xC3, 0x02)
MovRM 'ax' 18; E @(0x64, 0x89, 0x07); E @(0x83, 0xC3, 0x02)
# pass 2: ds:si the box (cleared as read), ah = art byte, dh = mask byte, dl = pixels to a byte
MovDsM 24; MovRM 'si' 22
MovRM 'ax' 18; MovMR -2 'ax'
Lbl 'crow'
MovRM 'cx' 20; E @(0xB2, 0x04)
Lbl 'cpix'
E @(0x8A, 0x04); E @(0xC6, 0x04, 0x00); E @(0x46)                         # al = [si]; [si] = 0
E @(0xC0, 0xE4, 0x02); E @(0xC0, 0xE6, 0x02)                              # shl ah,2; shl dh,2
E @(0xA8, 0x80); Jr 0x75 'copq'
E @(0x80, 0xCE, 0x03); Jr 0xEB 'cnxt'                                     # nothing: mask 11
Lbl 'copq'
E @(0x24, 0x03); E @(0x0A, 0xE0)                                          # him: art = colour
Lbl 'cnxt'
E @(0xFE, 0xCA); Jr 0x75 'ccont'
E @(0x26, 0x88, 0x25); E @(0x47); E @(0x64, 0x88, 0x37); E @(0x43); E @(0xB2, 0x04)   # a byte each
Lbl 'ccont'
Jr 0xE2 'cpix'
E @(0x80, 0xFA, 0x04); Jr 0x74 'crdone'                                   # a part byte left?
Lbl 'cpad'
E @(0xC0, 0xE4, 0x02); E @(0xC0, 0xE6, 0x02); E @(0x80, 0xCE, 0x03); E @(0xFE, 0xCA); Jr 0x75 'cpad'
E @(0x26, 0x88, 0x25); E @(0x47); E @(0x64, 0x88, 0x37); E @(0x43)
Lbl 'crdone'
E @(0xFF, 0x4E, 0xFE); Jn @(0x0F, 0x85) 'crow'
E @(0x07, 0x5B, 0x5F, 0x5E, 0x1F); E @(0x8B, 0xE5); E @(0x5D); E @(0xCA, 0x14, 0x00)
$cga = $script:a.Resolve()

# =============================================================================
# C3DBLTM: CALL ABSOLUTE(BYVAL sseg, BYVAL soff, BYVAL dseg, BYVAL doff, BYVAL rows,
#                        BYVAL rbytes, BYVAL sstride, BYVAL dstride, BYVAL colour, SADD(bltm$))  RETF 18
#   rectangle copy like SHADBOP mode 0, but every 254 (the silhouette mark) becomes
#   colour on the way out. Word moves, so the ISA bus sees the same traffic as a plain copy.
#   [bp+6]=colour [bp+8]=dstride [bp+10]=sstride [bp+12]=rbytes [bp+14]=rows [bp+16]=doff [bp+18]=dseg [bp+20]=soff [bp+22]=sseg
# =============================================================================
$script:a = [Asm]::new()
E @(0x55); E @(0x8B, 0xEC); E @(0x1E, 0x56, 0x57, 0x06)
MovDsM 22; MovRM 'si' 20; MovEsM 18; MovRM 'di' 16
MovRM 'dx' 14; E @(0x8A, 0x5E, 0x06)                                      # dx = rows; bl = colour
Lbl 'brow'
MovRM 'cx' 12; E @(0xD1, 0xE9); Jr 0xE3 'bodd'                            # words
Lbl 'bw'
E @(0xAD)                                                                 # lodsw
E @(0x3C, 0xFE); Jr 0x75 'b1'; E @(0x8A, 0xC3); Lbl 'b1'                  # al
E @(0x80, 0xFC, 0xFE); Jr 0x75 'b2'; E @(0x8A, 0xE3); Lbl 'b2'            # ah
E @(0xAB); Jr 0xE2 'bw'                                                   # stosw; loop
Lbl 'bodd'
E @(0xF7, 0x46, 0x0C, 0x01, 0x00); Jr 0x74 'badv'                         # odd byte?
E @(0xAC); E @(0x3C, 0xFE); Jr 0x75 'b3'; E @(0x8A, 0xC3); Lbl 'b3'; E @(0xAA)
Lbl 'badv'
MovRM 'ax' 10; SubRM 'ax' 12; E @(0x03, 0xF0)
MovRM 'ax' 8; SubRM 'ax' 12; E @(0x03, 0xF8)
E @(0x4A); Jr 0x75 'brow'
E @(0x07, 0x5F, 0x5E, 0x1F); E @(0x5D); E @(0xCA, 0x12, 0x00)
$bltm = $script:a.Resolve()

# =============================================================================
# C3DTEST: block words 0..3 = a,b,c,d in; results from word 4 (see C3DTEST.BAS)
# =============================================================================
$script:a = [Asm]::new()
E @(0x55); E @(0x8B, 0xEC); E @(0x1E, 0x56, 0x57, 0x06)
MovDsM 8; MovRM 'si' 6
E @(0x66, 0x0F, 0xBF, 0x04); E @(0x66, 0x0F, 0xBF, 0x4C, 0x02); E @(0x66, 0x0F, 0xAF, 0xC1); E @(0x66, 0x89, 0x44, 0x08)   # [4..5] = a*b
E @(0x66, 0x0F, 0xBF, 0x4C, 0x04); E @(0x66, 0x0F, 0xBF, 0x54, 0x06); E @(0x66, 0x0F, 0xAF, 0xCA); E @(0x66, 0x2B, 0xC1); E @(0x66, 0x89, 0x44, 0x0C)  # [6..7] = a*b-c*d
E @(0x66, 0x0F, 0xBF, 0x4C, 0x06); E @(0x66, 0x99); E @(0x66, 0xF7, 0xF9); E @(0x89, 0x44, 0x10)   # [8] = (a*b-c*d)/d
E @(0x66, 0x0F, 0xBF, 0x04); E @(0x66, 0xC1, 0xE0, 0x10); E @(0x66, 0x99); E @(0x66, 0x0F, 0xBF, 0x4C, 0x02); E @(0x66, 0xF7, 0xF9); E @(0x66, 0x89, 0x44, 0x14)  # [10..11] = (a<<16)/b
E @(0x8B, 0x04); E @(0x8B, 0x4C, 0x04); E @(0x0F, 0xAF, 0xC1); E @(0x89, 0x44, 0x18)   # [12] = a*c (imul r,r)
E @(0x8B, 0x04); E @(0x25, 0x3F, 0x00); E @(0xC1, 0xE0, 0x06); E @(0x89, 0x44, 0x1A)   # [13] = (a&63)<<6
E @(0x8B, 0x4C, 0x04); E @(0x33, 0xC0); Lbl 'lp'; E @(0x40); Jr 0xE2 'lp'; E @(0x89, 0x44, 0x1C)   # [14] = c (loop)
E @(0x66, 0x8B, 0x44, 0x08); E @(0x66, 0x03, 0x44, 0x0C); E @(0x89, 0x44, 0x1E)         # [15] = low16(t1+t2)
E @(0x07, 0x5F, 0x5E, 0x1F); E @(0x5D); E @(0xCA, 0x04, 0x00)
$tst = $script:a.Resolve()

$srcDir = "$PSScriptRoot\.."
[System.IO.File]::WriteAllBytes("$srcDir\C3DTRI.OVL", $tri)
[System.IO.File]::WriteAllBytes("$srcDir\C3DT128.OVL", $tri128)
[System.IO.File]::WriteAllBytes("$srcDir\C3DEDGE.OVL", $edge)
[System.IO.File]::WriteAllBytes("$srcDir\C3DEDGO.OVL", $edgo)
[System.IO.File]::WriteAllBytes("$srcDir\C3DEDGK.OVL", $edgk)
[System.IO.File]::WriteAllBytes("$srcDir\C3DEDGI.OVL", $edgi)
[System.IO.File]::WriteAllBytes("$srcDir\C3DCOMP.OVL", $comp)
[System.IO.File]::WriteAllBytes("$srcDir\C3DSKIN.OVL", $skin)
[System.IO.File]::WriteAllBytes("$srcDir\C3DMSE.OVL", $mse)
[System.IO.File]::WriteAllBytes("$srcDir\C3DMCPY.OVL", $mcpy)
[System.IO.File]::WriteAllBytes("$srcDir\C3DCGA.OVL", $cga)
[System.IO.File]::WriteAllBytes("$srcDir\C3DBLTM.OVL", $bltm)
[System.IO.File]::WriteAllBytes("$srcDir\C3DPRJ.OVL", $prj)
[System.IO.File]::WriteAllBytes("$srcDir\C3DTEST.OVL", $tst)
Write-Host "C3DTRI.OVL $($tri.Length) bytes; C3DPRJ.OVL $($prj.Length) bytes; C3DEDGE.OVL $($edge.Length) bytes; C3DBLTM.OVL $($bltm.Length) bytes; C3DTEST.OVL $($tst.Length) bytes"

# =============================================================================
# C3DROT: CALL ABSOLUTE(BYVAL seg, BYVAL off, SADD(rot$))  RETF 4  -- block of 24 words:
#   0/1 mx seg/off  2/3 my  4/5 mz  (the model, x16)   6/7 rx  8/9 ry  10/11 rz (out)
#   12 nv  13 cs  14 sn (the heading, x256)  15/16 fa seg/off (5-word records)
#   17/18 ord seg/off (out)  19 nf  20/21 lnk seg/off (nf words scratch)
#   22/23 bkt seg/off (256 words scratch)  24 cp  25 sp (the pitch, x256: 256/0 = none)
#   The pitch first, about the model's x axis (its front is +z, so sp > 0 lifts the nose):
#   y' = (y*cp + z*sp) >> 8, z' = (z*cp - y*sp) >> 8; then the heading: rx = (x*cs + z'*sn)
#   >> 8, rz = (z'*cs - x*sn) >> 8, ry = y'; then the faces bucket-sorted far-to-near by
#   (rz[a]+rz[b]+rz[c]+4096) >> 5 into ord. Shifts floor (QB's \ truncates): a 1/16-unit
#   difference on negative values.
#   About 1.4 ms on a 486SX for 483 vertices / 229 faces, so the car can turn every frame.
# =============================================================================
function QR($k) { return -96 + 2 * $k }
$script:a = [Asm]::new()
E @(0x55); E @(0x8B, 0xEC); E @(0x81, 0xEC, 0x60, 0x00); E @(0x1E, 0x56, 0x57, 0x06, 0x53)   # push bp; mov bp,sp; sub sp,96; push ds,si,di,es,bx
MovDsM 8; MovRM 'si' 6; E @(0x8C, 0xD0); E @(0x8E, 0xC0); LeaDI (QR 0); E @(0xB9, 0x1A, 0x00); E @(0xF3, 0xA5)   # block (26 words) -> locals
# ---- rotate: the pitch (about the model's x axis), then the heading ----
MovMI -4 0
Lbl 'rloop'
MovRM 'ax' -4; CmpRM 'ax' (QR 12); Jn @(0x0F, 0x8D) 'rdone'
E @(0xD1, 0xE0); MovMR -6 'ax'                                                         # i*2
MovDsM (QR 0); MovRM 'si' -6; AddRM 'si' (QR 1); E @(0x66, 0x0F, 0xBF, 0x04); Mov32MR -12 'ax'   # x
MovDsM (QR 2); MovRM 'si' -6; AddRM 'si' (QR 3); E @(0x66, 0x0F, 0xBF, 0x04); Mov32MR -20 'ax'   # y
MovDsM (QR 4); MovRM 'si' -6; AddRM 'si' (QR 5); E @(0x66, 0x0F, 0xBF, 0x0C); Mov32MR -16 'cx'   # z
Movsx32RM 'dx' (QR 24); E @(0x66, 0x0F, 0xAF, 0xC2)                                    # eax = y*cp
Movsx32RM 'dx' (QR 25); E @(0x66, 0x0F, 0xAF, 0xCA)                                    # ecx = z*sp
E @(0x66, 0x03, 0xC1); E @(0x66, 0xC1, 0xF8, 0x08)                                     # y' = (y*cp + z*sp) >> 8
MovDsM (QR 8); MovRM 'si' -6; AddRM 'si' (QR 9); E @(0x89, 0x04)                       # ry[i] = y'
Mov32RM 'ax' -16; Movsx32RM 'dx' (QR 24); E @(0x66, 0x0F, 0xAF, 0xC2)                  # eax = z*cp
Mov32RM 'cx' -20; Movsx32RM 'dx' (QR 25); E @(0x66, 0x0F, 0xAF, 0xCA)                  # ecx = y*sp
E @(0x66, 0x2B, 0xC1); E @(0x66, 0xC1, 0xF8, 0x08); Mov32MR -16 'ax'                   # z' = (z*cp - y*sp) >> 8
Mov32RM 'ax' -12; Movsx32RM 'dx' (QR 13); E @(0x66, 0x0F, 0xAF, 0xC2)                  # eax = x*cs
Mov32RM 'cx' -16; Movsx32RM 'dx' (QR 14); E @(0x66, 0x0F, 0xAF, 0xCA)                  # ecx = z'*sn
E @(0x66, 0x03, 0xC1); E @(0x66, 0xC1, 0xF8, 0x08)                                     # >> 8
MovDsM (QR 6); MovRM 'si' -6; AddRM 'si' (QR 7); E @(0x89, 0x04)                       # rx[i]
Mov32RM 'ax' -16; Movsx32RM 'dx' (QR 13); E @(0x66, 0x0F, 0xAF, 0xC2)                  # eax = z'*cs
Mov32RM 'cx' -12; Movsx32RM 'dx' (QR 14); E @(0x66, 0x0F, 0xAF, 0xCA)                  # ecx = x*sn
E @(0x66, 0x2B, 0xC1); E @(0x66, 0xC1, 0xF8, 0x08)
MovDsM (QR 10); MovRM 'si' -6; AddRM 'si' (QR 11); E @(0x89, 0x04)                     # rz[i]
IncM -4; JmpN 'rloop'
Lbl 'rdone'
# ---- bucket the faces by depth ----
MovEsM (QR 22); MovRM 'di' (QR 23); E @(0xB9, 0x00, 0x01); E @(0xB8, 0xFF, 0xFF); E @(0xF3, 0xAB)   # bkt[] = -1
MovMI -4 0
Lbl 'floop'
MovRM 'ax' -4; CmpRM 'ax' (QR 19); Jn @(0x0F, 0x8D) 'fdone'
E @(0x8B, 0xC8); E @(0xC1, 0xE0, 0x03); E @(0x03, 0xC1); E @(0x03, 0xC1); MovMR -6 'ax'   # f*10
MovDsM (QR 15); MovRM 'si' -6; AddRM 'si' (QR 16)                                      # ds:si -> fa[f]
MovEsM (QR 10)                                                                         # es = rz
E @(0x8B, 0x1C); E @(0xD1, 0xE3); AddRM 'bx' (QR 11); E @(0x26, 0x8B, 0x17)            # dx = rz[a]
E @(0x8B, 0x5C, 0x02); E @(0xD1, 0xE3); AddRM 'bx' (QR 11); E @(0x26, 0x03, 0x17)      # + rz[b]
E @(0x8B, 0x5C, 0x04); E @(0xD1, 0xE3); AddRM 'bx' (QR 11); E @(0x26, 0x03, 0x17)      # + rz[c]
E @(0x81, 0xC2, 0x00, 0x10); E @(0xC1, 0xFA, 0x05)                                     # (+4096) >> 5
E @(0x83, 0xFA, 0x00); Jr 0x7D 'c1'; E @(0x33, 0xD2); Lbl 'c1'                          # clamp 0
E @(0x81, 0xFA, 0xFF, 0x00); Jr 0x7E 'c2'; E @(0xBA, 0xFF, 0x00); Lbl 'c2'              # clamp 255
E @(0xD1, 0xE2)
MovEsM (QR 22); E @(0x8B, 0xDA); AddRM 'bx' (QR 23)                                    # es:bx -> bkt[d]
E @(0x26, 0x8B, 0x07); MovRM 'cx' -4; E @(0x26, 0x89, 0x0F)                            # ax = bkt[d]; bkt[d] = f
MovEsM (QR 20); MovRM 'bx' -4; E @(0xD1, 0xE3); AddRM 'bx' (QR 21); E @(0x26, 0x89, 0x07)   # lnk[f] = ax
IncM -4; JmpN 'floop'
Lbl 'fdone'
# ---- gather far-to-near ----
MovMI -8 0; MovMI -4 255
Lbl 'gloop'
MovEsM (QR 22); MovRM 'bx' -4; E @(0xD1, 0xE3); AddRM 'bx' (QR 23); E @(0x26, 0x8B, 0x07)   # ax = bkt[bk]
Lbl 'wloop'
E @(0x85, 0xC0); Jr 0x78 'wdone'
MovEsM (QR 17); MovRM 'bx' -8; E @(0xD1, 0xE3); AddRM 'bx' (QR 18); E @(0x26, 0x89, 0x07); IncM -8   # ord[n++] = f
MovEsM (QR 20); E @(0x8B, 0xD8); E @(0xD1, 0xE3); AddRM 'bx' (QR 21); E @(0x26, 0x8B, 0x07)          # ax = lnk[f]
Jr 0xEB 'wloop'
Lbl 'wdone'
E @(0xFF, 0x4E, (D8 -4)); Jn @(0x0F, 0x89) 'gloop'                                     # dec bk; jns
E @(0x5B, 0x07, 0x5F, 0x5E, 0x1F); E @(0x8B, 0xE5); E @(0x5D); E @(0xCA, 0x04, 0x00)
$rot = $script:a.Resolve()

# =============================================================================
# C3DBLTF: CALL ABSOLUTE(BYVAL sseg, BYVAL soff, BYVAL dseg, BYVAL doff, BYVAL fseg, BYVAL foff,
#                        BYVAL rows, BYVAL rbytes, BYVAL sstride, BYVAL dstride, BYVAL fstride,
#                        BYVAL colour, SADD(bltf$))  RETF 24
#   C3DBLTM with a foreground layer: the same rectangle of the backdrop strip (fseg:foff,
#   stride fstride) is read alongside; where the strip byte has bit 7 set (a pixel the
#   artist marked "in front", carr_road2_front.png) that byte goes out instead of the work
#   buffer's, so the car passes behind it. The palette mirrors 0..15 at 128..143, so the
#   flagged value shows as the same colour. 254 -> colour as before.
#   [bp+6]=colour [bp+8]=fstride [bp+10]=dstride [bp+12]=sstride [bp+14]=rbytes [bp+16]=rows
#   [bp+18]=foff [bp+20]=fseg [bp+22]=doff [bp+24]=dseg [bp+26]=soff [bp+28]=sseg
# =============================================================================
$script:a = [Asm]::new()
E @(0x55); E @(0x8B, 0xEC); E @(0x1E, 0x56, 0x57, 0x06, 0x53); E @(0x0F, 0xA0)         # push ds,si,di,es,bx,fs
MovDsM 28; MovRM 'si' 26; MovEsM 24; MovRM 'di' 22
E @(0x8E, 0x66, 0x14); MovRM 'bx' 18                                                   # fs = fseg; bx = foff
Lbl 'frow'
MovRM 'cx' 14; E @(0xD1, 0xE9); Jr 0xE3 'fodd'
Lbl 'fw'
E @(0xAD); E @(0x64, 0x8B, 0x17); E @(0x83, 0xC3, 0x02)                                # lodsw; dx = fs:[bx]; bx += 2
E @(0xF6, 0xC2, 0x80); Jr 0x74 'n1'; E @(0x8A, 0xC2); Jr 0xEB 'm1'                     # al: flagged -> strip byte
Lbl 'n1'; E @(0x3C, 0xFE); Jr 0x75 'm1'; E @(0x8A, 0x46, 0x06)                          #     254 -> colour
Lbl 'm1'
E @(0xF6, 0xC6, 0x80); Jr 0x74 'n2'; E @(0x8A, 0xE6); Jr 0xEB 'm2'                     # ah
Lbl 'n2'; E @(0x80, 0xFC, 0xFE); Jr 0x75 'm2'; E @(0x8A, 0x66, 0x06)
Lbl 'm2'
E @(0xAB); Jr 0xE2 'fw'                                                                # stosw; loop
Lbl 'fodd'
E @(0xF7, 0x46, 0x0E, 0x01, 0x00); Jr 0x74 'fadv'
E @(0xAC); E @(0x64, 0x8A, 0x17); E @(0x43)                                            # lodsb; dl = fs:[bx]; inc bx
E @(0xF6, 0xC2, 0x80); Jr 0x74 'n3'; E @(0x8A, 0xC2); Jr 0xEB 'm3'
Lbl 'n3'; E @(0x3C, 0xFE); Jr 0x75 'm3'; E @(0x8A, 0x46, 0x06)
Lbl 'm3'; E @(0xAA)
Lbl 'fadv'
MovRM 'ax' 12; SubRM 'ax' 14; E @(0x03, 0xF0)                                          # si += sstride - rbytes
MovRM 'ax' 10; SubRM 'ax' 14; E @(0x03, 0xF8)                                          # di += dstride - rbytes
MovRM 'ax' 8; SubRM 'ax' 14; E @(0x03, 0xD8)                                           # bx += fstride - rbytes
E @(0xFF, 0x4E, 0x10); Jn @(0x0F, 0x85) 'frow'                                         # dec rows; jnz
E @(0x0F, 0xA1); E @(0x5B, 0x07, 0x5F, 0x5E, 0x1F); E @(0x5D); E @(0xCA, 0x18, 0x00)
$bltf = $script:a.Resolve()

[System.IO.File]::WriteAllBytes("$srcDir\C3DROT.OVL", $rot)
[System.IO.File]::WriteAllBytes("$srcDir\C3DBLTF.OVL", $bltf)
Write-Host "C3DROT.OVL $($rot.Length) bytes; C3DBLTF.OVL $($bltf.Length) bytes"

# =============================================================================
# C3DFUSE: CALL ABSOLUTE(BYVAL seg, BYVAL off, SADD(fuse$)) RETF 4 -- C3DSKIN, C3DROT's turn
#   and C3DPRJ in one pass (GAME8 M3OPT 256). Block of 34 words:
#    0/1 mx seg/off  2/3 my  4/5 mz       the rest pose (x16 units)
#    6/7 vt seg/off   the interleaved vertex array: x, y written (1/16 px) at +0, +2 of 8 bytes a vertex
#    8/9 rz seg/off   out: the depth (camera z less the feet's, x16 units) for C3DROT's face sort
#   10 nv   11/12 bones seg/off (C3DSKIN's word a vertex: low byte bone 1, high byte bone 2)
#   13/14 matrices seg/off (C3DSKIN's 12 words a bone)   15/16 scratch seg/off (15 words a bone)
#   17 the bone count   18 vA = k cos, 19 vB = k sin, 20 vY = k (x4096: k the depth scale x256 / 256)
#   21/22 px  23/24 py  25/26 pz (LONGs, x16 units: the feet's camera position)
#   27 the horizontal focal length x16   28/29 the picture centre (1/16 px)
#   30..33 out: min x, max x, min y, max y (1/16 px)
#   34/35 twins seg/off, 36 all the vertices: (GAME8 M3OPT 512) 10 is then the count to transform,
#   vertex 10 + k a copy of vertex twins[k]'s place and depth (the texture's seams), 36 = 0 none
#   First each bone's matrix is turned and scaled into the scratch (x8192, the translation a
#   dword with the feet added): CX = (vA R0 + vB R2) >> 13, CY = vY R1 >> 13, CZ = (vA R2 - vB R0)
#   >> 13; the translations >> 12. Then a vertex is X = (CX . v + 4096) >> 13 + tX (Y, Z alike; two bones averaged),
#   sx = cx + X F / max(Z, 16), sy = cy - (Y << 12) / max(Z, 16), rz = Z - pz.
#   Locals: the block at bp-128 (word k at -128+2k); i -60, i*2 -58; X1 Y1 Z1 -56 -52 -48;
#   X Y Z -44 -40 -36; v -32 -28 -24; vA vB vY F (dwords) -20 -16 -12 -8
# =============================================================================
function K($k) { return -128 + 2 * $k }
function Imul32RM($reg, $d8) { E (@(0x66, 0x0F, 0xAF) + (MB $R[$reg] $d8)) }   # imul r32,[bp+d]
function Sub32RM($reg, $d8) { E (@(0x66, 0x2B) + (MB $R[$reg] $d8)) }          # sub r32,[bp+d]
$script:a = [Asm]::new()
E @(0x55); E @(0x8B, 0xEC); E @(0x81, 0xEC, 0x80, 0x00); E @(0x1E, 0x56, 0x57, 0x06, 0x53)   # push bp; mov bp,sp; sub sp,128; push ds si di es bx
MovDsM 8; MovRM 'si' 6; E @(0x16, 0x07); LeaDI (K 0); E @(0xB9, 0x22, 0x00); E @(0xFC); E @(0xF3, 0xA5)   # the block (34 words) -> [bp-128]
MovMI (K 30) 32767; MovMI (K 31) -32768; MovMI (K 32) 32767; MovMI (K 33) -32768
Movsx32RM 'ax' (K 18); Mov32MR -20 'ax'; Movsx32RM 'ax' (K 19); Mov32MR -16 'ax'
Movsx32RM 'ax' (K 20); Mov32MR -12 'ax'; Movsx32RM 'ax' (K 27); Mov32MR -8 'ax'
# ---- the bones: ds:si = a matrix (12 words), es:di = its turned copy (15 words) ----
MovDsM (K 13); MovRM 'si' (K 14); MovEsM (K 15); MovRM 'di' (K 16); MovRM 'cx' (K 17)
E @(0x85, 0xC9); Jn @(0x0F, 0x84) 'bdone'                                   # test cx,cx; jz
Lbl 'bloop'
foreach ($j in 0, 1, 2) {
  $o0 = 2 * $j; $o1 = 8 + 2 * $j; $o2 = 16 + 2 * $j
  E @(0x66, 0x0F, 0xBF, 0x44, $o0); Imul32RM 'ax' -20                       # eax = R0j vA
  E @(0x66, 0x0F, 0xBF, 0x54, $o2); Imul32RM 'dx' -16                       # edx = R2j vB
  E @(0x66, 0x03, 0xC2); E @(0x66, 0xC1, 0xF8, 0x0D); E @(0x26, 0x89, 0x45, $o0)          # CXj = (..) >> 13 (x8192)
  E @(0x66, 0x0F, 0xBF, 0x44, $o1); Imul32RM 'ax' -12                       # eax = R1j vY
  E @(0x66, 0xC1, 0xF8, 0x0D); E @(0x26, 0x89, 0x45, (10 + 2 * $j))         # CYj
  E @(0x66, 0x0F, 0xBF, 0x44, $o2); Imul32RM 'ax' -20                       # eax = R2j vA
  E @(0x66, 0x0F, 0xBF, 0x54, $o0); Imul32RM 'dx' -16                       # edx = R0j vB
  E @(0x66, 0x2B, 0xC2); E @(0x66, 0xC1, 0xF8, 0x0D); E @(0x26, 0x89, 0x45, (20 + 2 * $j)) # CZj
}
E @(0x66, 0x0F, 0xBF, 0x44, 0x06); Imul32RM 'ax' -20; E @(0x66, 0x0F, 0xBF, 0x54, 0x16); Imul32RM 'dx' -16
E @(0x66, 0x03, 0xC2); E @(0x66, 0xC1, 0xF8, 0x0C); Add32RM 'ax' (K 21); E @(0x26, 0x66, 0x89, 0x45, 0x06)   # tX = (t0 vA + t2 vB) >> 12 + px
E @(0x66, 0x0F, 0xBF, 0x44, 0x0E); Imul32RM 'ax' -12
E @(0x66, 0xC1, 0xF8, 0x0C); Add32RM 'ax' (K 23); E @(0x26, 0x66, 0x89, 0x45, 0x10)                          # tY = t1 vY >> 12 + py
E @(0x66, 0x0F, 0xBF, 0x44, 0x16); Imul32RM 'ax' -20; E @(0x66, 0x0F, 0xBF, 0x54, 0x06); Imul32RM 'dx' -16
E @(0x66, 0x2B, 0xC2); E @(0x66, 0xC1, 0xF8, 0x0C); Add32RM 'ax' (K 25); E @(0x26, 0x66, 0x89, 0x45, 0x1A)   # tZ = (t2 vA - t0 vB) >> 12 + pz
E @(0x83, 0xC6, 0x18); E @(0x83, 0xC7, 0x1E); E @(0x49); Jn @(0x0F, 0x85) 'bloop'   # si += 24; di += 30; loop
Lbl 'bdone'
# ---- the vertices ----
MovEsM (K 15)                                                               # es = the turned matrices
MovMI -60 0
Lbl 'vloop'
MovRM 'ax' -60; CmpRM 'ax' (K 10); Jn @(0x0F, 0x8D) 'vdone'
E @(0xD1, 0xE0); MovMR -58 'ax'                                             # i*2
MovDsM (K 0); MovRM 'si' (K 1); AddRM 'si' -58; E @(0x66, 0x0F, 0xBF, 0x04); Mov32MR -32 'ax'   # v
MovDsM (K 2); MovRM 'si' (K 3); AddRM 'si' -58; E @(0x66, 0x0F, 0xBF, 0x04); Mov32MR -28 'ax'
MovDsM (K 4); MovRM 'si' (K 5); AddRM 'si' -58; E @(0x66, 0x0F, 0xBF, 0x04); Mov32MR -24 'ax'
MovDsM (K 11); MovRM 'si' (K 12); AddRM 'si' -58; E @(0x8B, 0x14)          # dl, dh = the bones
E @(0x52); E @(0x8A, 0xC2); CallN 'xf'; E @(0x5A)                           # bone 1 -> X1 Y1 Z1
Mov32RM 'ax' -56; Mov32MR -44 'ax'; Mov32RM 'ax' -52; Mov32MR -40 'ax'; Mov32RM 'ax' -48; Mov32MR -36 'ax'
E @(0x3A, 0xD6); Jr 0x74 'vone'                                             # cmp dl,dh; je
E @(0x8A, 0xC6); CallN 'xf'                                                 # bone 2: the average
foreach ($p in @(@(-44, -56), @(-40, -52), @(-36, -48))) { Mov32RM 'ax' $p[0]; Add32RM 'ax' $p[1]; E @(0x66, 0xD1, 0xF8); Mov32MR $p[0] 'ax' }
Lbl 'vone'
Mov32RM 'ax' -36; Sub32RM 'ax' (K 25)                                       # rz = Z - pz
MovDsM (K 8); MovRM 'si' (K 9); AddRM 'si' -58; E @(0x89, 0x04)
Mov32RM 'cx' -36; E @(0x66, 0x83, 0xF9, 0x10); Jr 0x7D 'zok'; E @(0x66, 0xB9, 0x10, 0x00, 0x00, 0x00); Lbl 'zok'   # ecx = max(Z, 16)
Mov32RM 'ax' -44; Imul32RM 'ax' -8; E @(0x66, 0x99); E @(0x66, 0xF7, 0xF9); AddRM 'ax' (K 28); E @(0x8B, 0xD8)   # bx = sx
Mov32RM 'ax' -40; E @(0x66, 0xC1, 0xE0, 0x0C); E @(0x66, 0x99); E @(0x66, 0xF7, 0xF9)
MovRM 'dx' (K 29); E @(0x2B, 0xD0)                                          # dx = sy
MovDsM (K 6); MovRM 'si' -58; E @(0xC1, 0xE6, 0x02); AddRM 'si' (K 7); E @(0x89, 0x1C); E @(0x89, 0x54, 0x02)   # vt[i].x, .y
CmpRM 'bx' (K 30); Jr 0x7D 'm1'; MovMR (K 30) 'bx'; Lbl 'm1'
CmpRM 'bx' (K 31); Jr 0x7E 'm2'; MovMR (K 31) 'bx'; Lbl 'm2'
CmpRM 'dx' (K 32); Jr 0x7D 'm3'; MovMR (K 32) 'dx'; Lbl 'm3'
CmpRM 'dx' (K 33); Jr 0x7E 'm4'; MovMR (K 33) 'dx'; Lbl 'm4'
IncM -60; JmpN 'vloop'
Lbl 'vdone'
# ---- the twins: vertices U..all-1 copy their twin's place and depth (vA vB vY's slots reused)
MovDsM 8; MovRM 'si' 6
E @(0x8B, 0x44, 0x44); MovMR -20 'ax'; E @(0x8B, 0x44, 0x46); MovMR -16 'ax'; E @(0x8B, 0x44, 0x48); MovMR -12 'ax'   # words 34, 35, 36
MovRM 'ax' (K 10); MovMR -60 'ax'
Lbl 'gloop'
MovRM 'ax' -60; CmpRM 'ax' -12; Jn @(0x0F, 0x8D) 'gdone'
SubRM 'ax' (K 10); E @(0xD1, 0xE0)
MovDsM -20; MovRM 'si' -16; E @(0x03, 0xF0); E @(0x8B, 0x1C); E @(0xD1, 0xE3)      # bx = twin*2
MovRM 'cx' -60; E @(0xD1, 0xE1)                                                     # cx = i*2
MovDsM (K 8); MovRM 'si' (K 9); MovRM 'di' (K 9)
E @(0x03, 0xF3); E @(0x03, 0xF9); E @(0x8B, 0x04); E @(0x89, 0x05)                  # rz[i] = rz[twin]
E @(0xC1, 0xE3, 0x02); E @(0xC1, 0xE1, 0x02)
MovDsM (K 6); MovRM 'si' (K 7); MovRM 'di' (K 7)
E @(0x03, 0xF3); E @(0x03, 0xF9); E @(0x8B, 0x04); E @(0x89, 0x05); E @(0x8B, 0x44, 0x02); E @(0x89, 0x45, 0x02)   # vt[i].x, .y
IncM -60; JmpN 'gloop'
Lbl 'gdone'
MovEsM 8; MovRM 'di' 6; E @(0x83, 0xC7, 0x3C); E @(0x16, 0x1F); LeaSI (K 30); E @(0xB9, 0x04, 0x00); E @(0xF3, 0xA5)   # min/max -> block words 30..33
E @(0x5B, 0x07, 0x5F, 0x5E, 0x1F); E @(0x8B, 0xE5); E @(0x5D); E @(0xCA, 0x04, 0x00)
# xf: bone al's turned matrix (es:bx) on v -> X1 Y1 Z1
Lbl 'xf'
E @(0x32, 0xE4); E @(0x6B, 0xC0, 0x1E); AddRM 'ax' (K 16); E @(0x8B, 0xD8)   # bx = scratch + bone*30
foreach ($row in @(@(0, -56), @(10, -52), @(20, -48))) {
  $o = $row[0]
  E @(0x26, 0x66, 0x0F, 0xBF, 0x47, $o); Imul32RM 'ax' -32
  E @(0x26, 0x66, 0x0F, 0xBF, 0x4F, ($o + 2)); Imul32RM 'cx' -28; E @(0x66, 0x03, 0xC1)
  E @(0x26, 0x66, 0x0F, 0xBF, 0x4F, ($o + 4)); Imul32RM 'cx' -24; E @(0x66, 0x03, 0xC1)
  E @(0x66, 0x05, 0x00, 0x10, 0x00, 0x00); E @(0x66, 0xC1, 0xF8, 0x0D); E @(0x26, 0x66, 0x03, 0x47, ($o + 6))
  Mov32MR $row[1] 'ax'
}
E @(0xC3)
$fuse = $script:a.Resolve()
[System.IO.File]::WriteAllBytes("$srcDir\C3DFUSE.OVL", $fuse)
Write-Host "C3DFUSE.OVL $($fuse.Length) bytes"

# =============================================================================
# C3DPCM: CALL ABSOLUTE(BYVAL seg, BYVAL off, VARPTR(oPcm(0))) RETF 4 -- the 3D man's walk clock and his
#   recorded footsteps (FOOTSTEP.DAT) on the PC speaker by pulse width, both from the timer interrupt (INT 8
#   taken over, the old vector kept and chained to at its own 65536-clock rate, so TIMER keeps its time; see
#   op 5 for QB's music engine). Block of 14 words: 0 op, 1/2 samples
#   seg/off, 3 the sample count (op 0) or BIOS ticks to time (op 1), 4 the delay loop count D (op 1), 5
#   ticks a sample, (op 0) 6/7 the ramp-in / ramp-out entries, 8 their segment, 9/10 their offsets, 11 the
#   half-period delay, 12 ticks to wait first, 13 ticks to count on after the sound (a stream outside the
#   clock); (op 1) 6/7 out: the periods counted (dword).
#   A TICK = 128 clocks (9.3 kHz); the tick count (a dword, offsets 49/51) is the clock GAME8 paces the
#   walk frames by (512 ticks to a BIOS tick).
#   op 5 CLOCK ON: INT 8 taken over at channel 0 set to 2048 (every 32nd interrupt on to the old handler,
#      which runs at the BIOS 65536: QB's music engine must be IDLE then -- it hooks the vector while a
#      note is queued and puts back the vector it found when its queue empties, over anyone who hooked
#      after it; notes played while we are in stack on top of us and unstack), the count up by 16 an
#      interrupt (phase 7). GAME8 turns it on for a walk and off after.
#   op 0 PLAY a footstep (in the clock, or alone: the vector taken then): channel 0 to 128 clocks, every
#      512th tick chained, the count up by 1 a tick; one element a tick: the wait
#      (word 12 ticks, no output), the RAMP-IN (every other entry of the file's 64-clock ramp: channel 2
#      in mode 0 then mode 4, low byte only, with the entry as the count, the half-period delay -- 64
#      clocks -- between: the output low, then high, a 9.3 kHz square -- half on a real speaker -- while
#      86Box, which takes mode 0 and 4 as a level 40 count - 5120 (its snd_speaker.c) and QB's note as
#      2560, goes smoothly from the note's level (count 192) to the samples' (32)), the SAMPLES (channel
#      2 in mode 0, the sample 1..63 written to port 42h after the mode word: a fresh pulse, the output low
#      that many clocks of the 128 -- a real speaker hears half the swing it did at 64-clock periods, and
#      a 9.3 kHz carrier; 86Box the same level as before), the RAMP-OUT, then channel 2 as QB left it
#      (mode 3, count 36: the speaker stays on). In the clock: back to 2048 and phase 7. Alone: the count
#      goes on for word 13 ticks (phase 5), then (6) the vector and channel 0 are put back at a chain tick.
#      ~25% of a 486SX-25 while the samples play (its interrupts cost ~25 us each), ~70% for the 2 x 8 ms
#      of ramps.
#   op 2 STOP: whatever runs ended now: channel 0 and the vector back (before the arrays are given back)
#   op 1 CALIBRATE: a silent 64-clock period (mode word, a count, D turns of LOOP, a tick read) with the
#      speaker's data bit off, interrupts on, counted from one BIOS tick edge for word 3 ticks: GAME8
#      solves period = a + b D from two D values -> the ramps' half-period delay
#   The state lives in the overlay itself (offsets 10..60, addressed off BX = the overlay's own offset in
#   its segment, found by call/pop -- the array need not sit at offset 0; GAME8 PEEKs the phase at 15 and
#   the tick count at 49), the handler at offset 61. The overlay's array must not move while the handler
#   is hooked (no REDIM then): GAME8 stops it at a walk's end and before a page.
# =============================================================================
$script:a = [Asm]::new()
$Q = @{ farj = 10; ooff = 11; oseg = 13; phase = 15; count = 17; poff = 19; pseg = 21; sub = 23; chain = 25; chr = 27; ns = 29; soff = 31; sseg = 33; per = 35; rin = 37; rino = 39; rout = 41; routo = 43; rseg = 45; half = 47; tlo = 49; thi = 51; clk = 53; fchr = 55; schr = 57; tail = 59 }
$ISR = 61
function BxAx($k) { E (@(0x2E, 0x8B, 0x47, $Q[$k])) }                     # mov ax,[cs:bx+k]
function AxBx($k) { E (@(0x2E, 0x89, 0x47, $Q[$k])) }                     # mov [cs:bx+k],ax
function BxR($reg, $k) { E (@(0x2E, 0x8B, (0x47 -bor ($R[$reg] -shl 3)), $Q[$k])) }   # mov r16,[cs:bx+k]
function RBx($k, $reg) { E (@(0x2E, 0x89, (0x47 -bor ($R[$reg] -shl 3)), $Q[$k])) }   # mov [cs:bx+k],r16
function DecBx($k) { E (@(0x2E, 0xFF, 0x4F, $Q[$k])) }                    # dec word [cs:bx+k]
function IncBx($k) { E (@(0x2E, 0xFF, 0x47, $Q[$k])) }                    # inc word [cs:bx+k]
function AddBx8($k, $i) { E (@(0x2E, 0x83, 0x47, $Q[$k], (D8 $i))) }      # add word [cs:bx+k],imm8
function AdcBx8($k, $i) { E (@(0x2E, 0x83, 0x57, $Q[$k], (D8 $i))) }      # adc word [cs:bx+k],imm8
function CmpBx8($k, $i) { E (@(0x2E, 0x83, 0x7F, $Q[$k], (D8 $i))) }      # cmp word [cs:bx+k],imm8
function BxI($k, $i) { E (@(0x2E, 0xC7, 0x47, $Q[$k]) + (W16 $i)) }      # mov word [cs:bx+k],imm16
function LdsSi($k) { E (@(0x2E, 0xC5, 0x77, $Q[$k])) }                    # lds si,[cs:bx+k]
function Ch2($mode) { E @(0xB0, $mode, 0xE6, 0x43, 0x8A, 0xC4, 0xE6, 0x42) }   # out 43h,mode; out 42h,ah
function Ch0($lo, $hi) { E @(0xB0, 0x36, 0xE6, 0x43, 0xB0, $lo, 0xE6, 0x40, 0xB0, $hi, 0xE6, 0x40) }   # channel 0 mode 3, the reload
function Ch2Qb() { E @(0xB0, 0xB6, 0xE6, 0x43, 0xB0, 0x24, 0xE6, 0x42, 0x32, 0xC0, 0xE6, 0x42) }   # channel 2 as QB left it: mode 3, count 36
# ---- offset 0: the entry stub -- bx = the overlay's own offset, then the entry
E @(0xE8, 0x00, 0x00); E @(0x5B); E @(0x83, 0xEB, 0x03); JmpN 'pentry'     # call +0; pop bx; sub bx,3; jmp pentry
# ---- offsets 10..60: the state (10: jmp far to the old handler, filled in when hooked)
Lbl 'farj'; E @(0xEA, 0, 0, 0, 0)
E (New-Object byte[] 46)
# ---- the interrupt handler (offset 61): bx = the overlay's offset (call/pop), dx = the phase
Lbl 'pisr'
E @(0x50, 0x53, 0x51, 0x52, 0x56, 0x1E)                                   # push ax bx cx dx si ds
E @(0xE8, 0x00, 0x00); E @(0x5B); E @(0x83, 0xEB, ($ISR + 9))             # call +0; pop bx; sub bx,(the pop's offset)
BxR 'dx' 'phase'
E @(0x83, 0xFA, 0x07); Jr 0x74 'i7'                                       # 7 the clock idling: 16 ticks an interrupt
E @(0x83, 0xFA, 0x08); Jr 0x75 'inot7'                                   # 8 a click sounding (in the clock): its ticks counted down
E @(0x2E, 0x83, 0x6F, $Q['count'], 0x10); Jr 0x7F 'i7'
Ch2Qb; BxI 'phase' 7                                                      # over: channel 2 as QB left it
Lbl 'i7'; AddBx8 'tlo' 16; AdcBx8 'thi' 0; JmpN 'ichain'
Lbl 'inot7'
AddBx8 'tlo' 1; AdcBx8 'thi' 0
E @(0x83, 0xFA, 0x01); Jr 0x75 'inot1'                                   # 1 the wait
DecBx 'count'; Jn @(0x0F, 0x85) 'ichain'
CallN 'pnext'; JmpN 'ichain'
Lbl 'inot1'
E @(0x83, 0xFA, 0x03); Jr 0x74 'isamp'
E @(0x83, 0xFA, 0x02); Jr 0x74 'iramp'
E @(0x83, 0xFA, 0x04); Jr 0x74 'iramp'
E @(0x83, 0xFA, 0x05); Jn @(0x0F, 0x85) 'ichain'                                   # 5 counting on alone: for word 13 ticks
DecBx 'count'; Jn @(0x0F, 0x85) 'ichain'; BxI 'phase' 6
JmpN 'ichain'                                                          # 0 off, 6 finishing: nothing
Lbl 'isamp'

LdsSi 'poff'                                                              # ds:si = the sample
E @(0x8A, 0x24)                                                           # ah = the sample
Ch2 0x90                                                                  # mode 0, the count: a fresh pulse
DecBx 'sub'; Jr 0x75 'ichain'
BxAx 'per'; AxBx 'sub'
IncBx 'poff'
DecBx 'count'; Jr 0x75 'ichain'
CallN 'pnext'; Jr 0xEB 'ichain'
Lbl 'iramp'
LdsSi 'poff'
E @(0xAC, 0x8A, 0xE0, 0x46)                                               # lodsb; ah = the entry; the next one skipped
RBx 'poff' 'si'
Ch2 0x90                                                                  # mode 0: the output low
BxR 'cx' 'half'; Lbl 'ihd'; Jr 0xE2 'ihd'                                 # the half-period delay
Ch2 0x98                                                                  # mode 4: the output high
DecBx 'count'; Jr 0x75 'ichain'
CallN 'pnext'
Lbl 'ichain'                                                             # the old handler's tick every 512 fast ticks (a slow interrupt = 16)
CmpBx8 'phase' 7; Jr 0x7C 'ic1'; E @(0x2E, 0x83, 0x6F, $Q['chain'], 0x10); Jr 0xEB 'ic2'
Lbl 'ic1'; DecBx 'chain'
Lbl 'ic2'; CmpBx8 'chain' 0; Jr 0x7F 'inoch'
E @(0x2E, 0x81, 0x47, $Q['chain'], 0x00, 0x02)                                 # chain += 512 (a deficit carried)
CmpBx8 'phase' 6; Jr 0x75 'idoch'
CallN 'prestore'                                                          # a lone stream over: QB's clock and vector back
Lbl 'idoch'
E @(0x1F, 0x5E, 0x5A, 0x59, 0x5B, 0x58)                                   # pop ds si dx cx bx ax
JmpN 'farj'                                                               # on to the old handler (it does the EOI)
Lbl 'inoch'
E @(0xB0, 0x20, 0xE6, 0x20)                                               # EOI
E @(0x1F, 0x5E, 0x5A, 0x59, 0x5B, 0x58); E @(0xCF)                        # iret
# ---- pnext: the next phase of the stream (an empty one skipped)
Lbl 'pnext'
IncBx 'phase'; BxR 'dx' 'phase'
E @(0x83, 0xFA, 0x02); Jr 0x75 'pn3'
BxAx 'rino'; AxBx 'poff'; BxAx 'rseg'; AxBx 'pseg'; BxAx 'rin'; E @(0xD1, 0xE8); Jr 0xEB 'pnset'   # (two entries a tick)
Lbl 'pn3'; E @(0x83, 0xFA, 0x03); Jr 0x75 'pn4'
BxAx 'soff'; AxBx 'poff'; BxAx 'sseg'; AxBx 'pseg'; BxAx 'per'; AxBx 'sub'; BxAx 'ns'; Jr 0xEB 'pnset'
Lbl 'pn4'; E @(0x83, 0xFA, 0x04); Jr 0x75 'pn5'
BxAx 'routo'; AxBx 'poff'; BxAx 'rseg'; AxBx 'pseg'; BxAx 'rout'; E @(0xD1, 0xE8); Jr 0xEB 'pnset'
Lbl 'pn5'                                                                 # the sound over: channel 2 as QB left it
Ch2Qb
CmpBx8 'clk' 0; Jr 0x74 'pn5t'
BxI 'phase' 7; Ch0 0x00 0x08; E @(0xC3)   # in the clock: idling again at 2048
Lbl 'pn5t'; BxAx 'tail'; AxBx 'count'; E @(0xC3)                          # alone: counting on for word 13 ticks
Lbl 'pnset'; AxBx 'count'; E @(0x0B, 0xC0); Jn @(0x0F, 0x84) 'pnext'; E @(0xC3)
# ---- prestore: (interrupts off) channel 0 and the vector back, channel 2 as QB left it, phase 0
Lbl 'prestore'
CmpBx8 'phase' 0; Jr 0x74 'prdone'
E @(0xB0, 0x36, 0xE6, 0x43, 0x32, 0xC0, 0xE6, 0x40)                       # channel 0 mode 3, low byte 0
E @(0xE6, 0x40)                                                          # high byte 0: 65536 again
E @(0x06, 0x33, 0xC0, 0x8E, 0xC0)                                         # push es; es = 0
BxAx 'ooff'; E @(0x26, 0xA3, 0x20, 0x00); BxAx 'oseg'; E @(0x26, 0xA3, 0x22, 0x00)
E @(0x07)                                                                 # pop es
Ch2Qb
BxI 'phase' 0; BxI 'clk' 0
Lbl 'prdone'; E @(0xC3)
# ---- phook: (interrupts off) the old vector kept, the chain rates from its segment, ours in, the count 0
Lbl 'phook'
E @(0x33, 0xC0, 0x8E, 0xC0)                                               # es = 0
E @(0x26, 0xA1, 0x20, 0x00); AxBx 'ooff'; E @(0x26, 0xA1, 0x22, 0x00); AxBx 'oseg'
BxI 'chain' 512                                                          # the vector found runs at the BIOS 65536: its tick every 512 fast ticks
E @(0xB8, $ISR, 0x00); E @(0x03, 0xC3); E @(0x26, 0xA3, 0x20, 0x00)       # our handler: the overlay's offset + 61
E @(0x8C, 0xC8); E @(0x26, 0xA3, 0x22, 0x00)
BxI 'tlo' 0; BxI 'thi' 0
E @(0xC3)
# ---- the entry (CALL ABSOLUTE; bx = the overlay's offset from the stub)
Lbl 'pentry'
E @(0x55); E @(0x8B, 0xEC); E @(0x1E, 0x56, 0x57, 0x53, 0x06); E @(0x83, 0xEC, 0x14)   # push bp ds si di bx es; sub sp,20 (locals bp-12..bp-30)
E @(0x8E, 0x5E, 0x08); E @(0x8B, 0x76, 0x06)                              # ds:si = the block
E @(0x8B, 0x04); E @(0x3D, 0x01, 0x00); Jn @(0x0F, 0x84) 'pcal'           # op 1: calibrate
E @(0x3D, 0x02, 0x00); Jn @(0x0F, 0x84) 'pstop'                           # op 2: stop
E @(0x3D, 0x05, 0x00); Jn @(0x0F, 0x84) 'pclock'                          # op 5: the clock on
E @(0x3D, 0x06, 0x00); Jn @(0x0F, 0x84) 'ptone'                           # op 6: a click
# ---- op 0: a footstep
E @(0x9C, 0xFA)                                                           # pushf; cli
E @(0x8B, 0x44, 0x02); AxBx 'sseg'; E @(0x8B, 0x44, 0x04); AxBx 'soff'; E @(0x8B, 0x44, 0x06); AxBx 'ns'
E @(0x8B, 0x44, 0x0A); AxBx 'per'; E @(0x8B, 0x44, 0x0C); AxBx 'rin'; E @(0x8B, 0x44, 0x0E); AxBx 'rout'
E @(0x8B, 0x44, 0x10); AxBx 'rseg'; E @(0x8B, 0x44, 0x12); AxBx 'rino'; E @(0x8B, 0x44, 0x14); AxBx 'routo'
E @(0x8B, 0x44, 0x16); AxBx 'half'; E @(0x8B, 0x44, 0x1A); AxBx 'tail'
E @(0x8B, 0x44, 0x18); E @(0x0B, 0xC0, 0x75, 0x01, 0x40); AxBx 'count'     # the wait (at least a tick)
CmpBx8 'phase' 0; Jr 0x75 'ps1'; CallN 'phook'; BxI 'clk' 0               # alone: hooked now
Lbl 'ps1'
E @(0xE4, 0x61, 0x0C, 0x03, 0xE6, 0x61)                                   # the speaker on (QB's engine left it on)
Ch0 0x80 0x00                                                             # channel 0: 128 clocks a tick
BxI 'phase' 1
E @(0x9D); JmpN 'pend'                                                    # popf
# ---- op 5: the clock on (nothing if the handler is already in)
Lbl 'pclock'
E @(0x9C, 0xFA)
CmpBx8 'phase' 0; Jr 0x75 'pc1'
CallN 'phook'; BxI 'clk' 1
Ch0 0x00 0x08                                                             # channel 0 at 2048
BxI 'phase' 7
Lbl 'pc1'; E @(0x9D); JmpN 'pend'
# ---- op 2: stop
# ---- op 6: a click in the clock (QB's SOUND would hook the timer over the clock): channel 2 in mode 3 at
# word 4's count for word 3 ticks (phase 8), then as QB left it
Lbl 'ptone'
CmpBx8 'phase' 7; Jn @(0x0F, 0x85) 'pend'
E @(0x8B, 0x4C, 0x08)                                                     # cx = the count
E @(0xB0, 0xB6, 0xE6, 0x43, 0x8A, 0xC1, 0xE6, 0x42, 0x8A, 0xC5, 0xE6, 0x42)   # channel 2 mode 3, the count
E @(0xE4, 0x61, 0x0C, 0x03, 0xE6, 0x61)                                   # the speaker on
E @(0x8B, 0x44, 0x06); AxBx 'count'; BxI 'phase' 8
JmpN 'pend'
Lbl 'pstop'
E @(0x9C, 0xFA); CallN 'prestore'; E @(0x9D); JmpN 'pend'
# ---- op 1: calibrate
Lbl 'pcal'
E @(0x8B, 0x54, 0x08); E @(0x8B, 0x44, 0x06); E @(0x89, 0x46, 0xF2)       # dx = D, [bp-14] = ticks
E @(0xB0, 0x90); E @(0xE6, 0x43)
E @(0xE4, 0x61); E @(0x50); E @(0x24, 0xFC); E @(0x0C, 0x01); E @(0xE6, 0x61)   # the gate on, the speaker's data off
E @(0xFB); E @(0xB8, 0x40, 0x00); E @(0x8E, 0xC0)                         # sti; es = 0040h
E @(0x26, 0x8B, 0x0E, 0x6C, 0x00)
Lbl 'pw'; E @(0x26, 0x3B, 0x0E, 0x6C, 0x00); Jr 0x74 'pw'                 # wait for a tick edge
E @(0x26, 0x8B, 0x3E, 0x6C, 0x00)                                         # di = the start tick
E @(0x33, 0xDB); E @(0x89, 0x5E, 0xF4)                                    # count = 0 (bx low, [bp-12] high)
Lbl 'pc'
E @(0xB0, 0x90); E @(0xE6, 0x43); E @(0xB0, 0x20); E @(0xE6, 0x42)
E @(0x8B, 0xCA); Lbl 'pd2'; Jr 0xE2 'pd2'
E @(0x26, 0x8B, 0x0E, 0x6C, 0x00); E @(0x2B, 0xCF); E @(0x3B, 0x4E, 0xF2); Jr 0x73 'pcd'   # ticks gone >= the wanted: done
E @(0x43); Jr 0x75 'pc'; E @(0xFF, 0x46, 0xF4); Jr 0xEB 'pc'
Lbl 'pcd'
E @(0x89, 0x5C, 0x0C); E @(0x8B, 0x46, 0xF4); E @(0x89, 0x44, 0x0E)       # words 6/7 = the count
E @(0xB0, 0xB6); E @(0xE6, 0x43); E @(0x58); E @(0x24, 0xFC); E @(0xE6, 0x61)
Lbl 'pend'
E @(0x83, 0xC4, 0x14); E @(0x07, 0x5B, 0x5F, 0x5E, 0x1F); E @(0x5D); E @(0xCA, 0x04, 0x00)
$pcm = $script:a.Resolve()
if ($script:a.labels['pisr'] -ne $ISR) { throw "C3DPCM: the handler is at offset $($script:a.labels['pisr']), not $ISR" }
if ($script:a.labels['farj'] -ne 10) { throw "C3DPCM: the far jump is at offset $($script:a.labels['farj']), not 10" }
[System.IO.File]::WriteAllBytes("$srcDir\C3DPCM.OVL", $pcm)
Write-Host "C3DPCM.OVL $($pcm.Length) bytes"
