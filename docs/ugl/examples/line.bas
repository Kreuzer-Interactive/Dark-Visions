''
'' line.bas -- line drawing ex
''

DefInt A-Z
'$Include: '..\inc\ugl.bi'

Const xRes = 320
Const yRes = 200
Const cFmt = UGL.8BIT

Declare Sub ExitError (msg As String)

'':::
    Dim video As Long
    
    '' initialize
    If (Not uglInit) Then ExitError "Init"
    
    '' change video-mode
    video = uglSetVideoDC(cFmt, xRes, yRes, 1)
    If (video = 0) Then ExitError "SetVideoDC"
    
    colors& = uglColors(cFmt)
    Do
        For i = 0 To 999
            uglLine video, Rnd*xRes, Rnd*yRes, _
                           Rnd*xRes, Rnd*yRes, _
                           Rnd * colors&
        Next i
    Loop While (Inkey$ = "")

    uglRestore
    uglEnd
    End

'':::
Sub ExitError (msg As String)
    uglRestore
    uglEnd
    Print "ERROR! "; msg
    End
End Sub
