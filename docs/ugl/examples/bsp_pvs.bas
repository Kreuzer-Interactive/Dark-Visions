''
'' Crappy renderer
''
defint a-z
'$include: '..\inc\u3d.bi'
'$include: '..\inc\ugl.bi'
'$include: '..\inc\kbd.bi'
'$include: '..\inc\tmr.bi'
'$include: '..\inc\dos.bi'
'$include: '..\inc\arch.bi'
'$include: '..\inc\uglu.bi'
'$include: '..\inc\font.bi'
'$include: '..\inc\mouse.bi'
'$include: 'bsp_pvs.bi'
'$include: '..\inc\snd.bi'
'$include: '..\inc\mod.bi'


declare sub getSBSettings  ( port as integer, irq as integer, _
                             ldma as integer, hdma as integer )

dim shared mymod as UGMMOD


dim shared env as EnvType
dim shared hTextrDC( 256*4 ) as long
dim shared frustum(5) as plane
dim shared culLeafs as integer
dim shared drwLeafs as integer
dim shared visCount as long
dim shared texCount as long
dim shared bsphead as header
dim shared triCount as long
dim shared vtxCount as long
dim shared edgCount as long
dim shared ledgCount as long
dim shared lefCount as long
dim shared lfcCount as long
dim shared plnCount as long
dim shared ndsCount as long
dim shared mdlCount as long
dim shared ordCount as long
dim shared clpCount as long
dim shared camUp as u3dVector3f    
dim shared CamPos as u3dVector3f    
dim shared camLookAt as u3dVector3f
dim shared bitarray(15) as integer
dim shared hFontChar(255) as long
dim shared startAngle as single

'$dynamic
dim shared triBuffer( 1 ) as face2
dim shared edgBuffer( 1 ) as edge
dim shared ledgBuffer( 1 ) as integer
dim shared vtxBuffer( 1 ) as vertex
dim shared txcBuffer( 1 ) as uv
dim shared lefBuffer( 1 ) as leaf2
dim shared lfcBuffer( 1 ) as integer
dim shared mdlBuffer( 1 ) as model
dim shared plnBuffer( 1 ) as plane2
dim shared ndsBuffer( 1 ) as nodeb
dim shared orderList( 1 ) as integer
dim shared pvsBufferA( 1 ) as integer
dim shared pvsBufferB( 1 ) as integer
dim shared texInfBuff( 1 ) as texinfo
dim shared mipBuffInf( 1 ) as miptexb
dim shared clpBuffer( 1 ) as clipnode
dim shared polyFlag( 1 ) as integer
dim shared lightmap as long





'$static

    ''
    '' Grr, qb suxs
    '' 
    on errror goto HandleErr
    
        
    '':::::
    
    doInit 
    doMain   
    doEnd
    
    
HandleErr:    
    ExitError "0x1000, Unknown runtime error..."


'' :::::::::::::
'' name: drwLoadingBar
'' desc: Draws a loading bar
''
'' :::::::::::::
defint a-z
sub drwLoadingBar ( hDC as long, x as integer, y as integer, wdt as integer, _
                    hgt as integer, percent as single, col as long )
    dim drwWidth as integer
    
    if ( percent < 0   ) then percent = 0
    if ( percent > 100 ) then percent = 100
    
    drwWidth = (wdt * percent) / 100.0    
    uglRect  hDC, x-2, y-2, x+wdt+2, y+hgt+2, col
    uglRectF hDC, x, y, x+drwWidth, y+hgt, col  
    
end sub



