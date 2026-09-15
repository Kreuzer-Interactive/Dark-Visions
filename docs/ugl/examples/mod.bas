''
'' sound.bas - UGL music module example
'' note: You always have to include dos.bi and arch.bi
'' before including snd.bi
''
defint a-z
'$include: '..\inc\ugl.bi'
'$include: '..\inc\dos.bi'
'$include: '..\inc\arch.bi'
'$include: '..\inc\snd.bi'
'$include: '..\inc\mod.bi'
'$include: '..\inc\kbd.bi'
'$include: '..\inc\tmr.bi'


const true      = -1
const false     =  0

declare sub doInit ( )
declare sub doMain ( )
declare sub doEnd  ( )
declare sub ExitError ( msg as string )
declare sub getSBSettings  ( port as integer, irq as integer, _
                             ldma as integer, hdma as integer )

dim shared kbd   as TKBD
dim shared mymod as UGMMOD

    doInit
    doMain
    doEnd
    
    

'' :::::::::::
'' name: doInit 
'' desc: Inits everything
''
'' :::::::::::
defint a-z
sub doInit
    dim i as integer
    dim port as integer, irq as integer
    dim ldma as integer, hdma as integer
        
    
    ''
    '' Init UGL
    ''
    if ( uglInit = false ) then
        ExitError "0x0000, Could not init UGL..."
    end if
  
    
    ''
    '' Try to autodetect (sb16 only), if that doesn't work
    '' we will try to get the sb settings from the BLASTER
    '' variable. If that doesn't work either there either
    '' isn't a sound blaster or the user needs to set it up.
    ''
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
                ExitError "0x0003, Could not open sound output..."
            end if
        end if        
    end if
    
    ''
    '' Init mod module
    ''
    if ( modInit = false ) then
        ExitError "0x0004, Could not load mod module..."
    end if
    
    ''
    '' Load mod
    ''
    if ( modNew( mymod, mod.ems, command$ ) = false ) then
        ExitError "0x0005, Could not load mod..."
    end if    

   
    ''
    '' Init keyboard handler
    ''
    kbdInit kbd
       
    
end sub



'' :::::::::::
'' name: doMain 
'' desc: 
''
'' :::::::::::
defint a-z
sub doMain    

    cls	
    modPlay mymod
    modSetPlayMode mymod, mod.repeat
    
    locate 3, 1
    print "This song is playing in the background..."

    
    
    do    
        locate 1, 1
        print "Play state:" + str$( modGetPlayState )
        print "Current volume:" + str$( modGetVolume ) + "    "
        
        
        if ( kbd.p ) then
            modPause
            print "Mod paused"
            while ( kbd.p )
            wend
        end if
        
        if ( kbd.r ) then
            modResume
            print "Mod resumed"
            while ( kbd.r )
            wend            
        end if
        
        if ( kbd.o ) then
            modFadeOut 200
            while ( kbd.o )
            wend            
        end if
        
        if ( kbd.i ) then
            modFadeIn 200
            while ( kbd.i )
            wend            
        end if                
        
        if ( kbd.plus ) then            
            modSetVolume modGetVolume+1
            while ( kbd.plus )
            wend
        end if
        
        if ( kbd.min ) then            
            modSetVolume modGetVolume-1
            while ( kbd.min )
            wend
        end if        
                
    loop until ( kbd.esc or kbd.q or kbd.x or (modGetPlayState = mod.stopped) )
        
end sub



'' :::::::::::
'' name: doEnd
'' desc: Clean up and end
''
'' :::::::::::
defint a-z
sub doEnd    

    uglEnd
    end
    
end sub



'' :::::::::::
'' name: ExitError
'' desc: Exit with an error
''
'' :::::::::::
defint a-z
sub ExitError ( msg as string )
    
    print "Error: " + msg
    uglEnd
    end
    
end sub



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



    

