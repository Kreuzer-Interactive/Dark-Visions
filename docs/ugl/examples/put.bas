''
'' put.bas -- bitmap drawing ex
''

DefInt A-Z
'$Include: '..\inc\ugl.bi'

Const xRes = 320
Const yRes = 200
Const cFmt = UGL.8BIT

Const BMPS = 64
Const bmpW = 32
Const bmpH = 32

Declare Sub ExitError (msg As String)

'':::
    Dim video As Long
    Dim bmp(0 to BMPS-1) As Long
    
    '' initialize
    If (Not uglInit) Then ExitError "Init"
    
    '' change video-mode
    video = uglSetVideoDC(cFmt, xRes, yRes, 1)
    If (video = 0) Then ExitError "SetVideoDC"

    '' allocate the bitmaps
    If (Not uglNewMult(bmp(), BMPS, UGL.MEM, cFmt, bmpW, bmpH)) Then 
        ExitError "New bmps"
    End If

    colors& = uglColors(cFmt)

    '' fill the bitmaps
    For i = 0 To BMPS-1
        For y = 0 To bmpH-1
            uglHLine bmp(i), 0, y, bmpW-1, Rnd * colors&
        Next y
        uglRect bmp(i), 0, 0, bmpW-1, bmpH-1, Rnd * colors&
    Next i

    Do
        For i = 0 To 255
            uglPut video, _
                   -bmpW\2 + Rnd * (xRes+bmpW\2), _
                   -bmpH\2 + Rnd * (yRes+bmpH\2), _
                   bmp(Rnd * (BMPS-1))
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