''::::
defint a-z
sub doInit
    dim i as integer
    dim nRet as integer
    dim tmpStr as string
    dim bsphead as header
    dim texoffs(256) as long
    dim tex as miptex
    dim file as UAR
    
    dim loading as single
    dim loadmod as UGMMOD    
    dim port as integer, irq as integer
    dim ldma as integer, hdma as integer
    
    dim hVideoDC as long
    
    
    ''
    '' Check if files exists
    '' 
    if ( rtrim$(ltrim$( command$ )) = "" ) then
        print "Usage: bsp_pvs mapname.bsp"
        print "Copyleft Blitz, july/2003"
        doEnd
    end if
    
    if ( (dir$( command$ ) = "") ) then
        print "File " + lcase$(command$) + " could not be found"
        doEnd
    end if
    
    if ( (dir$( "stuff.ini" ) = "") ) then
        print "Ini file could not be found"
        doEnd
    end if    
        

    
    ''
    '' Init vars
    ''       
    parseIni "stuff.ini"    
    
    for  i = 0 to 15
        bitarray(i) = clng(2^i)
    next i    


    ''
    '' Init UGL
    '' 
    if ( uglInit() = FALSE ) then 
        ExitError "0x0000, Could not init UGL..."
    end if
    
    ''
    '' Try to autodetect (sb16 only), if that doesn't work
    '' we will try to get the sb settings from the BLASTER
    '' variable. If that doesn't work either there either
    '' isn't a sound blaster or the user needs to set it up.
    ''
    if ( env.sound = true ) then
        if ( sndInit( false, false, false, false ) = false ) then
            
            getSBSettings port, irq, ldma, hdma
            if ( (port = false) or (irq = false) or (ldma = false ) ) then
                ExitError "0x0001, No sound blaster or compatible detected..."
            end if
          
            if ( sndInit( port, irq, ldma, hdma ) = false ) then
                ExitError "0x0002, Could not init sound module..."
            end if
            
        end if
        
        ''
        '' Try to open sound output with a update rate of
        '' 50 times per second.
        ''
        '' SB 1.0 - 2.0:    8 bit, mono, 4000Hz-23000Hz
        '' SB 2.01:         8 bit, mono, 4000Hz-44100Hz
        '' SB Pro:          8 bit, mono, 4000Hz-44100Hz
        ''                  8 bit, stereo, 11025Hz-22050Hz
        '' SB 16:           8/16 bit, mono/stereo, 5000Hz-44100Hz
        ''        
        if ( sndOpenOutput( snd.s16.stereo, 44100, 50 ) = false ) then
            if ( sndOpenOutput( snd.s8.stereo, 22050, 50 ) = false ) then
                if ( sndOpenOutput( snd.s8.mono, 22050, 50 ) = false ) then
                    ExitError "0x1003, Could not open sound output..."
                end if
            end if        
        end if
        
        ''
        '' Init mod module
        ''
        if ( modInit = false ) then
            ExitError "0x1004, Could not init mod module..."
        end if
        
        ''
        '' Load mod
        ''    
        if ( modNew( loadmod, mod.ems, "base.dat::mods/flim.mod" ) = false ) then
            ExitError "0x1005, Could not load mod..."
        end if
            
        if ( modNew( mymod, mod.ems, "base.dat::mods/mainfrm.mod" ) = false ) then
            ExitError "0x1005, Could not load mod..."
        end if
        
       
        ''
        '' Loading music
        ''
        modPlay loadmod
    end if
    
    ''
    '' Font
    ''
    if ( not initFont( "base.dat::font/4x6.fnt", 254 ) ) then
        ExitError "0x0000, Could not load font..."
    end if    
    
    
    
              
    
    ''
    '' Load geometry    
    ''    
    open command$ for binary as #1 
    
    dim vtx as vertex   
    dim fce as face
    dim nodetmp as node
    dim leaftmp as leaf
    dim planetmp as plane
    
    get #1,, bsphead
    
    triCount = bsphead.faces.size \ len( fce )
    vtxCount = bsphead.vertices.size \ len( vtxBuffer(0) )
    edgCount = bsphead.edges.size \ len( edgBuffer(0) )
    ledgCount = bsphead.ledges.size \ 4
    lefCount = bsphead.leaves.size \ len( leaftmp )
    lfcCount = bsphead.lface.size \ len( lfcBuffer(0) )
    plnCount = bsphead.planes.size \ len( planetmp )
    ndsCount = bsphead.nodes.size \ len( nodetmp )
    mdlCount = bsphead.models.size \ len( mdlBuffer(0) )
    visCount = bsphead.vislist.size
    texiCount = bsphead.texinfo.size \ len( texInfBuff(0) )
    clpCount = bsphead.clipnode.size \ len( clpBuffer(0) )
    seek #1, bsphead.miptex.offs+1
    get #1,, numtex&    
    texCount = numtex&

    ''
    '' Set mode 13h for loading
    ''    
    hVideoDC = uglSetVideoDC( UGL.8BIT, 320, 200, 1 )
    if ( hVideoDC = false ) then
        ExitError "0x3001, Could not set loading video mode"
    end if
    
    drwLoadingBar hVideoDC, (320-150)\2, (200-20)\2, 150, 20, loading, -1    


    
    ''
    '' Find start position entity
    ''  
    entity$ = space$( bsphead.entities.size )
    seek #1, bsphead.entities.offs+1
    get #1,, entity$
    
    dim strm(50) as string
    dim strm_cnt as integer

    for  i = 1 to len( entity$ )    
        char$ = mid$( entity$, i, 1 )

        if char$ = "{" then 
            new = 1
            fchar = i
        end if
            
        if char$ = "}" then 
            if new = 1 then
                class$ = mid$( entity$, fchar, i-fchar+1 )
                
                if instr( class$, "info_player_start" ) then
                    strtok strm(), strm_cnt, " {}"+chr$(34)+chr$(10)+chr$(13), class$
                    
                    for j = 0 to strm_cnt-1
                        if strm(j) = "origin" then
                            camPos.x = val(strm(j+1))
                            camPos.z = val(strm(j+2))
                            camPos.y = val(strm(j+3))
                        end if
                        
                        if strm(j) = "angle" then
                            startAngle = val(strm(j+1))                            
                        end if                        
                    next j
                end if
            end if
        end if    
    next i
    
    loading = loading + 100.0/14.0
    drwLoadingBar hVideoDC, (320-150)\2, (200-20)\2, 150, 20, loading, -1    

    
    ''
    '' Allocate memory for level data
    ''    
    redim triBuffer(triCount-1) as face2
    redim edgBuffer(edgCount-1) as edge    
    redim ledgBuffer(ledgCount-1) as integer
    redim vtxBuffer(vtxCount-1) as vertex
    redim txcBuffer(vtxCount-1) as uv
    redim lefBuffer(lefCount-1) as leaf2
    redim lfcBuffer(lfcCount-1) as integer
    redim plnBuffer(plnCount-1) as plane2
    redim ndsBuffer(ndsCount-1) as nodeb
    redim mdlBuffer(mdlCount-1) as model
    redim orderList(ndsCount-1) as integer
    redim pvsBufferA( (bsphead.vislist.size+1)\2 ) as integer
    redim pvsBufferB( 4096 ) as integer
    redim polyFlag( 4096 ) as integer
    redim texInfBuff(texiCount-1) as texinfo
    
    
    ''
    '' Load vertices
    ''
    seek #1, bsphead.vertices.offs+1
    for  i = 0 to vtxCount-1
        get #1,, vtxBuffer(i)
        loading = loading + ((100.0/14.0)/vtxCount)
        drwLoadingBar hVideoDC, (320-150)\2, (200-20)\2, 150, 20, loading, -1
    next i

    ''
    '' Load polygons
    ''    
    seek #1, bsphead.faces.offs+1
    for  i = 0 to triCount-1
        get #1,, fce
        triBuffer(i).planeid = fce.planeid
        triBuffer(i).side = fce.side
        triBuffer(i).ledgeid = fce.ledgeid
        triBuffer(i).ledgenum = fce.ledgenum
        triBuffer(i).texinfoid = fce.texinfoid
        triBuffer(i).lightmap = fce.lightmap
        loading = loading + ((100.0/14.0)/triCount)
        drwLoadingBar hVideoDC, (320-150)\2, (200-20)\2, 150, 20, loading, -1        
    next i    

    ''
    '' Load Edges
    ''    
    seek #1, bsphead.edges.offs+1
    for  i = 0 to edgCount-1
        get #1,, edgBuffer(i)
        loading = loading + ((100.0/14.0)/edgCount)
        drwLoadingBar hVideoDC, (320-150)\2, (200-20)\2, 150, 20, loading, -1
    next i        
    
    ''
    '' Load edge indexes
    ''    
    seek #1, bsphead.ledges.offs+1
    for  i = 0 to ledgCount-1
        get #1,, tmp&
        ledgBuffer(i) = tmp&
        loading = loading + ((100.0/14.0)/ledgCount)
        drwLoadingBar hVideoDC, (320-150)\2, (200-20)\2, 150, 20, loading, -1
    next i    
    
    ''
    '' Load BSP Leaves
    ''    
    seek #1, bsphead.leaves.offs+1
    for  i = 0 to lefCount-1        
        get #1,, leaftmp
        lefBuffer(i).vislist = leaftmp.vislist
        swap lefBuffer(i).bound, leaftmp.bound
        lefBuffer(i).lfaceid = leaftmp.lfaceid
        lefBuffer(i).lfacenum = leaftmp.lfacenum
        loading = loading + ((100.0/14.0)/lefCount)
        drwLoadingBar hVideoDC, (320-150)\2, (200-20)\2, 150, 20, loading, -1        
    next i        

    ''
    '' Load polygons indexes
    ''    
    seek #1, bsphead.lface.offs+1
    for  i = 0 to lfcCount-1
        get #1,, lfcBuffer(i)
        loading = loading + ((100.0/14.0)/lfcCount)
        drwLoadingBar hVideoDC, (320-150)\2, (200-20)\2, 150, 20, loading, -1
    next i                
    
    ''
    '' Load nodes
    ''    
    seek #1, bsphead.nodes.offs+1
    for  i = 0 to ndsCount-1
        get #1,, nodetmp
        ndsBuffer(i).planeid = nodetmp.planeid
        ndsBuffer(i).child0  = nodetmp.child0
        ndsBuffer(i).child1  = nodetmp.child1
        ndsBuffer(i).lfaceid = nodetmp.lfaceid
        ndsBuffer(i).lfacenum = nodetmp.lfacenum
        
        ndsBuffer(i).bound.min.x = nodetmp.bound.min.x
        ndsBuffer(i).bound.min.y = nodetmp.bound.min.y
        ndsBuffer(i).bound.min.z = nodetmp.bound.min.z
        ndsBuffer(i).bound.max.x = nodetmp.bound.max.x
        ndsBuffer(i).bound.max.y = nodetmp.bound.max.y
        ndsBuffer(i).bound.max.z = nodetmp.bound.max.z
        
        loading = loading + ((100.0/14.0)/ndsCount)
        drwLoadingBar hVideoDC, (320-150)\2, (200-20)\2, 150, 20, loading, -1
    next i
    
    ''
    '' Load split planes
    ''
    seek #1, bsphead.planes.offs+1
    for  i = 0 to plnCount-1
        get #1,, planetmp
        plnBuffer(i).norm.x = planetmp.norm.x
        plnBuffer(i).norm.y = planetmp.norm.y
        plnBuffer(i).norm.z = planetmp.norm.z
        plnBuffer(i).dist = planetmp.dist
        
        loading = loading + ((100.0/14.0)/plnCount)
        drwLoadingBar hVideoDC, (320-150)\2, (200-20)\2, 150, 20, loading, -1
    next i    
    
    ''
    '' Load Model and sub model info
    ''    
    seek #1, bsphead.models.offs+1
    for  i = 0 to mdlCount-1
        get #1,, mdlBuffer(i)
        
        loading = loading + ((100.0/14.0)/mdlCount)
        drwLoadingBar hVideoDC, (320-150)\2, (200-20)\2, 150, 20, loading, -1
    next i

    ''
    '' Load PVS
    ''    
    seek #1, bsphead.vislist.offs+1
    for  i = 0 to (bsphead.vislist.size\2)-1
        get #1,, pvsBufferA(i)
    next i
    
    if ( bsphead.vislist.size mod 2 ) then
        get #1,, pvsBufferA(i)
    end if
    loading = loading + (100.0/14.0)
    drwLoadingBar hVideoDC, (320-150)\2, (200-20)\2, 150, 20, loading, -1 
    
    ''
    '' Load texture offsets
    ''
    seek #1, bsphead.texinfo.offs+1
    for  i = 0 to texiCount-1
        get #1 ,, texInfBuff(i)
        
        loading = loading + (100.0/14.0)/texiCount
        drwLoadingBar hVideoDC, (320-150)\2, (200-20)\2, 150, 20, loading, -1
    next i
    
    seek #1, bsphead.miptex.offs+1
    get #1,, numtex&
    
    redim tmipinf( numtex&-1 ) as miptex
    redim mipBuffInf( numtex&-1 ) as miptexb
    
    for  i = 0 to numtex&-1
        get #1,, texoffs(i)
    next i    
    
    for  i = 0 to numtex&-1
        seek #1, bsphead.miptex.offs+texoffs(0)+1
        get #1,, tex
    next i

    
    redim colmap(8192*2-1) as integer

    ''
    '' Load colormap
    ''    
    if ( uarOpen( file, "base.dat::color/colormap.lmp", F4READ ) = false ) then
        ExitError "Could not open ( 1 ) base.dat::color/colormap.lmp..."
    end if

    if ( uarReadEx( file, colmap(0), 16384 ) <> 16384 ) then
        ExitError "Could not open ( 2 ) base.dat::color/colormap.lmp..."
    end if
    
    loading = loading + (100.0/14.0)
    drwLoadingBar hVideoDC, (320-150)\2, (200-20)\2, 150, 20, loading, -1    
    
    
    uarClose file
    
    
    ''
    '' Load textures and mipmaps
    '' FIXME: Current code is fragements memory and
    ''        assumes that the textures are powers of 2
    ''        
    dim byte as string * 1 
    
    dim tmpdc as long
    dim dx as single, dy as single
    dim cx as single, cy as single
    
    dim miplevel0( numtex&-1 ) as long
    dim miplevel1( numtex&-1 ) as long
    dim miplevel2( numtex&-1 ) as long
    dim miplevel3( numtex&-1 ) as long
    
    if ( (uglNewMult( miplevel0(), numtex&, ugl.ems, ugl.8bit, 64, 64 ) = false) or _
         (uglNewMult( miplevel1(), numtex&, ugl.ems, ugl.8bit, 32, 32 ) = false) or _
         (uglNewMult( miplevel2(), numtex&, ugl.ems, ugl.8bit, 16, 16 ) = false) or _
         (uglNewMult( miplevel3(), numtex&, ugl.ems, ugl.8bit, 08, 08 ) = false) ) then
            ExitError "0x0004, Could not create textures..."
    end if
    
    tmpdc = uglNew( UGL.EMS, env.cFmt, 256, 256 )
    if ( tmpdc = false ) then
        ExitError "0x0004, Could not create texture temp..."
    end if
    
    dim pal as long
    dim palseg as integer
    dim palofs as integer
    dim cmpseg as integer
    dim cmpofs as integer
    dim dist as single
    dim dista as single    
    dim r as single
    dim g as single
    dim b as single
    dim s as single
    dim t as single
    
    
    pal = uglPalLoad( "base.dat::color/palette.lmp", PALRGB )
    palseg = pal \ 65536&
    palofs = pal and &h0000ffff&
    
    cmpseg = varseg( colmap(0) ) 
    cmpofs = varptr( colmap(0) ) + 256*0
            
    fontPrintText hVideoDC, 0, 199-8, "Loading and converting textures, this might take a while..."
    
    
    for  i = 0 to numtex&-1
        seek #1, bsphead.miptex.offs+texoffs(i)+1
        get #1,, tmipinf(i)
        
        
        mipBuffInf(i).hght = 1.0 / tmipinf(i).hght
        mipBuffInf(i).wdth = 1.0 / tmipinf(i).wdth        
        
        dx = tmipinf(i).wdth / 64.0
        dy = tmipinf(i).hght / 64.0
        
        
        
        ''
        '' Scale texture and create mipmaps
        '' FIXME: Way too slow
        ''
        ''

        for  j = 0 to 3
        
            mipl = 2^j            
            
            seek #1, bsphead.miptex.offs+texoffs(i)+ tmipinf(i).offset(j)+1
            
            def seg = cmpseg
            for  y = 0 to tmipinf(i).hght\mipl-1
                for  x = 0 to tmipinf(i).wdth\mipl-1
                    get #1,, byte
                    uglPset tmpdc&, x, y, peek( cmpofs+asc(byte) )
                next x
            next y
        

            select case ( j )
                case 0: hTextrDC(i*4+j) = miplevel0(i)
                case 1: hTextrDC(i*4+j) = miplevel1(i)
                case 2: hTextrDC(i*4+j) = miplevel2(i)
                case 3: hTextrDC(i*4+j) = miplevel3(i)
            end select
            
            def seg = palseg
            cy = 0.0

            for  y = 0 to ((64\(2^j))-1)
                cx = 0.0            
                
                for  x = 0 to ((64\(2^j))-1)
                    col1 = uglPGet( tmpdc&, _
                                    (cx+0) mod (tmipinf(i).wdth\mipl), _
                                    (cy+0) mod (tmipinf(i).hght\mipl) )
                    col2 = uglPGet( tmpdc&, _
                                    (cx+0) mod (tmipinf(i).wdth\mipl), _
                                    (cy+1) mod (tmipinf(i).hght\mipl) )
                    col3 = uglPGet( tmpdc&, _
                                    (cx+1) mod (tmipinf(i).wdth\mipl), _
                                    (cy+0) mod (tmipinf(i).hght\mipl) )
                    col4 = uglPGet( tmpdc&, _
                                    (cx+1) mod (tmipinf(i).wdth\mipl), _
                                    (cy+1) mod (tmipinf(i).hght\mipl) )
                                    
                    s = cx - int( cx )
                    t = cy - int( cy )
                    
                    ''
                    '' Average, bleh
                    ''
                    cofs1 = palofs+col1*3
                    cofs2 = palofs+col2*3
                    cofs3 = palofs+col3*3
                    cofs4 = palofs+col4*3

                    r = peek( cofs1+0 )*(1-s)*(1-t)
                    g = peek( cofs1+1 )*(1-s)*(1-t)
                    b = peek( cofs1+2 )*(1-s)*(1-t)
                    r = r + peek( cofs2+0 )*(1-s)*t
                    g = g + peek( cofs2+1 )*(1-s)*t
                    b = b + peek( cofs2+2 )*(1-s)*t
                    r = r + peek( cofs3+0 )*(1-t)*s
                    g = g + peek( cofs3+1 )*(1-t)*s
                    b = b + peek( cofs3+2 )*(1-t)*s
                    r = r + peek( cofs4+0 )*s*t
                    g = g + peek( cofs4+1 )*s*t
                    b = b + peek( cofs4+2 )*s*t
                    
                    if ( r > 255.0 ) then r = 255.0
                    if ( g > 255.0 ) then g = 255.0
                    if ( b > 255.0 ) then b = 255.0

                    
                    dist  = 167777217
                    
                    for  k = 0 to 255
                        kofs = palofs+k*3
                        r2! = r-peek( kofs+0 )
                        g2! = g-peek( kofs+1 )
                        b2! = b-peek( kofs+2 )
                                                
                        dista = r2!*r2! + g2!*g2! +b2!*b2!
                        
                        if ( dist > dista ) then
                            col = k
                            
                            if ( dista = 0.0 ) then
                                exit for
                            end if
                            
                            dist = dista                            
                        end if
                    next k
                    
                    uglPset hTextrDC(i*4+j), x, y, col
                    cx = cx + dx
                next x
                
                cy = cy + dy
            next y
            
            drwLoadingBar hVideoDC, (320-150)\2, (200-20)\2-15, 150, 7, (i*4+j)*25\numtex&, 51            
        next j
        
        loading = loading + (100.0/14.0)/numtex
        drwLoadingBar hVideoDC, (320-150)\2, (200-20)\2, 150, 20, loading, -1
        drwLoadingBar hVideoDC, (320-150)\2, (200-20)\2-15, 150, 7, (i*4+j)*25\numtex&, 51
    next i
    
    uglDel tmpdc&
    erase colmap
        
    
    close #1    
    
    uglRestore
    screen 0
    width 80, 25
    
    dim hFile as FILE
    
    ''
    '' Load ligtmap
    ''
    'if ( fileOpen( hFile, command$, F4READ ) = false ) then
    '    ExitError "File could not be opened for lightmap"
    'end if
    
    'lightmap = memAlloc( bsphead.lightmaps.size )
    'if ( lightmap = false ) then
    '  ExitError "Lightmap buffer could not be allocated"
    'end if   
   
    'if ( fileSeek( hFile, 0, bsphead.lightmaps.offs ) <> bsphead.lightmaps.offs ) then
    '    ExitError "Could not seek to lightmap data"
    'end if
    
    'if ( fileReadH( hFile, lightmap, bsphead.lightmaps.size ) <> bsphead.lightmaps.size ) then
    '    ExitError "Could not load lightmap data"
    'end if
    'fileClose hFile 
    
    ''
    '' Update face lightmap adresses
    ''
    for  i = 0 to triCount-1
        linaddr& = (lightmap \ 65536&) * 16
        linaddr& = linaddr& + (lightmap and &h0000ffff ) + triBuffer(i).lightmap
        
        triBuffer(i).lightmap = (linaddr& \ 16&)*65536& + linaddr& and 15
    next i    
    

        
    
    ''
    '' Set video mode
    '' 
    if ( env.usepag = true ) then
        pages = env.pages
    else
        pages = 1
    end if
            
    env.hVideoDC = uglSetVideoDC( env.cFmt, env.xRes, env.yRes, pages )
    if ( env.hVideoDC = FALSE ) then 
        ExitError "0x0001, Could not set video mode..."
    end if
    
    
    ''
    '' Create a backbuffer
    '' 
    if ( env.usepag = false ) then
        env.hBackBDC = uglNew( ugl.mem, env.cFmt, env.xRes, env.yRes )
        if ( env.hBackBDC = FALSE ) then 
            ExitError "0x0002, Could not create a backbuffer..."
        end if
    end if     
    

    ''
    '' Load quake palette
    ''    
    uglPalSet 0, 256, pal
    memFree pal
    
    
    ''
    '' Init mouse
    ''
    if ( mouseInit( env.hVideoDC, env.mouse ) = FALSE ) then
        ExitError "0x0006, Could not init mouse..."
    end if  
    
    ''
    '' Init keyboard
    ''
    kbdInit env.keyboard
    
    ''
    '' Init timer
    ''
    tmrInit
    
    
    ''
    '' Stop loading music
    ''
    if ( env.sound = true ) then
        modStop
        modDel loadmod
    end if


