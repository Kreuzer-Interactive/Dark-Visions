''
'' putm.bas -- sprite drawing ex
''

DefInt A-Z
'$Include: '..\inc\ugl.bi'

Const xRes = 320
Const yRes = 200
Const cFmt = UGL.8BIT

Const SPRITES = 16
Const bmpW = 32
Const bmpH = 32

Declare Sub ExitError (msg As String)

'':::
    Dim video As Long
    Dim sprite(0 to SPRITES-1) As Long
    
    '' initialize
    If (Not uglInit) Then ExitError "Init"
    
    '' change video-mode
    video = uglSetVideoDC(cFmt, xRes, yRes, 1)
    If (video = 0) Then ExitError "SetVideoDC"

    colors& = uglColors(cFmt)

    '' allocate the sprites
    If (Not uglNewMult(sprite(), SPRITES, UGL.MEM, cFmt, bmpW, bmpH)) Then
        ExitError "New sprites"
    End If

    '' fill the sprites
    For i = 0 To SPRITES-1
        uglClear sprite(i), uglColor(cFmt,255,0,255)
        For y = 0 To bmpH-1
            uglHLine sprite(i), Rnd * (bmpW-1), y, Rnd * (bmpW-1), _
            		 Rnd * colors&
        Next y
        uglRect sprite(i), 0, 0, bmpW-1, bmpH-1, Rnd * colors&
    Next i

    '' show them
    Do
        For i = 0 To 255
            uglPutMsk video, _
                      -bmpW\2 + Rnd * (xRes+bmpW\2), _
                      -bmpH\2 + Rnd * (yRes+bmpH\2), _
                      sprite(Rnd * (SPRITES-1))
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
