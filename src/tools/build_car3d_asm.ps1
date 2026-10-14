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
#   A face is drawn when (x1-x0)*(y2-y0)-(x2-x0)*(y1-y0) > 0 (screen y down,
#   converter's outward winding). Texel index 255 = transparent.
#
# C3DPRJ.OVL  -- CALL ABSOLUTE(BYVAL qseg, BYVAL qoff, SADD(prj$))     (RETF 4)
#   block (21 INTEGERs): 0/1 rx seg/off  2/3 ry  4/5 rz  6/7 sx  8/9 sy  10 n
#   11/12 px lo/hi  13/14 py  15/16 pz (LONG, x16 units)  17..20 out: minx maxx miny maxy
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

# one blob per texture size: $tsh = log2(texture width), 6 = 64 texels, 7 = 128
function Build-Tri([int]$tsh) {
$tmask = [byte]((1 -shl $tsh) - 1)
$script:a = [Asm]::new()
E @(0x55); E @(0x8B, 0xEC); E @(0x81, 0xEC, 0x80, 0x00)      # push bp; mov bp,sp; sub sp,128
E @(0x1E, 0x56, 0x57, 0x06)                                    # push ds,si,di,es
MovDsM 8; MovRM 'si' 6                                         # ds:si = pseg:poff
E @(0x8C, 0xD0); E @(0x8E, 0xC0)                               # mov ax,ss; mov es,ax
LeaDI (P 0); E @(0xB9, 0x18, 0x00); E @(0xF3, 0xA5)            # lea di,[bp-128]; mov cx,24; rep movsw
MovMI (P 22) 0                                                 # drawn = 0
MovMI $ORDI 0
Lbl 'outer'
MovRM 'ax' $ORDI; CmpRM 'ax' (P 19); Jn @(0x0F, 0x8D) 'done'  # jge done
MovDsM (P 17); MovRM 'si' (P 18); E @(0xD1, 0xE0); E @(0x03, 0xF0)   # ds:si = ord + i*2
E @(0x8B, 0x1C)                                                # mov bx,[si]  (face f)
MovDsM (P 15); MovRM 'si' (P 16); E @(0x8B, 0xC3); E @(0xD1, 0xE0); E @(0x03, 0xF0)   # band[f]
E @(0x8B, 0x04); E @(0xD1, 0xE0)                               # mov ax,[si]; shl ax,1
MovDsM (P 4); MovRM 'si' (P 23); E @(0x03, 0xF0); E @(0x8B, 0x04)   # band segment table [P4:P23]
MovMR $TSEG 'ax'                                               # tseg for this face
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
CallN 'TRI'
# quad: d >= 0 -> triangle (a,c,d)
MovDsM (P 13); MovRM 'si' $FOFF; E @(0x8B, 0x44, 0x06); E @(0x0B, 0xC0); Jr 0x78 'nextpoly'   # js
foreach ($pair in @(@(0, $X0), @(4, $X1), @(6, $X2))) {
  MovDsM (P 13); MovRM 'si' $FOFF
  if ($pair[0] -eq 0) { E @(0x8B, 0x04) } else { E @(0x8B, 0x44, [byte]$pair[0]) }
  E (@(0xBF) + (W16 $pair[1])); CallN 'LDV'
}
CallN 'TRI'
Lbl 'nextpoly'
IncM $ORDI; JmpN 'outer'
Lbl 'done'
# write back: word 22 = faces drawn; words 24..63 = the rasteriser locals [bp-80..bp-1] (debug)
MovEsM 8; MovRM 'di' 6
MovRM 'ax' (P 22); E @(0x26, 0x89, 0x45, 0x2C)                  # mov es:[di+44],ax
E @(0x83, 0xC7, 0x30); E @(0x8C, 0xD0); E @(0x8E, 0xD8); LeaSI -80; E @(0xB9, 0x28, 0x00); E @(0xF3, 0xA5)
E @(0x07, 0x5F, 0x5E, 0x1F); E @(0x8B, 0xE5); E @(0x5D); E @(0xCA, 0x04, 0x00)   # pops; mov sp,bp; pop bp; retf 4

# ---- LDV: ax = vertex index, di = slot offset (bp-relative) --------------------
Lbl 'LDV'
E @(0xD1, 0xE0); E @(0x8B, 0xC8)                               # shl ax,1; mov cx,ax
MovDsM (P 5);  E @(0x8B, 0xF1); AddRM 'si' (P 6);  E @(0x8B, 0x04); SubRM 'ax' (P 20); E @(0x89, 0x03)         # x = sx-dx -> [bp+di]
MovDsM (P 7);  E @(0x8B, 0xF1); AddRM 'si' (P 8);  E @(0x8B, 0x04); SubRM 'ax' (P 21); E @(0x89, 0x43, 0x02)   # y = sy-dy
MovDsM (P 9);  E @(0x8B, 0xF1); AddRM 'si' (P 10); E @(0x8B, 0x04); E @(0x89, 0x43, 0x04)                      # u
MovDsM (P 11); E @(0x8B, 0xF1); AddRM 'si' (P 12); E @(0x8B, 0x04); E @(0x89, 0x43, 0x06)                      # v
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
MovRM 'ax' $U1; SubRM 'ax' $U0; MovMR $DU1 'ax'
MovRM 'ax' $U2; SubRM 'ax' $U0; MovMR $DU2 'ax'
MovRM 'ax' $V1; SubRM 'ax' $V0; MovMR $DV1 'ax'
MovRM 'ax' $V2; SubRM 'ax' $V0; MovMR $DV2 'ax'
Cross32 $DX1 $DY2 $DX2 $DY1; Mov32MR $DET 'ax'
E @(0x66, 0x0B, 0xC0); Jr 0x75 't2'; E @(0xC3); Lbl 't2'                            # det == 0 -> ret
# gradients per pixel (8.8): the numerators are in texel*(1/16 px) and det in (1/16 px)^2,
# so the quotient is 1/16 of the per-pixel value: scale the numerator by 16 first
Cross32 $DU1 $DY2 $DU2 $DY1; E @(0x66, 0xC1, 0xE0, 0x04); E @(0x66, 0x99); Idiv32M $DET; MovMR $DUDX 'ax'
Cross32 $DV1 $DY2 $DV2 $DY1; E @(0x66, 0xC1, 0xE0, 0x04); E @(0x66, 0x99); Idiv32M $DET; MovMR $DVDX 'ax'
Cross32 $DU2 $DX1 $DU1 $DX2; E @(0x66, 0xC1, 0xE0, 0x04); E @(0x66, 0x99); Idiv32M $DET; MovMR $DUDY 'ax'
Cross32 $DV2 $DX1 $DV1 $DX2; E @(0x66, 0xC1, 0xE0, 0x04); E @(0x66, 0x99); Idiv32M $DET; MovMR $DVDY 'ax'
Mov32RM 'ax' $DET; E @(0x66, 0x0B, 0xC0); MovMI $LLEFT 1; Jr 0x7F 'lf'; MovMI $LLEFT 0; Lbl 'lf'
# rows: a row cy is covered when its centre (cy*16+8) lies in [y0, y2); first row = (y0+7)>>4
MovRM 'ax' $Y0; E @(0x05, 0x07, 0x00); E @(0xC1, 0xF8, 0x04); MovMR $CY 'ax'       # cy0
MovRM 'ax' $Y1; E @(0x05, 0x07, 0x00); E @(0xC1, 0xF8, 0x04); MovMR $YEND 'ax'     # cy1
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

# ---- SPANS: scanlines CY..YEND-1 --------------------------------------------------
Lbl 'SPANS'
MovRM 'ax' $CY; CmpRM 'ax' $YEND; Jr 0x7C 'sp0'; E @(0xC3); Lbl 'sp0'
Lbl 'sploop'
MovRM 'ax' ($XACCL + 2); MovRM 'cx' ($XACCS + 2)                 # integer parts
CmpMI8 $LLEFT 0; Jr 0x75 'l1'; E @(0x91); Lbl 'l1'               # long on right -> swap
E @(0x2B, 0xC8); Jn @(0x0F, 0x8E) 'spnext'                        # cx = xr-xl; jle spnext
MovMR $TMP 'ax'; E @(0x8B, 0xF1)                                  # xl; si = count
MovRM 'ax' $CY; ImulM16 (P 2); AddRM 'ax' (P 1); AddRM 'ax' $TMP; E @(0x8B, 0xF8)   # di = doff + y*w + xl
# texel start at the first pixel's centre: u = u0 + (dudx*(xl*16+8-x0) + dudy*(cy*16+8-y0))/16
MovRM 'ax' $TMP; E @(0xC1, 0xE0, 0x04); E @(0x05, 0x08, 0x00); SubRM 'ax' $X0; MovMR $TMP 'ax'   # TMP = dx16
MovRM 'ax' $CY; E @(0xC1, 0xE0, 0x04); E @(0x05, 0x08, 0x00); SubRM 'ax' $Y0; E @(0x8B, 0xD8)     # bx = dy16
Movsx32RM 'cx' $TMP; E @(0x66, 0x0F, 0xBF, 0xD3)                                                   # ecx = dx16, edx = dy16
Movsx32RM 'ax' $DUDX; E @(0x66, 0x0F, 0xAF, 0xC1); E @(0x66, 0x50)                                 # push dudx*dx16
Movsx32RM 'bx' $DUDY; E @(0x66, 0x0F, 0xAF, 0xDA); E @(0x66, 0x58); E @(0x66, 0x03, 0xC3)          # + dudy*dy16
E @(0x66, 0xC1, 0xF8, 0x04); AddRM 'ax' $U0; E @(0x50)                                             # push u
Movsx32RM 'ax' $DVDX; E @(0x66, 0x0F, 0xAF, 0xC1); E @(0x66, 0x50)
Movsx32RM 'bx' $DVDY; E @(0x66, 0x0F, 0xAF, 0xDA); E @(0x66, 0x58); E @(0x66, 0x03, 0xC3)
E @(0x66, 0xC1, 0xF8, 0x04); AddRM 'ax' $V0; E @(0x8B, 0xD0)                                       # dx = v
E @(0x5B); E @(0x8B, 0xCE)                                        # pop bx (u); cx = count
MovEsM (P 0); MovDsM $TSEG
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
MovDsM 8; MovRM 'si' 6; E @(0x8C, 0xD0); E @(0x8E, 0xC0); LeaDI (Q 0); E @(0xB9, 0x15, 0x00); E @(0xF3, 0xA5)
MovMI (Q 17) 32767; MovMI (Q 18) -32768; MovMI (Q 19) 32767; MovMI (Q 20) -32768
MovMI -4 0
Lbl 'ploop'
MovRM 'ax' -4; CmpRM 'ax' (Q 10); Jn @(0x0F, 0x8D) 'pdone'
E @(0xD1, 0xE0); MovMR -6 'ax'                                   # [bp-6] = i*2
MovDsM (Q 4); MovRM 'si' -6; AddRM 'si' (Q 5); E @(0x66, 0x0F, 0xBF, 0x04); Add32RM 'ax' (Q 15)   # eax = rz+pz
E @(0x66, 0x83, 0xF8, 0x10); Jr 0x7D 'z1'; E @(0x66, 0xB8, 0x10, 0x00, 0x00, 0x00); Lbl 'z1'      # min 16
E @(0x66, 0x8B, 0xC8)                                            # ecx = zz
MovDsM (Q 0); MovRM 'si' -6; AddRM 'si' (Q 1); E @(0x66, 0x0F, 0xBF, 0x04); Add32RM 'ax' (Q 11)
E @(0x66, 0xC1, 0xE0, 0x0C); E @(0x66, 0x99); E @(0x66, 0xF7, 0xF9); E @(0x05, 0x00, 0x0A)       # ax = (160 + 256x/z) * 16
MovDsM (Q 6); MovRM 'si' -6; AddRM 'si' (Q 7); E @(0x89, 0x04)
CmpRM 'ax' (Q 17); Jr 0x7D 'm1'; MovMR (Q 17) 'ax'; Lbl 'm1'
CmpRM 'ax' (Q 18); Jr 0x7E 'm2'; MovMR (Q 18) 'ax'; Lbl 'm2'
MovDsM (Q 2); MovRM 'si' -6; AddRM 'si' (Q 3); E @(0x66, 0x0F, 0xBF, 0x04); Add32RM 'ax' (Q 13)
E @(0x66, 0xC1, 0xE0, 0x0C); E @(0x66, 0x99); E @(0x66, 0xF7, 0xF9)
E @(0x8B, 0xC8); E @(0xB8, 0x40, 0x06); E @(0x2B, 0xC1)          # ax = (100 - 256y/z) * 16
MovDsM (Q 8); MovRM 'si' -6; AddRM 'si' (Q 9); E @(0x89, 0x04)
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
[System.IO.File]::WriteAllBytes("$srcDir\C3DBLTM.OVL", $bltm)
[System.IO.File]::WriteAllBytes("$srcDir\C3DPRJ.OVL", $prj)
[System.IO.File]::WriteAllBytes("$srcDir\C3DTEST.OVL", $tst)
Write-Host "C3DTRI.OVL $($tri.Length) bytes; C3DPRJ.OVL $($prj.Length) bytes; C3DEDGE.OVL $($edge.Length) bytes; C3DBLTM.OVL $($bltm.Length) bytes; C3DTEST.OVL $($tst.Length) bytes"
