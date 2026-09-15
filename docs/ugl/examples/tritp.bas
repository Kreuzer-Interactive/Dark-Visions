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
dim a as single, s as single
dim ka as single, ks as single
dim i as integer
dim hVideoDC as long
dim hBackBDC as long
dim hTextrDC as long
dim mytri(3) as TriType
dim mypal(255) as tRGB



    
    
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
    mytri(0).v1.x = -16
    mytri(0).v1.y = -16
    mytri(0).v1.z = 1.0 / 1.0
    mytri(0).v1.u = 0.0 * mytri(0).v1.z
    mytri(0).v1.v = 0.0 * mytri(0).v1.z

    mytri(0).v2.x = +16
    mytri(0).v2.y = -16
    mytri(0).v2.z = 1.0 / 1.0
    mytri(0).v2.u = 1.0 * mytri(0).v2.z
    mytri(0).v2.v = 0.0 * mytri(0).v2.z
    
    mytri(0).v3.x = +16
    mytri(0).v3.y = +16
    mytri(0).v3.z = 1.0 / 1.0
    mytri(0).v3.u = 1.0 * mytri(0).v3.z
    mytri(0).v3.v = 1.0 * mytri(0).v3.z
    
    mytri(1).v1.x = -16
    mytri(1).v1.y = -16
    mytri(1).v1.z = 1.0 / 1.0
    mytri(1).v1.u = 0.0 * mytri(1).v1.z
    mytri(1).v1.v = 0.0 * mytri(1).v1.z

    mytri(1).v2.x = +16
    mytri(1).v2.y = +16
    mytri(1).v2.z = 1.0 / 1.0
    mytri(1).v2.u = 1.0 * mytri(1).v2.z
    mytri(1).v2.v = 1.0 * mytri(1).v2.z
    
    mytri(1).v3.x = -16
    mytri(1).v3.y = +16
    mytri(1).v3.z = 1.0 / 1.0
    mytri(1).v3.u = 0.0 * mytri(1).v3.z
    mytri(1).v3.v = 1.0 * mytri(1).v3.z    
        
    ''
    '' Draw the triangle
    ''
    a = 0
    s = 0.1
    ka = 1.00
    ks = 0.001
    
    do
        k = inkey$
        
        uglClear hBackBDC, -1
        
        if ( k = "a" ) then
            a = a + ka
        end if            
        
        s = s + ks
        
        if ( a > 360.0 ) then a = a - 360.0
        if ( s < 0.1   ) then ks = -ks
        if ( s > 12.0   ) then ks = -ks
        
        rotateTri mytri(2), a, s, xres\2, yres\2, mytri(0)
        rotateTri mytri(3), a, s, xres\2, yres\2, mytri(1)
        uglTriTP hBackBDC, mytri(2), ugl.mask.false, hTextrDC
        uglTriTP hBackBDC, mytri(3), ugl.mask.false, hTextrDC        
        uglPut hVideoDC, 0, 0, hBackBDC
    loop until ( k = chr$( 27 ) )
    
    
    
    ''
    '' Wait for input and end
    ''    
    uglRestore
    uglEnd
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

    dst.v1.u = src.v1.u
    dst.v1.v = src.v1.v
    dst.v1.z = src.v1.z
    
    dst.v2.u = src.v2.u
    dst.v2.v = src.v2.v
    dst.v2.z = src.v2.z
    
    dst.v3.u = src.v3.u
    dst.v3.v = src.v3.v
    dst.v3.z = src.v3.z        
    
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