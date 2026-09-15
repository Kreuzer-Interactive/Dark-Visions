''
'' qbez.bas -- quadric bezier curve drawing ex
''

DefInt A-Z
'$Include: '..\inc\ugl.bi'

Const LEVELS = 16

Const xRes = 320
Const yRes = 200
Const cFmt = UGL.8BIT

Declare Sub ExitError (msg As String)

'':::
    Dim video As Long
    Dim curve As QUADBEZ
    
    '' initialize
    If (Not uglInit) Then ExitError "Init"
    
    '' change video-mode
    video = uglSetVideoDC(cFmt, xRes, yRes, 1)
    If (video = 0) Then ExitError "SetVideoDC"
    
    colors& = uglColors(cFmt)
    Do
        curve.a.x = Rnd * xRes: curve.a.y = Rnd * yRes
        curve.b.x = Rnd * xRes: curve.b.y = Rnd * yRes
        curve.c.x = Rnd * xRes: curve.c.y = Rnd * yRes
        uglQuadricBez video, curve, LEVELS, Rnd * colors&
        Do
            kb$ = Inkey$
        Loop While (Len(kb$) = 0)
    Loop Until (Asc(kb$) = 27)

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