end sub




''::::
defint a-z
sub doMain
    dim a as single
    dim b as single
    dim vtx(31) as tritype
    static zm as single    
    static w1i as single
    static w2i as single
    static w3i as single    
    dim mtxMdl as u3dMtrx
    dim mtxPrj as u3dMtrx
    dim mtxFin as u3dMtrx
    dim mtxScl as u3dMtrx
    
    dim ppos(env.caminterp) as PNT3D
    dim plok(env.caminterp) as PNT3D
    dim cbzp(10) as PNT3D
    dim cbzl(10) as PNT3D
    
    dim hDstDC as long
    dim pa as integer
    dim crrPnt as integer
    dim cntPnts as integer
    dim xres as single, yres as single
    dim xresh as single, yresh as single
    
    dim viewvec as vertex
    dim poly(64) as u3dVector4f
    dim polyb(32) as u3dVector4f
    dim polyc(3) as u3dVector4f
    dim uvbuff(64) as uv
    dim uvbuffb(32) as uv
    dim vtxb as quadtype    
    
    dim min(1) as single
    dim max(1) as single
    dim bmin(1) as integer
    dim bmax(1) as integer
    dim extn(1) as integer
    dim polyvert as integer
    dim camPosB as u3dVector3f
    dim camPosC as u3dVector3f
    
    
    xres  = env.xRes
    yres  = env.yRes
    xresh = env.xRes/2.0
    yresh = env.yRes/2.0

    mousePos 0, 0


    camUp.x = 0.0
    camUp.y = 1.0
    camUp.z = 0.0   
    
    mousePos (env.xres-1) * startAngle/360.0, 110
    
    

    
    if ( env.cammode = 1 ) then
        open env.camscrpt for input as #1    
        do 
            input #1, cbzp(i).x, cbzp(i).y, cbzp(i).z
            input #1, cbzl(i).x, cbzl(i).y, cbzl(i).z
            i = i + 1
        loop until ( eof( 1 ) )    
        close #1    
        cntPnts = i-1
                
        ugluCubicBez3D ppos(0), cbzp(crrPnt), env.caminterp
        ugluCubicBez3D plok(0), cbzl(crrPnt), env.caminterp
        crrPnt = crrPnt + 3
    end if        
    
    if ( env.cammode = 2 ) then
        open env.camscrpt for output as #1
    end if
    
    
    
    hz& = tmrMs2Freq&( 1000 )
    tmrNew env.secTimer, TMR.AUTOINIT, hz&    
    
    if ( env.usepag = false ) then
        hDstDC = env.hBackBDC
    else        
        hDstDC = env.hVideoDC
    end if        
    
    u3dMtrxScale mtxScl, 1.0, 1.0, 1.0
    u3dMtrxPersp mtxPrj, env.camfov, 320.0/240.0, env.zNear, env.zFar
    
    usemips = -1
    rendmode = 0
    fpsview = -1
    
    if ( env.sound = true ) then
        modPlay mymod
    end if
    
    
    ''
    ''
    ''
    do  
    	''
    	'' Clear DC
    	''      
        if ( env.disclear = true ) then
            uglClear hDstDC, 0
        end if 
        
	''
	'' mode script_play run through the bezier curves
	''                
        if ( env.cammode = 1 ) then
            pa = pa + 1
            if ( crrPnt+3 <= cntPnts and last_point=false ) then
                if ( pa > env.caminterp ) then
                    
                            
                    ugluCubicBez3D ppos(0), cbzp(crrPnt), env.caminterp
                    ugluCubicBez3D plok(0), cbzl(crrPnt), env.caminterp
                    
                    pa = 0
                    crrPnt = crrPnt+3
                end if                
            else
                if ( crrPnt <> cntPnts and (not last_point) ) then
                    pa = 0
                    last_point = true
                    ugluCubicBez3D ppos(0), cbzp(cntPnts-4), env.caminterp
                    ugluCubicBez3D plok(0), cbzl(cntPnts-4), env.caminterp
                    
                elseif ( pa > env.caminterp ) then
                    crrPnt = 0
                    last_point = false
                    env.keyboard.esc = true
                end if                    
            end if                
            
            camPos.x = ppos(pa).x
            camPos.y = ppos(pa).y
            camPos.z = ppos(pa).z        
            camLookAt.x = camPos.x+plok(pa).x
            camLookAt.y = camPos.y+plok(pa).y
            camLookAt.z = camPos.z+plok(pa).z
        end if
        
        
        ''
        '' Mode: freelook or script_edit
        ''
        if ( env.cammode = 0 or env.cammode = 2 ) then            
            if env.mouse.x < 1 then  mousepos env.xres-4, env.mouse.y
            if env.mouse.x > env.xres-3 then  mousepos 1, env.mouse.y
            
            if env.mouse.y < 0        then  mousepos env.mouse.x, 0
            if env.mouse.y > env.yres then  mousepos env.mouse.x, env.yres-1
            
            tmx = env.mouse.x + 1
            tmy = env.mouse.y + 2

            theta! = 2 * 3.14159 * ((env.xRes-1)-tmx) / env.xRes
            phi! = 3.14159 * tmy / env.yRes
            
            camLookAt.x = cos( theta! ) * sin( phi! )
            camLookAt.y = cos( phi! )
            camLookAt.z = sin( theta! ) * sin( phi! )
            
    
            if ( env.mouse.left  ) then 
                camPosC.x = camPos.x + CamLookAt.x*3
                camPosC.y = camPos.y + CamLookAt.y*3
                camPosC.z = camPos.z + CamLookAt.z*3

        		camPos.x = camPosC.x
        		camPos.y = camPosC.y
        		camPos.z = camPosC.z
            end if
                        
            if ( env.mouse.right ) then
                camPosC.x = camPos.x - CamLookAt.x*3
                camPosC.y = camPos.y - CamLookAt.y*3
                camPosC.z = camPos.z - CamLookAt.z*3                
                
        		camPos.x = camPosC.x
        		camPos.y = camPosC.y
        		camPos.z = camPosC.z
            end if            
            
            if ( env.keyboard.n and env.cammode = 2 ) then
                print #1, camPos.x, camPos.y, camPos.z
                print #1, camLookAt.x, camLookAt.y, camLookAt.z
                
                while ( env.keyboard.n )
                wend
            end if
            
            camLookAt.x = camLookAt.x + camPos.x 
            camLookAt.y = camLookAt.y + camPos.y 
            camLookAt.z = camLookAt.z + camPos.z
        end if

    	''
    	'' Toggle mipmaps
    	''
        if ( env.keyboard.f1 ) then
            usemips = not usemips
            do 
            loop while ( env.keyboard.f1 )
        end if            

    	''
    	'' Toggle perspective/affine/wireframe
    	''        
        if ( env.keyboard.f2 ) then
            rendmode = (rendmode + 1) mod 3
            do 
            loop while ( env.keyboard.f2 )
        end if                    

    	''
    	'' Toggle cam/birdseye
    	''        
        if ( env.keyboard.f3 ) then
            fpsview = not fpsview
            do 
            loop while ( env.keyboard.f3 )
        end if            
        
    	''
    	'' Toggle stats
    	''        
        if ( env.keyboard.f12 ) then
            stats = not stats
            do 
            loop while ( env.keyboard.f12 )
        end if                    
        
    	''
    	'' Toggle backface culling
    	''        
        if ( env.keyboard.b ) then
            backface = not backface
            do 
            loop while ( env.keyboard.b )
        end if
        

        ''
        '' Combine all transforms 
        ''
        u3dMtrxLookAt mtxMdl, camPos, camLookAt, camUp        
        u3dMtrxConc mtxFin, mtxMdl, mtxPrj
        ExtractFrustum frustum(), mtxFin
        

        ''
        '' Birdseye stuff
        ''
        if ( fpsview = false ) then 
            camPosB.x = 351.0
            camPosB.y = 2119.0
            camPosB.z = -552.0            
                        
            camLookAt.x = camPosB.x + 1.991367e-8
            camLookAt.y = camPosB.y + -1.0
            camLookAt.z = camPosB.z + 1.570986e-2
        else
            camPosB.x = camPos.x
            camPosB.y = camPos.y
            camPosB.z = camPos.z
        end if
        
        '        
        u3dMtrxLookAt mtxMdl, camPosB, camLookAt, camUp        
        u3dMtrxConc mtxFin, mtxMdl, mtxPrj
        
        
        ''
        '' Walk BSP tree
        ''
        bspShowModel 0
        
        
       ''
       '' Draw nodes
       ''       
        for mi = 0 to ordCount-1
            m = orderList(mi)
                
            leafIndx = ndsBuffer(m).lfaceid
            leafEnd = leafIndx + ndsBuffer(m).lfacenum-1
            
            for  ti = leafIndx to leafEnd            
                i = ti
                       
                if ( polyFlag(i) ) then
                    
                    ''
                    '' Backface cull
                    ''
                    dim dp as single
                    
                    pid = triBuffer(nodenr).planeid
                    dp  = camPos.x*plnBuffer(pid).norm.x + _
                          camPos.y*plnBuffer(pid).norm.z + _
                          camPos.z*plnBuffer(pid).norm.y + _
                          plnBuffer(pid).dist
                          
                    if ( dp > 0.01 and triBuffer(nodenr).side = 1 ) then
                        drawply = 1
                    elseif ( dp < -0.01 and triBuffer(nodenr).side = 0 ) then
                        drawply = 1
                    else 
                        drawply = 1
                    end if
                    
                    if ( (backface and drawply) or (backface = 0) ) then
                    	
            		''
            		'' Build polygon
            		''
                        lid = triBuffer(i).ledgeid
                        tex = triBuffer(i).texinfoid
                        
                        min(0) =  99999
                        max(0) = -99999
                        min(1) =  99999
                        max(1) = -99999
                        
                        for  j = 0 to triBuffer(i).ledgenum-1
                            EdgeIdx = ledgBuffer(lid+j)
                            
                            if ( EdgeIdx >= 0 ) then
                                v0 = edgBuffer(EdgeIdx).v0
                            else                        
                                v0 = edgBuffer(-EdgeIdx).v1
                            end if
    
                            polyb(j).x = vtxBuffer(v0).x
                            polyb(j).y = vtxBuffer(v0).z
                            polyb(j).z = vtxBuffer(v0).y
                            polyb(j).w = 1.0
                            
                            uvbuffb(j).u = texInfBuff(tex).vecs(0)*vtxBuffer(v0).x + _
                                           texInfBuff(tex).vecs(1)*vtxBuffer(v0).y + _
                                           texInfBuff(tex).vecs(2)*vtxBuffer(v0).z + _
                                           texInfBuff(tex).vecs(3)
                                           
                            if ( uvbuffb(j).u < min(0) ) then
                                min(0) = uvbuffb(j).u
                            end if
                            
                            if ( uvbuffb(j).u > max(0) ) then
                                max(0) = uvbuffb(j).u
                            end if
                            
                                          
                            uvbuffb(j).v = texInfBuff(tex).vect(0)*vtxBuffer(v0).x + _
                                           texInfBuff(tex).vect(1)*vtxBuffer(v0).y + _
                                           texInfBuff(tex).vect(2)*vtxBuffer(v0).z + _                                  
                                           texInfBuff(tex).vect(3)
                                           
                            if ( uvbuffb(j).v < min(1) ) then
                                min(1) = uvbuffb(j).v
                            end if
                            
                            if ( uvbuffb(j).v > max(1) ) then
                                max(1) = uvbuffb(j).v
                            end if
                            
                            uvbuffb(j).u = uvbuffb(j).u * mipBuffInf(texInfBuff(tex).miptex).wdth
                            uvbuffb(j).v = uvbuffb(j).v * mipBuffInf(texInfBuff(tex).miptex).hght
                        next j
                        
                        ''
                        '' Calc lightmap size
                        ''
                        for  j = 0 to 1
                            bmin(j) =  int( min(j) / 16 )
                            bmax(j) = cint( max(j) / 16 )                            
                            extn(j) = bmax(j) - bmin(j)
                        next j
                        
                        smax = extn(0)
                        tmax = extn(1)
                        size = smax*tmax
                        lght&= triBuffer(i).lightmap

                        
                        ''
                        '' Transform and clip to near and far
                        ''
                        u3dMtrxByVec4 polyb(0), len( polyb(0) ), mtxFin, _
                                      polyb(0), len( polyb(0) ), triBuffer(i).ledgenum
                        SHClipzNearFar poly(), uvbuff(), polycnt, polyb(), uvbuffb(), triBuffer(i).ledgenum

            			''
            			'' If more then 2 vertices, rasterize
            			''
                        if polycnt > 2 then
                        	
                        	tricnt = 0
                            for j = 0 to polycnt-3
                                p1 = 0
                                p2 = j+1
                                p3 = j+2
                                
                                w1i = polyb(p1).w
                                w2i = polyb(p2).w
                                w3i = polyb(p3).w                          
                                
                                
                                ''
                                '' Find mip level
                                ''
                				if ( w1i < w2i ) then
                    				if ( w1i < w3i ) then
                    				    zl! = w1i
                    				else
                    				    zl! = w3i
                    				end if
                    				
                				else
                    				if ( w2i < w3i ) then
                    				    zl! = w2i
                    				else
                    				    zl! = w3i
                    				end if
                				end if
                				
                				zl! = (w1i+w2i+w3i)/3
                				
                				if  ( zl! >= 1400.0 ) then
                				    miplevel = 3
                				elseif  ( zl! >= 1400.0*0.8*0.50 ) then
                				    miplevel = 2
                				elseif  ( zl! >= 1400.0*0.8*0.25 ) then
                				    miplevel = 1
                				else
                				    miplevel = 0
                				end if
                				
                				if ( usemips ) then 
                                    texIndx = texInfBuff(tex).miptex*4+miplevel
                				else
                				    texIndx = texInfBuff(tex).miptex*4+0
                				end if
				                
				                ''
				                '' Rasterize
				                ''

                                
                                w1i = 1.0 / w1i
                                w2i = 1.0 / w2i
                                w3i = 1.0 / w3i
                                vtx(j).v1.z = w1i
                                vtx(j).v2.z = w2i
                                vtx(j).v3.z = w3i
                                vtx(j).v1.x = xresh + polyb(p1).x*w1i*xresh
                                vtx(j).v1.y = yresh - polyb(p1).y*w1i*yresh
                                vtx(j).v2.x = xresh + polyb(p2).x*w2i*xresh
                                vtx(j).v2.y = yresh - polyb(p2).y*w2i*yresh
                                vtx(j).v3.x = xresh + polyb(p3).x*w3i*xresh
                                vtx(j).v3.y = yresh - polyb(p3).y*w3i*yresh
                                
                                
                                if ( rendmode = 0 ) then                                    
                                    vtx(j).v1.u = uvbuffb(p1).u * w1i 
                                    vtx(j).v1.v = uvbuffb(p1).v * w1i
                                    vtx(j).v2.u = uvbuffb(p2).u * w2i
                                    vtx(j).v2.v = uvbuffb(p2).v * w2i
                                    vtx(j).v3.u = uvbuffb(p3).u * w3i
                                    vtx(j).v3.v = uvbuffb(p3).v * w3i
                                                                    
                                    uglTriTP hDstDC, vtx(j), 0, hTextrDC(texIndx)
                                
                                elseif ( rendmode = 1 ) then                                   
                                    vtx(j).v1.u = uvbuffb(p1).u
                                    vtx(j).v1.v = uvbuffb(p1).v
                                    vtx(j).v2.u = uvbuffb(p2).u
                                    vtx(j).v2.v = uvbuffb(p2).v
                                    vtx(j).v3.u = uvbuffb(p3).u
                                    vtx(j).v3.v = uvbuffb(p3).v
                                                                    
                                    uglTriT hDstDC, vtx(j), 0, hTextrDC(texIndx)
                                else
                                    uglTriF hDstDC, vtx(j), 200 
                                    uglLine hDstDC, vtx(j).v1.x, vtx(j).v1.y, vtx(j).v2.x, vtx(j).v2.y, 0
                                    uglLine hDstDC, vtx(j).v2.x, vtx(j).v2.y, vtx(j).v3.x, vtx(j).v3.y, 0
                                    uglLine hDstDC, vtx(j).v3.x, vtx(j).v3.y, vtx(j).v1.x, vtx(j).v1.y, 0
                                end if
                                
                                tris = tris + 1                                
                            next j
                            
                            if ( rendmode = 0 ) then                                                                
                                'uglTriTPM hDstDC, vtx(0), j, 0, hTextrDC(texIndx)
                            end if
                            
                        end if
                    end if
                    
                    polys = polys + 1
                end if
                
            next ti
        next mi        


        
        ''
        '' Draw VUs
        ''
        sndMasterGetVU l, r
        drwLoadingBar hDstDC, env.xres-80, env.yres-29, 70, 3, l*100/255, 254
        drwLoadingBar hDstDC, env.xres-80, env.yres-20, 70, 3, r*100/255, 254
        

        ''
        '' Print stuff
        ''
        if ( stats ) then                    
            fontPrintText hDstDC, 0, 8*0, "Fps: " + str$( fps )
            fontPrintText hDstDC, 0, 8*1, "Renderd polys: " + str$( polys )
            fontPrintText hDstDC, 0, 8*2, "Renderd triangles: " + str$( tris )
            
            if ( usemips ) then 
                fontPrintText hDstDC, 0, 8*3, "Mipmapping: enabled, press f1 to disable"
            else
                fontPrintText hDstDC, 0, 8*3, "Mipmapping: disabled, press f1 to enable"
            end if
            
            if ( rendmode = 0 ) then 
                fontPrintText hDstDC, 0, 8*4, "Render mode: perspective correct, press f2 to change"
            elseif ( rendmode = 1 ) then 
                fontPrintText hDstDC, 0, 8*4, "Render mode: affine, press f2 to change"
            else
                fontPrintText hDstDC, 0, 8*4, "Render mode: wireframe, press f2 to change"
            end if       
            
            if ( backface ) then 
                fontPrintText hDstDC, 0, 8*5, "Backface culling: enabled, press 'b' to disable"
            else
                fontPrintText hDstDC, 0, 8*5, "Backface culling: disabled, press 'b' to enable"
            end if
            
            fontPrintText hDstDC, 0, env.yres-8*7-6, "Resolution: " + str$( env.xres ) + "x" + ltrim$(str$( env.yres ))
            fontPrintText hDstDC, 0, env.yres-8*6-6, "Vertices:" + str$( vtxCount )
            fontPrintText hDstDC, 0, env.yres-8*5-6, "Edges:" + str$( edgCount )
            fontPrintText hDstDC, 0, env.yres-8*4-6, "Polygons:" + str$( triCount )
            fontPrintText hDstDC, 0, env.yres-8*3-6, "Nodes:" + str$( ndsCount )
            fontPrintText hDstDC, 0, env.yres-8*2-6, "Leaves:" + str$( lefCount )
            fontPrintText hDstDC, 0, env.yres-8*1-6, "PVS entries:" + str$( lefCount^2 )
            fontPrintText hDstDC, 0, env.yres-8*0-6, "Stats: enabled, press f12 to disable"             
        else 
            fontPrintText hDstDC, 0, env.yres-8*0-6, "Stats: disabled, press f12 to enable"
        end if
        
        fontPrintText hDstDC, env.xres-56, env.yres-6, "Powered by UGL"
            
        
        ''
        '' Take screenshoot ?
        '' 
        if ( env.keyboard.s ) then            
            ugluBMPSave "scrn" + ltrim$(rtrim$(str$( screenie ))) + ".bmp", hDstDC
            screenie = screenie + 1
        end if
        
        ''
        '' Paging/backbuffer
        ''
        if ( env.usepag = false ) then
            uglPut env.hVideoDC, 0, 0, env.hBackBDC
        else        
            uglSetVisPage page
            uglSetWrkPage (page+1) mod env.pages
            page = (page+1) mod env.pages
        end if
        
        fps1 = fps1 + 1
        env.frames = env.frames + 1.0
        
        if env.secTimer.counter > 0 then
            fps = fps1
            fps1 = 0
            env.secTimer.counter = 0
        end if        
        
        tris = 0
        polys = 0
        
        
    loop while ( env.keyboard.esc = FALSE )
    
    tmrDel env.secTimer
    close #1

