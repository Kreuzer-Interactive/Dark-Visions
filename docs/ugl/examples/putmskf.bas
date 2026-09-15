''
'' putmskf.bas -- flipped sprite drawing ex
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
    Dim sprite As Long
    
    '' initialize
    If (Not uglInit) Then ExitError "Init"
    
    '' change video-mode
    video = uglSetVideoDC(cFmt, xRes, yRes, 1)
    If (video = 0) Then ExitError "SetVideoDC"

    '' allocate the sprite
    sprite = uglNew(UGL.MEM, cFmt, bmpW, bmpH)
    If (sprite = 0) Then
        ExitError "New sprite"
    End If

    colors& = uglColors(cFmt)

    '' fill the sprite
    uglClear sprite, uglColor(cFmt,255,0,255)
    For y = 0 To bmpH\2-1
        uglHLine sprite, Rnd * (bmpW-1), y, Rnd * (bmpW-1), Rnd * colors&
    Next y
    For x = 0 To bmpW-1
        uglVLine sprite, x, bmpH\2+Rnd*(bmpH\2-1), bmpH\2+Rnd*(bmpH\2-1), _
                 Rnd * colors&
    Next x
    uglRect sprite, 0, 0, bmpW-1, bmpH-1, Rnd * colors&
        
    For y = 0 To yRes \ bmpH - 1
        For x = 0 To xRes \ bmpW - 1
            Select Case (x And 3)
                Case 0
                    uglPutMsk video, x * bmpW, y * bmpH, sprite
                Case 1
                    uglPutMskFlip video, x * bmpW, y * bmpH, UGL.VFLIP, sprite
                Case 2
                    uglPutMskFlip video, x * bmpW, y * bmpH, UGL.HFLIP, sprite
                Case 3
                    uglPutMskFlip video, x * bmpW, y * bmpH, UGL.VHFLIP, sprite
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
