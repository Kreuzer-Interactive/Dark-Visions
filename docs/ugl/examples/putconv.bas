''
'' putconv.bas -- bitmap drawing + color conversion ex
''

DefInt A-Z
'$Include: '..\inc\ugl.bi'

Const xRes = 320
Const yRes = 200
Const cFmt = UGL.8BIT

Const bmpW = 64
Const bmpH = 64

Declare Sub ExitError (msg As String)

'':::
    Dim video As Long
    Dim bmp15 As Long, bmp16 As Long, bmp32 As Long
    
    '' initialize
    If (Not uglInit) Then ExitError "Init"
    
    '' change video-mode
    video = uglSetVideoDC(cFmt, xRes, yRes, 1)
    If (video = 0) Then ExitError "SetVideoDC"

    '' allocate the bitmaps
    bmp15 = uglNew(UGL.MEM, UGL.15BIT, bmpW, bmpH)
    if (bmp15 = 0) then ExitError "15"
    bmp16 = uglNew(UGL.EMS, UGL.16BIT, bmpW, bmpH)
    if (bmp16 = 0) then ExitError "16"
    bmp32 = uglNew(UGL.EMS, UGL.32BIT, bmpW, bmpH)
    if (bmp32 = 0) then ExitError "32"

    colors& = uglColors(UGL.15BIT)

    '' fill the bitmap
    For y = 0 To bmpH-1
        uglHLine bmp15, 0, y, bmpW-1, Rnd * colors&
    Next y
    uglRect bmp15, 0, 0, bmpW-1, bmpH-1, Rnd * colors&

    uglPutConv bmp16, 0, 0, bmp15
    uglPutConv bmp32, 0, 0, bmp16

    uglPutConv video, 0, 0, bmp15
    uglPutConv video, bmpW, bmpH, bmp16
    uglPutConv video, bmpW*2, bmpH*2, bmp32        
    sleep

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
