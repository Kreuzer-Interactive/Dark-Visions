''
'' poly.bas -- outlined polygon drawing ex
''

DefInt A-Z
'$Include: '..\inc\ugl.bi'

Const POINTS = 15

Const xRes = 320'*2
Const yRes = 200'*2
Const cFmt = UGL.8BIT

Declare Sub ExitError (msg As String)

'':::
    Dim video As Long
    Dim pnt( 0 to POINTS-1 ) As PNT2D
    
    '' initialize
    If ( Not uglInit ) Then ExitError "Init"
    
    '' change video-mode
    video = uglSetVideoDC(cFmt, xRes, yRes, 1)
    If ( video = 0 ) Then ExitError "SetVideoDC"

    Randomize Timer
    Do
        '' create the polygon
        For i = 0 To POINTS-1
            pnt(i).x = Cint( Rnd * xRes )
            pnt(i).y = Cint( Rnd * yRes )
        Next i

        '' show it
        uglClear video, 0
        uglPoly video, pnt(0), POINTS, Clng( Rnd * uglColors( cFmt ) )

        Do
            kb$ = Inkey$
        Loop While ( Len( kb$ ) = 0 )
    Loop Until ( Asc( kb$ ) = 27 )

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
