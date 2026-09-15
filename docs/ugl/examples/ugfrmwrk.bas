''
''  ugfrmwrk.bas - UGL template
''                 Best viewed in a text editor and NOT qb's IDE.
''
''         Note:   Add your code in the doMain sub where it says
''                 Your code here. This template automatically clears
''                 the screen. And as for the destination DC you use 
''                 Env.hVideoDC.
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
    Keyboard    as TKBD
    FPS         as single
    ViewPage    as integer
    WorkPage    as integer
end type


declare sub doMain      ( )
declare sub doInit      ( )
declare sub doEnd       ( )
declare sub ExitError   ( msg as string )


    '' Your code goes in doMain ( )
    
    dim shared Env as EnvType
    
    doInit
    doMain
    doEnd
    
    

defint a-z
sub ExitError ( msg as string )

    ''
    '' Terminate UGL
    ''
    kbdEnd
    uglRestore
    uglEnd
    
    ''
    '' Print error message
    '' and end
    ''
    print "Error: " + msg
    end
    
end sub


defint a-z
sub doInit

    ''
    '' Init UGL
    ''
    if ( uglInit = FALSE ) then 
        ExitError "0x0000, UGL init failed..."
    end if        
    
    
    ''
    '' Set video mode with x pages where
    '' x = PAGES
    ''
    Env.hVideoDC = uglSetVideoDC( cFmt, xRes, yRes, PAGES )
    if ( Env.hVideoDC = FALSE ) then ExitError "0x0001, Could not set video mode..."
    
    
    ''
    '' Init keyboard handler
    ''
    kbdInit Env.Keyboard
    
    ''
    '' Anything else
    ''
    
end sub


defint a-z
sub doEnd

    ''
    '' Terminate UGL
    ''
    kbdEnd
    uglRestore
    uglEnd
    
    ''
    '' Print FPS
    ''
    cls    
    print "Frames per second:" + str$( cint(Env.FPS) )    
        
end sub


defint a-z
sub doMain    
    static frmCounter as single
    static tmrIni as single, tmrEnd as single
   

    tmrIni = timer
    frmCounter = 0

    do
        ''
        '' Wait for vsync
        ''
        wait &h3da, 8
        
        ''
        '' Page flipping
        ''
        uglSetVisPage Env.ViewPage
        uglSetWrkPage Env.WorkPage
        
        ''
        '' Clear screen 
        ''
        uglClear Env.hVideoDC, 0
        
        
        ''
        '' -= Your code here =-
        ''        
        
        
        ''
        '' Update frame counter etc
        ''
        frmCounter   = frmCounter + 1.0!
        Env.ViewPage = Env.WorkPage        
        Env.WorkPage = (Env.WorkPage+1) mod PAGES
        
    loop until ( Env.Keyboard.Esc )
    
    tmrEnd = timer    
    Env.FPS = frmCounter / (tmrEnd-tmrIni)    
        
end sub