''
''  putrotm.bas - Using uglPutRotMsk to rotate DCs
''                 
''
''

defint a-z
'$include: '..\inc\ugl.bi'
'$include: '..\inc\kbd.bi'
'$include: '..\inc\font.bi'

const xRes = 320
const yRes = 200
const cFmt = UGL.16BIT
const FALSE = 0
const PAGES = 2


type EnvType    
    hFont       as long
    hVideoDC    as long
    hTextrDC    as long
    Keyboard    as TKBD
    FPS         as single
    ViewPage    as integer
    WorkPage    as integer
end type


declare sub doMain      ( )
declare sub doInit      ( )
declare sub doTerminate ( )
declare sub ExitError   ( msg as string )


    '' Your code goes in doMain ( )
    
    dim shared Env as EnvType
    
    doInit
    doMain
    doTerminate
    
    

defint a-z
sub ExitError ( msg as string )

    '' Terminate UGL
    '
    kbdEnd
    uglRestore
    uglEnd
    
    '' Print error message
    '' and end
    '
    print "Error: " + msg
    end
    
end sub


defint a-z
sub doInit

    '' Init UGL
    ''
    if ( uglInit = FALSE ) then 
        ExitError "0x0000, UGL init failed..."
    end if        
    
    
    '' Set video mode with x pages where
    '' x = PAGES
    ''
    Env.hVideoDC = uglSetVideoDC( cFmt, xRes, yRes, PAGES )
    if ( Env.hVideoDC = FALSE ) then ExitError "0x0001, Could not set video mode..."
    
    
    '' Init keyboard handler
    ''
    kbdInit Env.Keyboard
    
    
    '' Load UGL logo
    Env.hTextrDC = uglNewBMP( UGL.MEM, cFmt, "data/ugl.bmp" )
    if ( Env.hTextrDC = FALSE ) then ExitError "0x0002, Could not load data/ugl.bmp..."    
    
end sub


defint a-z
sub doTerminate

    '' Terminate UGL
    ''
    kbdEnd
    uglRestore
    uglEnd
    
    '' Print FPS
    cls    
    print "Frames per second:" + str$( cint(Env.FPS) )    
        
end sub


defint a-z
sub doMain    
    static angle as single
    static frmCounter as single    
    static tmrIni as single, tmrEnd as single
        

    tmrIni = timer
    frmCounter = 0

    do
        '' Wait for vsync
        'wait &h3da, 8
        
        '' Page flipping        
        'uglSetVisPage Env.ViewPage
        'uglSetWrkPage Env.WorkPage
        
        '' Clear screen 
        'uglClear Env.hVideoDC, -1
        
        
        '' Rotate DC
        uglPutMskRot Env.hVideoDC, (xRes-128)/2, (yRes-128)/2, angle, Env.hTextrDC
        
        
        if ( Env.keyboard.p = FALSE ) then
            angle = angle + 1.5
            
            if ( angle >= 360.0 ) then 
                angle = 0
            end if            
        end if
        
        
        '' Update some frame counter
        '' etc etc        
        frmCounter   = frmCounter + 1.0!
        Env.ViewPage = Env.WorkPage        
        Env.WorkPage = (Env.WorkPage+1) mod PAGES
        
    loop until ( Env.Keyboard.Esc )
    
    tmrEnd = timer    
    Env.FPS = frmCounter / (tmrEnd-tmrIni)    
        
end sub
