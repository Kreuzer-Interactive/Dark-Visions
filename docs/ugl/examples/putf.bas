''
'' putf.bas -- flipped bitmap drawing ex
''

DefInt A-Z
'$Include: '..\inc\ugl.bi'

Const xRes = 320
Const yRes = 200
Const cFmt = UGL.8BIT

Const bmpW = 32
Const bmpH = 32

Declare Sub ExitError (msg As String)

'':::
    Dim video As Long
    Dim bmp As Long
    
    '' initialize
    If (Not uglInit) Then ExitError "Init"
    
    '' change video-mode
    video = uglSetVideoDC(cFmt, xRes, yRes, 1)
    If (video = 0) Then ExitError "SetVideoDC"

    '' allocate the bitmap
    bmp = uglNew(UGL.MEM, cFmt, bmpW, bmpH)
    If (bmp = 0) Then
        ExitError "New bmp"
    End If

    colors& = uglColors(cFmt)

    '' fill the bitmap
    For y = 0 To bmpH \ 2 - 1
        uglHLine bmp, 0, y, bmpW - 1, Rnd * colors&
    Next y
    For x = 0 To bmpW - 1
        uglVLine bmp, x, bmpW \ 2, bmpW - 1, Rnd * colors&
    Next x
    uglRect bmp, 0, 0, bmpW - 1, bmpH - 1, Rnd * colors&
        
    For y = 0 To yRes \ bmpH - 1
        For x = 0 To xRes \ bmpW - 1
            Select Case  (x And 3)
            Case 0
                uglPut video, x * bmpW, y * bmpH, bmp
            Case 1
                uglPutFlip video, x * bmpW, y * bmpH, UGL.VFLIP, bmp
            Case 2
                uglPutFlip video, x * bmpW, y * bmpH, UGL.HFLIP, bmp
            Case 3
                uglPutFlip video, x * bmpW, y * bmpH, UGL.VHFLIP, bmp
            End Select
        Next x
    Next y

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

