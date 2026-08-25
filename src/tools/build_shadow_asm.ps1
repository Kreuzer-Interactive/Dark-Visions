# build_shadow_asm.ps1 -- hand-assembled 8086 blitter routines for the
# shadow-door watchers, emitted as .OVL binaries (velocity_2_se-style:
# loaded into QB strings, invoked via DEF SEG + CALL ABSOLUTE + SADD).
#
# QB45 CALL ABSOLUTE convention used here (all params BYVAL WORD):
#   params pushed LEFT to RIGHT, far return address on top -> after
#   push bp / mov bp,sp the LAST param sits at [bp+6], earlier ones above.
#   Routine restores registers and RETF 2*N.
#
# SHADBOP.OVL -- compose a GET-format pixel block into a linear far buffer.
#   CALL ABSOLUTE(BYVAL sseg, BYVAL soff, BYVAL dseg, BYVAL doff,
#                 BYVAL rows, BYVAL rbytes, BYVAL sstride, BYVAL dstride,
#                 BYVAL mode, SADD(r$))
#   mode: 0 = copy, 1 = AND, 2 = OR.   (9 params -> RETF 18)
#   [bp+6]=mode [bp+8]=dstride [bp+10]=sstride [bp+12]=rbytes [bp+14]=rows
#   [bp+16]=doff [bp+18]=dseg [bp+20]=soff [bp+22]=sseg
#
# SHADBLT.OVL -- copy a linear buffer rect to CGA B800 interleaved memory.
#   CALL ABSOLUTE(BYVAL sseg, BYVAL soff, BYVAL dxbyte, BYVAL dy,
#                 BYVAL rows, BYVAL rbytes, BYVAL sstride, BYVAL vs,
#                 SADD(r$))
#   dxbyte = destination column IN BYTES (x\4), dy = destination row;
#   vs<>0 waits for vertical retrace start first. (8 params -> RETF 16)
#   [bp+6]=vs [bp+8]=sstride [bp+10]=rbytes [bp+12]=rows [bp+14]=dy
#   [bp+16]=dxbyte [bp+18]=soff [bp+20]=sseg
$ErrorActionPreference = 'Stop'

# ---- tiny two-pass assembler: literal bytes + resolvable rel8 jumps --------
class Asm {
  [System.Collections.Generic.List[object]]$items = @()
  [hashtable]$labels = @{}
  [void]B([byte[]]$b) { foreach ($x in $b) { $this.items.Add([int]$x) } }
  [void]L([string]$name) { $this.labels[$name] = -1; $this.items.Add(@('label', $name)) }
  [void]J([byte]$opcode, [string]$target) { $this.items.Add(@('jmp', $opcode, $target)) }  # rel8
  [byte[]]Resolve() {
    # pass 1: addresses (labels 0 bytes, rel8 jumps 2 bytes)
    $addr = 0
    foreach ($it in $this.items) {
      if ($it -is [array]) {
        if ($it[0] -eq 'label') { $this.labels[$it[1]] = $addr } else { $addr += 2 }
      } else { $addr++ }
    }
    # pass 2: emit
    $out = New-Object System.Collections.Generic.List[byte]
    $addr = 0
    foreach ($it in $this.items) {
      if ($it -is [array]) {
        if ($it[0] -eq 'label') { continue }
        $rel = $this.labels[$it[2]] - ($addr + 2)
        if ($rel -lt -128 -or $rel -gt 127) { throw "rel8 out of range to $($it[2])" }
        $out.Add([byte]$it[1]); $out.Add([byte](($rel + 256) % 256)); $addr += 2
      } else { $out.Add([byte]$it); $addr++ }
    }
    return $out.ToArray()
  }
}

