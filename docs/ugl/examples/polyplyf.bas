''
'' polyplyf.bas -- filled polygons drawing ex
''

DefInt A-Z
'$Include: '..\inc\ugl.bi'

Const MAXPOINTS   = 3+1
Const MAXPOLYGONS = 1+5

Const xRes = 320'*2
Const yRes = 200'*2
Const cFmt = UGL.8BIT

Declare Sub ExitError (msg As String)

'':::
    Dim video As Long
    Dim pnt(0 to (MAXPOINTS*MAXPOLYGONS)-1) As PNT2D
    Dim cnt(0 to MAXPOLYGONS-1) As Integer
    
    '' initialize
    If (Not uglInit) Then ExitError "Init"
    
    '' change video-mode
    video = uglSetVideoDC(cFmt, xRes, yRes, 1)
    If (video = 0) Then ExitError "SetVideoDC"

    Randomize Timer
    Do
        i = 0
        polygons = 1 + int(Rnd * (MAXPOLYGONS-1))
        For p = 0 to polygons-1
            cnt(p) = 3 + int(Rnd * (MAXPOINTS-3))
            '' create the polygon
            For j = 1 To cnt(p)
                pnt(i).x = Cint(Rnd * xRes)
                pnt(i).y = Cint(Rnd * yRes) 
                i = i + 1
            Next j
        Next p

        '' show it
        uglClear video, 0
        uglPolyPolyF video, pnt(0), cnt(0), i, polygons, _
        			 Rnd * uglColors(cFmt)

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
