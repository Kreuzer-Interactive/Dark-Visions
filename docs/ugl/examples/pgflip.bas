''
'' pgflip.bas -- page flipping ex
''

DefInt a-z
'$Include: '..\inc\ugl.bi'
'$Include: '..\inc\mouse.bi'

Const xRes = 320*2
Const yRes = 200*2
Const cFmt = UGL.8BIT

Declare Sub ExitError (msg As String)

'':::
    Dim video As Long
    Dim mouse As MOUSEINF
    
    '' initialize
    If (not uglInit) Then ExitError "Init"
    
    '' change video-mode
    video = uglSetVideoDC(cFmt, xRes, yRes, 2)
    If (video = 0) Then ExitError "SetVideoDC"
    
    '' try starting mouse driver
    If (Not mouseInit(video, mouse)) Then ExitError "mouseInit"

    
    visPg = 0
    wrkPg = 1
    
    'uglRect video, 32, 32, xRes-1-32, yRes-1-32, -1
    mouseRange 32, 32, xRes-1-32, yRes-1-32
    mousePos xRes\2, yRes\2

    mouseShow    
    
    colors& = uglColors(cFmt)
    iTmr# = timer
    Do
        uglClear video, 0
        For i = 1 To 10
            uglRectF video, Rnd * xRes, Rnd * yRes, _
                            Rnd * xRes, Rnd * yRes, _
                            Rnd * colors&
        Next i
        
        
        mouseHide
        mouseShow
        
        wait &h3da, 8
        uglSetVisPage visPg
        uglSetWrkPage wrkPg
        
        visPg = wrkPg
        wrkPg = (wrkPg+1) mod 2        
                
        fps& = fps& + 1
    Loop While (Inkey$ = "")
    eTmr# = timer
    
    
    mouseEnd
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