# ---- SHADBOP ----------------------------------------------------------------
$a = [Asm]::new()
$a.B(0x55)                #         push bp
$a.B(@(0x8B,0xEC))        #         mov bp,sp
$a.B(0x1E); $a.B(0x56); $a.B(0x57); $a.B(0x06)   # push ds/si/di/es
$a.B(@(0x8B,0x46,0x16))   #         mov ax,[bp+22]  sseg
$a.B(@(0x8E,0xD8))        #         mov ds,ax
$a.B(@(0x8B,0x76,0x14))   #         mov si,[bp+20]  soff
$a.B(@(0x8B,0x46,0x12))   #         mov ax,[bp+18]  dseg
$a.B(@(0x8E,0xC0))        #         mov es,ax
$a.B(@(0x8B,0x7E,0x10))   #         mov di,[bp+16]  doff
$a.B(@(0x8B,0x56,0x0E))   #         mov dx,[bp+14]  rows
$a.L('rowloop')
$a.B(@(0x8B,0x4E,0x0C))   #         mov cx,[bp+12]  rbytes
$a.B(@(0xE3,0x00))        #         jcxz -> patched below? (jcxz rel8=E3) -- use resolver:
# (replace the two bytes just added with a resolvable jump)
$a.items.RemoveAt($a.items.Count-1); $a.items.RemoveAt($a.items.Count-1)
$a.J(0xE3,'rowadv')       #         jcxz rowadv     (defensive: 0-byte rows)
$a.B(@(0x8A,0x46,0x06))   #         mov al,[bp+6]   mode
$a.B(@(0x3C,0x01))        #         cmp al,1
$a.J(0x74,'andmode')      #         jz andmode
$a.B(@(0x3C,0x02))        #         cmp al,2
$a.J(0x74,'ormode')       #         jz ormode
$a.B(@(0xD1,0xE9))        #         shr cx,1        copy mode: words then odd byte
$a.B(@(0xF3,0xA5))        #         rep movsw
$a.J(0x73,'cnoodd')       #         jnc cnoodd
$a.B(0xA4)                #         movsb
$a.L('cnoodd')
$a.J(0xEB,'rowadv')       #         jmp rowadv
$a.L('andmode')
$a.L('andloop')
$a.B(0xAC)                #         lodsb
$a.B(@(0x26,0x20,0x05))   #         and es:[di],al
$a.B(0x47)                #         inc di
$a.J(0xE2,'andloop')      #         loop andloop
$a.J(0xEB,'rowadv')       #         jmp rowadv
$a.L('ormode')
$a.L('orloop')
$a.B(0xAC)                #         lodsb
$a.B(@(0x26,0x08,0x05))   #         or es:[di],al
$a.B(0x47)                #         inc di
$a.J(0xE2,'orloop')       #         loop orloop
$a.L('rowadv')
$a.B(@(0x8B,0x46,0x0A))   #         mov ax,[bp+10]  sstride
$a.B(@(0x2B,0x46,0x0C))   #         sub ax,[bp+12]  -rbytes
$a.B(@(0x01,0xC6))        #         add si,ax
$a.B(@(0x8B,0x46,0x08))   #         mov ax,[bp+8]   dstride
$a.B(@(0x2B,0x46,0x0C))   #         sub ax,[bp+12]
$a.B(@(0x01,0xC7))        #         add di,ax
$a.B(0x4A)                #         dec dx
$a.J(0x75,'rowloop')      #         jnz rowloop
$a.B(0x07); $a.B(0x5F); $a.B(0x5E); $a.B(0x1F)   # pop es/di/si/ds
$a.B(0x5D)                #         pop bp
$a.B(@(0xCA,0x12,0x00))   #         retf 18
$bop = $a.Resolve()

