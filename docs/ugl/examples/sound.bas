''
'' sound.bas - UGL sound module example
'' note: You always have to include dos.bi and arch.bi
'' before including snd.bi
''
defint a-z
'$include: '..\inc\ugl.bi'
'$include: '..\inc\dos.bi'
'$include: '..\inc\arch.bi'
'$include: '..\inc\snd.bi'
'$include: '..\inc\kbd.bi'


const true      = -1
const false     =  0
const MAXVOICES = 32

declare sub doInit ( )
declare sub doMain ( )
declare sub doEnd  ( )
declare sub ExitError ( msg as string )
declare sub getSBSettings  ( port as integer, irq as integer, _
                             ldma as integer, hdma as integer )


dim shared kbd as TKBD
dim shared sample( 4 ) as long
dim shared voices( MAXVOICES-1 ) as sndvoice


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
    print "_ - [ O P E N I N G ] - _"
    if ( sndOpenOutput( snd.s16.stereo, 44100, 50 ) = false ) then
        if ( sndOpenOutput( snd.s8.stereo, 22050, 50 ) = false ) then
            if ( sndOpenOutput( snd.s8.mono, 22050, 50 ) = false ) then
                ExitError "0x0003, Could not open sound output..."
            end if
        end If
    else
        print " ok..."
    end if   
    
    
    ''
    '' Load samples
    ''
    print 
    print "_ - [L O A D I N G] - _"
    
    for  i = 0 to 4
        print " Loading " + "data\sfx\sample" + chr$( asc("a")+i ) + ".wav, ";
        sample(i) = sndNewWav( snd.ems, "data\sfx\sample" + chr$( asc("a")+i ) + ".wav" )
        
        if ( sample(i) = false ) then
            print "failed"
        else
            print "ok"
        end if
    next i 
    
    
    ''
    '' Init voices
    ''
    for  i = 0 to MAXVOICES-1
        sndVoiceSetDefault voices(i)
    next i
    
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

    print
    print "_ - [P R E S S  K E Y S  1 - 5] - _"    
    
    do
        if ( kbd.one ) then
            sndPlay voices(0), sample(0)
            while ( kbd.one )
            wend
        end if
        
        if ( kbd.two ) then
            sndPlay voices(1), sample(1)
            while ( kbd.two )
            wend
        end if
        
        if ( kbd.three ) then
            sndPlay voices(2), sample(2)
            while ( kbd.three )
            wend
        end if        
        
        if ( kbd.four ) then
            sndPlay voices(3), sample(3)
            while ( kbd.four )
            wend
        end if
        
        if ( kbd.five ) then
            sndPlay voices(4), sample(4)
            while ( kbd.five )
            wend
        end if
        
    loop until ( kbd.esc or kbd.q or kbd.x )
        
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



    