end sub


''::::
defint a-z
sub doEnd
    
    ''
    '' Restore video mode and end UGL
    ''
    uglRestore
    uglEnd
    
    screen 0
    width 80, 25
    end

end sub


''::::::::::::
defint a-z
function bspClasifypoint% ( nodenr as integer )
  
    dp! = camPos.x*plnBuffer(ndsBuffer(nodenr).planeid).norm.x + _
          camPos.y*plnBuffer(ndsBuffer(nodenr).planeid).norm.z + _
          camPos.z*plnBuffer(ndsBuffer(nodenr).planeid).norm.y
          
    if ( (dp!-plnBuffer(ndsBuffer(nodenr).planeid).dist) > 0.0 ) then
        bspClasifypoint% = -1
    else
        bspClasifypoint% = 0
    end if
    
end function



defint a-z
sub bspWalkNodeB ( byval nodenr as integer ) static
    dim dp as single

    
    ''
    '' If bit 15 is set we are at the end of the branch. We
	'' draw the leaf and go back.
	''
	
	if ( nodenr and &h8000 ) then
	    
	    ''
	    '' Check pvs and bounding volume
	    ''
	    if ( pvsBufferB(not nodenr) and _
	         BBoxInFrustum( lefBuffer(not nodenr).bound, frustum() ) ) then
	    
	        frst = lefBuffer(not nodenr).lfaceid
	        last = frst+lefBuffer(not nodenr).lfacenum
	        
	        for  i = frst to last-1	            
	            polyFlag(lfcBuffer(i)) = 1
	        next i
	        
	        
    	    ''
    	    '' Put leaf in ordering list
    	    ''
    	    drwLeafs = drwLeafs + 1
        else 
            culLeafs = culLeafs + 1
        end if
        
	    exit sub
    end if    
    
    if ( not BBoxInFrustum( ndsBuffer(nodenr).bound, frustum() ) ) then
        exit sub
    end if
    
    pid = ndsBuffer(nodenr).planeid
    dp  = camPos.x*plnBuffer(pid).norm.x + _
          camPos.y*plnBuffer(pid).norm.z + _
          camPos.z*plnBuffer(pid).norm.y
          
    if ( dp-plnBuffer(pid).dist >= 0.0 ) then
        side = 1
    else
        side = 0
    end if
    
    if ( side ) then
    	''
    	'' We are at the front side of a node. First walk the
    	'' back nodes, then the front nodes.
    	''
    		
        bspWalkNodeB ndsBuffer(nodenr).child1
	    orderList(ordCount) = nodenr
	    ordCount = ordCount + 1
        bspWalkNodeB ndsBuffer(nodenr).child0
        
    else
        ''
	    '' We are at the back side of a node. First walk the
	    '' front nodes, then the back nodes.
	    ''
    		
        bspWalkNodeB ndsBuffer(nodenr).child0        
	    orderList(ordCount) = nodenr
	    ordCount = ordCount + 1        
        bspWalkNodeB ndsBuffer(nodenr).child1
    end if
    

