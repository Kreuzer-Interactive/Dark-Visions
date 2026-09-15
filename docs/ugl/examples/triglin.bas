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

dim i as integer
dim hVideoDC as long
dim mytri as TriType
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
    
    
    ''
    '' Set up a linear palette
    ''
    uglPalUsingLin true
    
    for  i = 0 to 255
        mypal(i).red   = chr$( 0 )
        mypal(i).green = chr$( i )
        mypal(i).blue  = chr$( 0 )
    next i
    
    uglPalSetBuff 0, 256, mypal(0)
    
    
    ''
    '' Set the triangle coordinates 
    '' The red component in the color is the
    '' color of that edge when using a linear palette    
    ''
    mytri.v1.x = xres\2
    mytri.v1.y = yres\2-50
    mytri.v1.r = 0.2

    mytri.v2.x = xres\2+50
    mytri.v2.y = yres\2+50
    mytri.v2.r = 1.0
    
    mytri.v3.x = xres\2-50
    mytri.v3.y = yres\2+50
    mytri.v3.r = 1.0
    
    ''
    '' Draw the triangle
    ''
    uglTriG hVideoDC, mytri
    
    
    ''
    '' Wait for input and end
    ''
    sleep
    uglRestore
    uglEnd
    end
    

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