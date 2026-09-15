''
'' pgflip2.bas -- page flipping ex, using more than 2 pages to reach more
''                than 60/70 FPS (no v-retrace checking) without flicking
''

DefInt a-z
'$Include: '..\inc\ugl.bi'

Const pages = 16                                '' will need 2M of VRAM
Const xRes = 320
Const yRes = 200
Const cFmt = UGL.16BIT

Declare Sub ExitError (msg As String)

'':::
    Dim video As Long
    
    '' initialize
    If (not uglInit) Then ExitError "Init"
    
    '' change video-mode
    video = uglSetVideoDC(cFmt, xRes, yRes, pages)
    If (video = 0) Then ExitError "SetVideoDC"
    
    visPg = 0
    wrkPg = 1        
    
    colors& = uglColors(cFmt)
    iTmr# = timer
    Do                
        fps& = fps& + 1
        uglSetVisPage visPg
        uglSetWrkPage wrkPg

        uglClear video, 0
        For i = 1 To 10
            uglRect video, Rnd * xRes, Rnd * yRes, _
                           Rnd * xRes, Rnd * yRes, _
                           Rnd * colors&
        Next i
        
        visPg = wrkPg
        wrkPg = (wrkPg + 1) mod pages
    
    Loop While (Inkey$ = "")
    eTmr# = timer
    
    uglRestore
    uglEnd
    print "fps:"; Clng(fps& / (eTmr#-iTmr#))
    End

'':::
Sub ExitError (msg As String)
    uglRestore
    uglEnd
    Print "ERROR! "; msg
    End
End Sub