end sub


'':::::::::
defint a-z
sub bspShowModel ( model as integer )
    ''
    '' Reset tree state
    ''
    ordCount = 0
    culLeafs = 0
    drwLeafs = 0
    
    for  i = 0 to triCount-1        
        polyFlag(i) = 0
    next i    
    
    ''
    '' Extract pvs
    ''
    pvsInit int(mdlBuffer(model).headnode0)
    
    ''
    '' Traverse tree
    ''
    bspWalkNodeB int(mdlBuffer(model).headnode0)
    
end sub


''::::
defint a-z
sub ExitError ( msg as string )
    ''
    '' Restore video mode and end UGL
    ''
    uglRestore
    uglEnd
    
    ''
    '' Print msg and quit program
    ''
    screen 0
    width 80, 25
    print "Error: " + msg
    sleep
    end
end sub


defint a-z
sub strtok ( strm() as string, strm_cnt as integer, _
             tokenlist as string, stream as string )
             
    dim char as string * 1
    dim i as integer, j as integer    
    
    dim is_a_tok as integer
    dim token_cnt as integer
    dim last_char_tok as integer
    dim token(50-1) as string * 1    
    
    dim stream_len as integer            
    dim stream_pos as integer    
    dim crnt_strm_indx as integer
    
    
    ''
    '' Reset vars 
    ''    
    strm_cnt   = 0    
    token_cnt  = 0
    stream_pos = 0
    crnt_strm_indx = 0
    strm(crnt_strm_indx) = ""
    
    
    ''
    '' Check stream length
    ''
    stream_len = len( stream )
    if ( stream_len = 0 ) then exit sub
        
    ''
    '' Exract tokens
    ''
    token_cnt = len( tokenlist )
    if ( token_cnt = 0  ) then exit sub
    if ( token_cnt > 50 ) then exit sub
    
    for  i = 1 to token_cnt
        token( i-1 ) = mid$( tokenlist, i, 1 )
    next i
    
    ''
    '' Tokenize
    '' 
    for  i = 1 to stream_len
        
        ''
        '' Get a char
        ''
        char = mid$( stream, i, 1 )
    
        ''
        '' Compare current char against all tokens
        '' 
        is_a_tok = false
        
        for  j = 0 to token_cnt-1
            if ( char = token(j) ) then
                is_a_tok = true
                exit for
            end if                
        next j
        
        ''
        '' If the current char isn't a token, we should
        '' add it do the out stream 
        ''
        if ( is_a_tok = false ) then
            strm(crnt_strm_indx) = strm(crnt_strm_indx) + char
            
        else         
            ''
            '' New stream
            ''
            if ( last_char_tok = false ) then
                crnt_strm_indx = crnt_strm_indx + 1
                strm(crnt_strm_indx) = ""
            end if                            
        end if
        
        last_char_tok = is_a_tok
    next i    
    
    ''
    '' Tell the user the stream count
    ''
    if ( len( strm(crnt_strm_indx) ) = 0 ) then 
        strm_cnt = crnt_strm_indx
    else
        strm_cnt = crnt_strm_indx + 1
    end if
            
