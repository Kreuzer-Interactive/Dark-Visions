''
'' timer.bas -- multiple high-res timers ex
''

Defint A-Z
'$Include: '..\inc\tmr.bi'

    Dim t1 As TMR, t2 As TMR, t3 As TMR, t4 As TMR
    Dim tc as TMR
    
    tmrInit

    tmrNew t1, TMR.ONESHOT, tmrSec2Freq(7)          '' 7secs
    tmrNew t2, TMR.ONESHOT, tmrTick2Freq(91)        '' 5secs
    tmrNew t3, TMR.ONESHOT, tmrUs2Freq(3000000)     '' 3secs
    tmrNew t4, TMR.ONESHOT, tmrMs2Freq(1000)        '' 1sec

    '' show statistics about the above timers 20 times p/ second
    tmrNew tc, TMR.AUTOINIT, tmrMs2Freq(1000 \ 20)

    Cls
    print time$

    Do
        if ( tc.counter > 0 ) then
            tc.counter = 0
            Locate 2, 1
            Print Using "t1> state:& counter:&   "; Hex$(t1.state and 1); Hex$(t1.cnt)
            Print Using "t2> state:& counter:&   "; Hex$(t2.state and 1); Hex$(t2.cnt)
            Print Using "t3> state:& counter:&   "; Hex$(t3.state and 1); Hex$(t3.cnt)
            Print Using "t4> state:& counter:&   "; Hex$(t4.state and 1); Hex$(t4.cnt)            
        end if
    Loop While (t1.state) and (Len(Inkey$) = 0)
     
    print time$

    tmrEnd
    End