# ---- SHADBLT ----------------------------------------------------------------
$b = [Asm]::new()
$b.B(0x55); $b.B(@(0x8B,0xEC))
$b.B(0x1E); $b.B(0x56); $b.B(0x57); $b.B(0x06)
$b.B(@(0x8B,0x46,0x06))   #         mov ax,[bp+6]   vs
$b.B(@(0x09,0xC0))        #         or ax,ax
$b.J(0x74,'novs')         #         jz novs
$b.B(@(0xBA,0xDA,0x03))   #         mov dx,03DAh
$b.L('vs1')               #         wait while IN retrace
$b.B(0xEC)                #         in al,dx
$b.B(@(0xA8,0x08))        #         test al,8
$b.J(0x75,'vs1')          #         jnz vs1
$b.L('vs2')               #         wait for retrace START
$b.B(0xEC)                #         in al,dx
$b.B(@(0xA8,0x08))        #         test al,8
$b.J(0x74,'vs2')          #         jz vs2
$b.L('novs')
$b.B(@(0xB8,0x00,0xB8))   #         mov ax,0B800h
$b.B(@(0x8E,0xC0))        #         mov es,ax
$b.B(@(0x8B,0x46,0x14))   #         mov ax,[bp+20]  sseg
$b.B(@(0x8B,0x76,0x12))   #         mov si,[bp+18]  soff
$b.B(@(0x8E,0xD8))        #         mov ds,ax
$b.B(@(0x8B,0x5E,0x0E))   #         mov bx,[bp+14]  dy
$b.B(@(0x8B,0x56,0x0C))   #         mov dx,[bp+12]  rows
$b.L('blrow')
$b.B(@(0x8B,0xC3))        #         mov ax,bx       y
$b.B(@(0xD1,0xE8))        #         shr ax,1        y\2
$b.B(@(0x8B,0xF8))        #         mov di,ax
$b.B(@(0xD1,0xE7))        #         shl di,1
$b.B(@(0xD1,0xE7))        #         shl di,1
$b.B(@(0xD1,0xE7))        #         shl di,1
$b.B(@(0xD1,0xE7))        #         shl di,1        di=(y\2)*16
$b.B(@(0x8B,0xC7))        #         mov ax,di
$b.B(@(0xD1,0xE0))        #         shl ax,1
$b.B(@(0xD1,0xE0))        #         shl ax,1        ax=(y\2)*64
$b.B(@(0x03,0xF8))        #         add di,ax       di=(y\2)*80
$b.B(@(0xF7,0xC3,0x01,0x00)) #      test bx,1
$b.J(0x74,'bleven')       #         jz bleven
$b.B(@(0x81,0xC7,0x00,0x20)) #      add di,2000h
$b.L('bleven')
$b.B(@(0x03,0x7E,0x10))   #         add di,[bp+16]  dxbyte
$b.B(@(0x8B,0x4E,0x0A))   #         mov cx,[bp+10]  rbytes
$b.B(@(0xD1,0xE9))        #         shr cx,1
$b.B(@(0xF3,0xA5))        #         rep movsw
$b.J(0x73,'bnoodd')       #         jnc bnoodd
$b.B(0xA4)                #         movsb
$b.L('bnoodd')
$b.B(@(0x8B,0x46,0x08))   #         mov ax,[bp+8]   sstride
$b.B(@(0x2B,0x46,0x0A))   #         sub ax,[bp+10]
$b.B(@(0x01,0xC6))        #         add si,ax
$b.B(0x43)                #         inc bx
$b.B(0x4A)                #         dec dx
$b.J(0x75,'blrow')        #         jnz blrow
$b.B(0x07); $b.B(0x5F); $b.B(0x5E); $b.B(0x1F); $b.B(0x5D)
$b.B(@(0xCA,0x10,0x00))   #         retf 16
$blt = $b.Resolve()

$srcDir = "$PSScriptRoot\.."
[System.IO.File]::WriteAllBytes("$srcDir\SHADBOP.OVL", $bop)
[System.IO.File]::WriteAllBytes("$srcDir\SHADBLT.OVL", $blt)
Write-Host "SHADBOP.OVL $($bop.Length) bytes; SHADBLT.OVL $($blt.Length) bytes"
Write-Host ("bop: " + (($bop | ForEach-Object { $_.ToString('X2') }) -join ' '))
Write-Host ("blt: " + (($blt | ForEach-Object { $_.ToString('X2') }) -join ' '))