end sub


defint a-z
sub parseIni ( filename as string )

    const xres_flag = 1
    const yres_flag = 2
    const cfmt_flag = 4
    const zn_flag   = 8
    const zf_flag   = 16
    const cmscr_flag= 32
    const page_flag = 64
    const usepg_flag= 128
    const clear_flag= 256
    const cminp_flag= 512
    const cmmde_flag= 1024
    const fov_flag  = 2048
    const sound_flag= 4096
    const all_flag% = xres_flag or yres_flag or zn_flag or zf_flag or cmscr_flag or _
                      page_flag or usepg_flag or clear_flag or cminp_flag or cmmde_flag or _
                      fov_flag or sound_flag
    
    dim flags as integer   
    dim rawline as string
    dim linenum as integer
    dim strm(50) as string
    dim strm_cnt as integer
    
    flags = 0
    file = freefile
    
    open filename for input as #file
    
    env.cFmt = UGL.8BIT    
            
    do 
        line input #file, rawline        
        strtok strm(), strm_cnt, "  ", rawline
        
        
        if ( strm_cnt > 0 ) then
            select case strm(0)
                case "//"
                
                case "display.xres"                
                    if ( (strm_cnt <> 3) and (strm(3) <> "//") ) then
                        ExitError "Uknown syntax at line # " + str$(linenum)
                    end if
                    
                    if ( strm(1) <> "=" ) then
                        ExitError "Uknown syntax at line # " + str$(linenum)
                    end if
                    
                    env.xRes = val( strm(2) )
                    flags = flags or xres_flag
                    
                case "display.yres"
                    if ( (strm_cnt <> 3) and (strm(3) <> "//") ) then
                        ExitError "Uknown syntax at line # " + str$(linenum)
                    end if
                    
                    if ( strm(1) <> "=" ) then
                        ExitError "Uknown syntax at line # " + str$(linenum)
                    end if
                    
                    env.yRes = val( strm(2) )
                    flags = flags or yres_flag
                    
                    
                case "display.clear"
                    if ( (strm_cnt <> 3) and (strm(3) <> "//") ) then
                        ExitError "Uknown syntax at line # " + str$(linenum)
                    end if
                    
                    if ( strm(1) <> "=" ) then
                        ExitError "Uknown syntax at line # " + str$(linenum)
                    end if
                    
                    if ( strm(2) = "no" ) then
                        env.disclear = false
                        flags = flags or clear_flag
                    elseif ( strm(2) = "yes" ) then
                        env.disclear = true
                        flags = flags or clear_flag
                    end if
                                        
                case "display.pages"
                    if ( (strm_cnt <> 3) and (strm(3) <> "//") ) then
                        ExitError "Uknown syntax at line # " + str$(linenum)
                    end if
                    
                    if ( strm(1) <> "=" ) then
                        ExitError "Uknown syntax at line # " + str$(linenum)
                    end if
                    
                    env.pages = val( strm(2) )
                    flags = flags or page_flag
                    
                case "display.usepaging"
                    if ( (strm_cnt <> 3) and (strm(3) <> "//") ) then
                        ExitError "Uknown syntax at line # " + str$(linenum)
                    end if
                    
                    if ( strm(1) <> "=" ) then
                        ExitError "Uknown syntax at line # " + str$(linenum)
                    end if
                    
                    if ( strm(2) = "no" ) then
                        env.usepag = false
                        flags = flags or usepg_flag
                    elseif ( strm(2) = "yes" ) then
                        env.usepag = true
                        flags = flags or usepg_flag
                    end if
                                    
                case "world.frustum.zn"                
                    if ( (strm_cnt <> 3) and (strm(3) <> "//") ) then
                        ExitError "Uknown syntax at line # " + str$(linenum)
                    end if
                    
                    if ( strm(1) <> "=" ) then
                        ExitError "Uknown syntax at line # " + str$(linenum)
                    end if
                    
                    env.zNear = val( strm(2) )
                    flags = flags or zn_flag
                                    
                case "world.frustum.zf"                
                    if ( (strm_cnt <> 3) and (strm(3) <> "//") ) then
                        ExitError "Uknown syntax at line # " + str$(linenum)
                    end if
                    
                    if ( strm(1) <> "=" ) then
                        ExitError "Uknown syntax at line # " + str$(linenum)
                    end if
                    
                    env.zFar = val( strm(2) )
                    flags = flags or zf_flag
                                    
                case "world.camera.script"
                    if ( (strm_cnt <> 3) and (strm(3) <> "//") ) then
                        ExitError "Uknown syntax at line # " + str$(linenum)
                    end if
                    
                    if ( strm(1) <> "=" ) then
                        ExitError "Uknown syntax at line # " + str$(linenum)
                    end if
                    
                    env.camscrpt = strm(2)
                    flags = flags or cmscr_flag
                    
                case "world.camera.interp"
                    if ( (strm_cnt <> 3) and (strm(3) <> "//") ) then
                        ExitError "Uknown syntax at line # " + str$(linenum)
                    end if
                    
                    if ( strm(1) <> "=" ) then
                        ExitError "Uknown syntax at line # " + str$(linenum)
                    end if
                    
                    env.caminterp = val( strm(2) )
                    flags = flags or cminp_flag
                    
                case "world.camera.mode"
                    if ( (strm_cnt <> 3) and (strm(3) <> "//") ) then
                        ExitError "Uknown syntax at line # " + str$(linenum)
                    end if
                    
                    if ( strm(1) <> "=" ) then
                        ExitError "Uknown syntax at line # " + str$(linenum)
                    end if
                    
                    if ( strm(2) = "freelook" ) then
                        env.cammode = 0
                    elseif ( strm(2) = "script_play" ) then
                        env.cammode = 1
                    elseif ( strm(2) = "script_edit" ) then
                        env.cammode = 2
                    else
                        ExitError "Uknown syntax at line # " + str$(linenum)                                                
                    end if                    
                    
                    flags = flags or cmmde_flag
                    
                case "world.camera.fov"
                    if ( (strm_cnt <> 3) and (strm(3) <> "//") ) then
                        ExitError "Uknown syntax at line # " + str$(linenum)
                    end if
                    
                    if ( strm(1) <> "=" ) then
                        ExitError "Uknown syntax at line # " + str$(linenum)
                    end if
                    
                    env.camfov = val( strm(2) )
                    flags = flags or fov_flag
                    
                case "sound.enabled"
                    if ( (strm_cnt <> 3) and (strm(3) <> "//") ) then
                        ExitError "Uknown syntax at line # " + str$(linenum)
                    end if
                    
                    if ( strm(1) <> "=" ) then
                        ExitError "Uknown syntax at line # " + str$(linenum)
                    end if
                    
                    if ( strm(2) = "false" ) then
                        env.sound = false
                        flags = flags or sound_flag
                    elseif ( strm(2) = "true" ) then
                        env.sound = true
                        flags = flags or sound_flag
                    end if                    
                
                case else
                    ExitError "Unknown command, " + rawline
                    
            end select                                    
        end if
        
        if ( flags = all_flag% ) then
            exit do
        end if
    
    loop until ( eof( 1 ) )
    close #file
    
    if ( flags <> all_flag% ) then
        ExitError "Incorrect ini file..."
    end if    

