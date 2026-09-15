''
'' offscr.bas -- off screen buffer ex
''

DefInt a-z
'$Include: '..\inc\ugl.bi'

Const xRes = 320
Const yRes = 200
Const cFmt = UGL.8BIT

Const BMPS = 16
Const bmpW = 32
Const bmpH = 32

Declare Sub ExitError (msg As String)

'':::
    Dim video As Long
    Dim offScrBuff As Long
    Dim bmp(0 To BMPS - 1) As Long
        
    '' initialize
    If (Not uglInit) Then ExitError "Init"
    
    '' change video-mode
    video = uglSetVideoDC(cFmt, xRes, yRes, 1)
    If (video = 0) Then ExitError "SetVideoDC"

    offScrBuff = uglNew(UGL.MEM, cFmt, xRes, yRes)
    If (offScrBuff = 0) Then ExitError "New off screen"

    colors& = uglColors(cFmt)

    '' allocate the bitmaps
    For i = 0 To BMPS - 1
        bmp(i) = uglNew(UGL.MEM, cFmt, bmpW, bmpH)
        If (bmp(i) = 0) Then ExitError "New bmp " + Str$(i)

        '' fill it
        For y = 0 To bmpH - 1
            uglHLine bmp(i), 0, y, bmpW - 1, Rnd * colors&
        Next y
    Next i

    '' fill the off screen buffer
    For y = 0 To yRes - 1 Step bmpH
        For x = 0 To xRes - 1 Step bmpW
            b = Rnd * (BMPS - 1)
            uglPut offScrBuff, x, y, bmp(b)
        Next x
    Next y

    '' copy the off screen buffer to the frame buffer
    uglPut video, 0, 0, offScrBuff

    Sleep
       
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
