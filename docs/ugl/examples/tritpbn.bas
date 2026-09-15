''
'' triglin.bas - Gouraud triangle with a linear palette (8bit)
''
''
defint a-z
'$include: '..\inc\ugl.bi'

const false =  0
const true  = -1

const xres  =  320
const yres  =  200

declare sub ExitWithError ( msg as string ) 
declare sub rotateTri ( dst as tritype, ang as single, scl as single, _
                        cx as integer, cy as integer, src as tritype )
dim k as string
dim a as single
dim i as integer
dim tmrIni as single
dim tmrEnd as single
dim hVideoDC as long
dim hBackBDC as long
dim hTextrDC as long
dim mytri(1) as TriType

    
    
    ''
    '' Init UGL
    ''
    if ( uglInit = false ) then
        ExitWithError "0x0000, Could not init UGL..."
    end if    
    
    ''
    '' Set video mode
    ''    
    hVideoDC = uglSetVideoDC( ugl.8bit, xres, yres, 1 )
    if ( hVideoDC = false ) then
        ExitWithError "0x0001, Could not set video mode..."
    end if
    
    hBackBDC = uglNew( ugl.mem, ugl.8bit, xres, yres )
    if ( hBackBDC = false ) then
        ExitWithError "0x0002, Could not create texture..."
    end if      
    
    ''
    '' Create a dc for texture
    ''
    hTextrDC = uglNew( ugl.mem, ugl.8bit, 64, 64 )
    if ( hTextrDC = false ) then
        ExitWithError "0x0002, Could not create texture..."
    end if
    
    for  y = 0 to 63
        if ( (y mod 4) = 0 ) then
            if ( c = uglColor8( 7, 0, 0 ) ) then
                c = uglColor8( 0, 0, 3 )
            else
                c = uglColor8( 7, 0, 0 )
            end if
        end if
                
        for  x  = 0 to 63
            if ( (x mod 4) = 0 ) then
                if ( c = uglColor8( 7, 0, 0 ) ) then
                    c = uglColor8( 0, 0, 3 )
                else
                    c = uglColor8( 7, 0, 0 )
                end if
            end if
            
            uglPSet hTextrDC, x, y, c
        next x
    next y
   
   'uglClear hTextrDC, -1
    
    ''
    '' Set the triangle coordinates 
    '' The red component in the color is the
    '' color of that edge when using a linear palette    
    ''
    mytri(0).v1.x = 0
    mytri(0).v1.y = 0
    mytri(0).v1.z = 1.0 / 1.0
    mytri(0).v1.u = 0.0 * mytri(0).v1.z
    mytri(0).v1.v = 0.0 * mytri(0).v1.z

    mytri(0).v2.x = xres-1
    mytri(0).v2.y = 0
    mytri(0).v2.z = 1.0 / 1.0
    mytri(0).v2.u = 1.0 * mytri(0).v2.z
    mytri(0).v2.v = 0.0 * mytri(0).v2.z
    
    mytri(0).v3.x = 0
    mytri(0).v3.y = yres-1
    mytri(0).v3.z = 1.0 / 1.0
    mytri(0).v3.u = 0.0 * mytri(0).v3.z
    mytri(0).v3.v = 1.0 * mytri(0).v3.z
    
    mytri(1).v1.x = xres-1
    mytri(1).v1.y = 0
    mytri(1).v1.z = 1.0 / 1.0
    mytri(1).v1.u = 1.0 * mytri(1).v1.z
    mytri(1).v1.v = 0.0 * mytri(1).v1.z

    mytri(1).v2.x = xres-1
    mytri(1).v2.y = yres-1
    mytri(1).v2.z = 1.0 / 1.0
    mytri(1).v2.u = 1.0 * mytri(1).v2.z
    mytri(1).v2.v = 1.0 * mytri(1).v2.z
    
    mytri(1).v3.x = 0
    mytri(1).v3.y = yres-1
    mytri(1).v3.z = 1.0 / 1.0
    mytri(1).v3.u = 0.0 * mytri(1).v3.z
    mytri(1).v3.v = 1.0 * mytri(1).v3.z    
        
    ''
    '' Draw the triangle
    ''
    tmrIni = timer
    for  i = 0 to 499
        uglTriTP hBackBDC, mytri(0), ugl.mask.false, hTextrDC
        uglTriTP hBackBDC, mytri(1), ugl.mask.false, hTextrDC
    next i
    tmrEnd = timer
    
            
    ''
    '' Wait for input and end
    '' 
    uglPut hVideoDC, 0, 0, hBackBDC
    sleep       
    uglRestore
    uglEnd
    
    cls
    width 80, 25
    print "Clocks per pixel :" + str$( 1900#*1000000#/(64000#*500#/(tmrEnd-tmrIni)) )
    print "Pixels per second:" + str$( 64000#*500#/(tmrEnd-tmrIni) )
    end
    


'' :::::::::::::
'' name: rotateTri
'' desc: The name says it all
''
'' :::::::::::::
sub rotateTri ( dst as tritype, ang as single, scl as single, _
                cx as integer, cy as integer, src as tritype )
    dim c as single
    dim s as single
    
    c = cos( ang * 3.1415926 / 180.0 ) * scl
    s = sin( ang * 3.1415926 / 180.0 ) * scl
    
    dst.v1.x = src.v1.x*c - src.v1.y*s + cx
    dst.v1.y = src.v1.y*c + src.v1.x*s + cy
    dst.v2.x = src.v2.x*c - src.v2.y*s + cx
    dst.v2.y = src.v2.y*c + src.v2.x*s + cy
    dst.v3.x = src.v3.x*c - src.v3.y*s + cx
    dst.v3.y = src.v3.y*c + src.v3.x*s + cy    
    
end sub


'' :::::::::::::
'' name: ExitWithError
'' desc: The name says it all
''
'' :::::::::::::
defint a-z    
sub ExitWithError ( msg as string )
    
    ''
    '' Restore video mode and deinit ugl
    ''
    uglRestore
    uglEnd
    
    ''
    '' Print error message and quit
    ''
    cls
    width 80, 25
    print "Error: " + msg
    end

end sub