end sub




'':::::::::
defint a-z
sub ExtractFrustum ( frustum() as plane, mtx as u3dMtrx )
    dim i as integer
    dim d as single

    ''
    '' Left clipping plane    
    ''
    frustum(0).norm.x = -(mtx.m14 + mtx.m11)
    frustum(0).norm.y = -(mtx.m24 + mtx.m21)
    frustum(0).norm.z = -(mtx.m34 + mtx.m31)
    frustum(0).dist   = -(mtx.m44 + mtx.m41)
    
    ''
    '' Right clipping plane    
    ''
    frustum(1).norm.x = -(mtx.m14 - mtx.m11)
    frustum(1).norm.y = -(mtx.m24 - mtx.m21)
    frustum(1).norm.z = -(mtx.m34 - mtx.m31)
    frustum(1).dist   = -(mtx.m44 - mtx.m41)
    
    ''
    '' Top clipping plane    
    ''
    frustum(2).norm.x = -(mtx.m14 - mtx.m12)
    frustum(2).norm.y = -(mtx.m24 - mtx.m22)
    frustum(2).norm.z = -(mtx.m34 - mtx.m32)
    frustum(2).dist   = -(mtx.m44 - mtx.m42)
    
    ''
    '' Bottom clipping plane    
    ''
    frustum(3).norm.x = -(mtx.m14 + mtx.m12)
    frustum(3).norm.y = -(mtx.m24 + mtx.m22)
    frustum(3).norm.z = -(mtx.m34 + mtx.m32)
    frustum(3).dist   = -(mtx.m44 + mtx.m42)
    
   
    ''
    '' Near clipping plane    
    ''
    frustum(4).norm.x = -(mtx.m14 + mtx.m13)
    frustum(4).norm.y = -(mtx.m24 + mtx.m23)
    frustum(4).norm.z = -(mtx.m34 + mtx.m33)
    frustum(4).dist   = -(mtx.m44 + mtx.m43)
    
    ''
    '' Far clipping plane    
    ''
    frustum(5).norm.x = -(mtx.m14 - mtx.m13)
    frustum(5).norm.y = -(mtx.m24 - mtx.m23)
    frustum(5).norm.z = -(mtx.m34 - mtx.m33)
    frustum(5).dist   = -(mtx.m44 - mtx.m43)
       
    
    ''
    '' Normalize
    ''
    for  i = 0 to 5
        d = 1.0 / sqr( frustum(i).norm.x*frustum(i).norm.x + _
                       frustum(i).norm.y*frustum(i).norm.y + _
                       frustum(i).norm.z*frustum(i).norm.z )
                  
        frustum(i).norm.x = frustum(i).norm.x * d
        frustum(i).norm.y = frustum(i).norm.y * d
        frustum(i).norm.z = frustum(i).norm.z * d
        frustum(i).dist   = frustum(i).dist   * d        
    next i

end sub



'':::::::::
defint a-z
function BBoxInFrustum% ( bbox as bboundbox, frustum() as plane )
    dim dp as single
    dim nearPoint as vertex


    for  i = 0 to 5
        if ( frustum(i).norm.x > 0.0 ) then
            if ( frustum(i).norm.y > 0.0 ) then
                if ( frustum(i).norm.z > 0.0 ) then
                    NearPoint.x = bbox.min.x
                    NearPoint.y = bbox.min.z
                    NearPoint.z = bbox.min.y
                else
                    NearPoint.x = bbox.min.x
                    NearPoint.y = bbox.min.z
                    NearPoint.z = bbox.max.y
                end if
            else
                if ( frustum(i).norm.z > 0.0 ) then
                    NearPoint.x = bbox.min.x
                    NearPoint.y = bbox.max.z
                    NearPoint.z = bbox.min.y
                else
                    NearPoint.x = bbox.min.x
                    NearPoint.y = bbox.max.z
                    NearPoint.z = bbox.max.y
                end if
            end if
        else
            if ( frustum(i).norm.y > 0.0 ) then
                if ( frustum(i).norm.z > 0.0 ) then
                    NearPoint.x = bbox.max.x
                    NearPoint.y = bbox.min.z
                    NearPoint.z = bbox.min.y
                else
                    NearPoint.x = bbox.max.x
                    NearPoint.y = bbox.min.z
                    NearPoint.z = bbox.max.y
                end if
            else
                if ( frustum(i).norm.z > 0.0 ) then
                    NearPoint.x = bbox.max.x
                    NearPoint.y = bbox.max.z
                    NearPoint.z = bbox.min.y
                else
                    NearPoint.x = bbox.max.x
                    NearPoint.y = bbox.max.z
                    NearPoint.z = bbox.max.y
                end if
            end if
        end if            
            
        dp = frustum(i).norm.x*NearPoint.x + frustum(i).norm.y*NearPoint.y + _
             frustum(i).norm.z*NearPoint.z
             
        if ( (dp+frustum(i).dist) > 0 ) then
            BBoxInFrustum% = 0
            exit function
        end if
    next i    
    
    BBoxInFrustum% = -1
end function



''::::::::::
defint a-z
sub pvsInit ( byval nodenr as integer )
    dim v as long
    dim l as long
    dim j as long
    dim bit as long
    dim byte as integer
    
    ''
    '' Find the node that the camera is in
    ''
    while not ( nodenr and &h8000 )
        if ( bspClasifypoint( nodenr ) ) then
            nodenr = ndsBuffer(nodenr).child0
        else
            nodenr = ndsBuffer(nodenr).child1
        end if            
    wend
    
    '' 
    '' Setup
    ''    
    v = lefBuffer( not nodenr ).vislist
    if ( v = -2 ) then ExitError "Leaf has no pvs data."
        
    v = v + varptr( pvsBufferA(0) )
    def seg = varseg( pvsBufferA(0) )
    
    if ( lefBuffer( not nodenr ).vislist = -1 ) then
        for  i = 0 to lefCount-1
            pvsBufferB(i) = -1
        next i           

        exit sub
    end if
    
    '' 
    '' Extract the pvs data
    ''
    l = 1
    while ( l < lefCount )
        
        if ( peek( v ) = 0 ) then
            j = l
            l = l + 8& * peek( v+1 ) 
            
            for  j = j to l-1
                pvsBufferB(j) = 0
            next j
            
            v = v + 1
        else
            byte = peek(v)
            
            for  bit = 0 to 7
                        
                if ( byte and bitarray(bit) ) then
                    pvsBufferB(l) = 1
                else                 
                    pvsBufferB(l) = 0
                end if
                
                l = l + 1
            next bit            
        end if            
            
        v = v + 1        
    wend


end sub 



'':::::::
defint a-z
sub SHClipzNearFar ( otVtx() as u3dVector4f, otUV() as uv, otCnt as integer, _
                     inVtx() as u3dVector4f, inUV() as uv, inCnt as integer )

    dim n as integer
    dim scl as single
    dim dsti as integer, tmCnt as integer
    dim src1 as integer, src2 as integer

    for  n = 0 to inCnt-1
        src1 = n
        src2 = (n + 1) mod inCnt
        
        if ( inVtx(src1).w >= env.zNear ) then
            otVtx(dsti).x = inVtx(src1).x
            otVtx(dsti).y = inVtx(src1).y
            otVtx(dsti).z = inVtx(src1).z
            otVtx(dsti).w = inVtx(src1).w
            otUV(dsti).u = inUV(src1).u
            otUV(dsti).v = inUV(src1).v
            
            dsti = dsti + 1 
            
            if ( inVtx(src2).w >= env.zNear ) then
                goto continuenfa
            end if
        else
            if ( inVtx(src2).w < env.zNear ) then
                goto continuenfa
            end if
        end if

        scl = ((env.zNear - inVtx(src1).w) / (inVtx(src2).w - inVtx(src1).w))
     
        otVtx(dsti).x = inVtx(src1).x + (inVtx(src2).x-inVtx(src1).x)*scl
        otVtx(dsti).y = inVtx(src1).y + (inVtx(src2).y-inVtx(src1).y)*scl
        otVtx(dsti).z = inVtx(src1).z
        otVtx(dsti).w = env.zNear        
        otUV(dsti).u = inUV(src1).u + (inUV(src2).u-inUV(src1).u)*scl
        otUV(dsti).v = inUV(src1).v + (inUV(src2).v-inUV(src1).v)*scl
    
        dsti = dsti + 1
        
continuenfa:        
    next n
    
    otCnt = dsti
    if ( otCnt < 3 ) then exit sub
    dsti = 0
    
    for  n = 0 to otCnt-1
        src1 = n
        src2 = (n + 1) mod otCnt
        
        if ( otVtx(src1).w <= env.zFar ) then
            inVtx(dsti).x = otVtx(src1).x
            inVtx(dsti).y = otVtx(src1).y
            inVtx(dsti).z = otVtx(src1).z
            inVtx(dsti).w = otVtx(src1).w
            inUV(dsti).u = otUV(src1).u
            inUV(dsti).v = otUV(src1).v
            
            dsti = dsti + 1 
            
            if ( otVtx(src2).w <= env.zFar ) then
                goto continuenfb
            end if
        else
            if ( otVtx(src2).w > env.zFar ) then
                goto continuenfb
            end if
        end if

        scl = ((env.zFar - otVtx(src1).w) / (otVtx(src2).w - otVtx(src1).w))
     
        inVtx(dsti).x = otVtx(src1).x + (otVtx(src2).x-otVtx(src1).x)*scl
        inVtx(dsti).y = otVtx(src1).y + (otVtx(src2).y-otVtx(src1).y)*scl
        inVtx(dsti).z = otVtx(src1).z
        inVtx(dsti).w = env.zFar        
        inUV(dsti).u = otUV(src1).u + (otUV(src2).u-otUV(src1).u)*scl
        inUV(dsti).v = otUV(src1).v + (otUV(src2).v-otUV(src1).v)*scl
    
        dsti = dsti + 1
        
continuenfb:
    next n
    
    otCnt = dsti    
    
end sub



'':::::::::
defint a-z
function initFont% ( flname as string, colb as long )
    dim col as long
    dim trn as long
    dim fHndl as integer
    dim char(3) as integer
    
    dim file as UAR
    dim idstr as string * 4
    
    trn = uglColor8( 7, 0, 3 )    
    
    if ( not uglNewMult( hFontChar(), 256, UGL.EMS, env.cfmt, 8, 8 ) ) then
        initFont% = 0
        exit function
    end if        

    
    if ( uarOpen( file, flname, F4READ ) = false ) then
        initFont% = 0
        exit function
    end if

    
    ''
    '' Check id
    ''
    if ( uarReadEx( file, idstr, 4 ) <> 4 ) then
        initFont% = 0
        exit function
    end if    
    
    
    'if ( idstr <> "font" ) then
    '    initFont% = 0
    '    exit function        
    'end if
    
        
    
    for  i = 0 to 255
        if ( uarReadEx( file, char(0), 4*2 ) <> 4*2 ) then
            initFont% = 0
            exit function
        end if
        
        bit = 0
        
        for y = 0 to 7
            for  x = 0 to 7
                if ( char(bit\16) and bitarray(15-bit and 15) ) then
                    col = colb
                else
                    col = trn                         
                end if
                
                uglPset hFontChar(i), x, y, col
                
                bit = bit + 1
            next x
        next y
    next i
    
    uarClose file
    initFont% = -1
end function


'':::::::::
defint a-z
sub fontPrintText ( dc as long, x as integer, y as integer, _
                    text as string )
    dim posx as integer
    
    posx = x
    
    for  i = 0 to len( text )-1
    
        char = asc( mid$( text, i+1 ) )
        
        if ( (char >= 0) or (char <= 255) ) then
            uglPutMsk dc, posx, y, hFontChar(char)        
        end if
    
        posx = posx + 4
    next i
    
end sub


'':::::::::
defint a-z
function NodesToLeaf% ( p as u3dVector3f, nodenr as integer )

    count = 0

    '' Find the node that the camera is in
    ''
    while not ( nodenr and &h8000 )
        dp! = p.x*plnBuffer(ndsBuffer(nodenr).planeid).norm.x + _
              p.y*plnBuffer(ndsBuffer(nodenr).planeid).norm.z + _
              p.z*plnBuffer(ndsBuffer(nodenr).planeid).norm.y - _
              plnBuffer(ndsBuffer(nodenr).planeid).dist             
    
        if ( dp! > 0.0 ) then
            nodenr = ndsBuffer(nodenr).child0
        else
            nodenr = ndsBuffer(nodenr).child1
        end if
        
        count = count + 1        
    wend
    
    NodesToLeaf% = count
    
end function


'' :::::::::::
'' name: getSBSettings
'' desc: Parse the BLASTER enviroment variable
''
'' :::::::::::
defint a-z
sub getSBSettings  ( port as integer, irq as integer, ldma as integer, _    
                     hdma as integer )
    
    dim tmpstr as string
    dim sbvstr as string
    dim strpos as integer
    dim currChar as string
                         
    port = false
    irq  = false
    ldma = false
    hdma = false
    strpos = 1
    
    ''
    '' Get BLASTER variable
    ''
    sbvstr = environ$( "BLASTER" )
    if ( sbvstr = "" ) then exit sub
    
    
    ''
    '' Parse it
    ''
    while ( strpos <= len( sbvstr ) )
    
        currChar = mid$( sbvstr, strpos, 1 )              
        
        select case ( currChar )            
            case "A", "a"
                tmpstr = "&h" + mid$( sbvstr, strpos+1, 3 )
                port = val( tmpstr )
                strpos = strpos + 4
                
            case "I", "i"
                tmpstr = mid$( sbvstr, strpos+1, 2 )
                irq = val( tmpstr )
                strpos = strpos + 2
                
            case "D", "d"
                tmpstr = mid$( sbvstr, strpos+1, 1 )
                ldma = val( tmpstr )
                strpos = strpos + 2
                
            case "H", "h"
                tmpstr = mid$( sbvstr, strpos+1, 1 )
                hdma = val( tmpstr )
                strpos = strpos + 2                
            
            case else
                strpos = strpos + 1
        end select        
    wend   
    
end sub