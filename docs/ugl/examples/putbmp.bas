''
'' putbmp.bas -- loads a BMP file directly to screen
''

DefInt A-Z
'$Include: '..\inc\ugl.bi'

Const xRes = 640
Const yRes = 400
Const cFmt = UGL.8BIT

Declare Sub ExitError (msg As String)

'':::
    Dim video As Long
    Dim flname As String
    
    If (Len(Command$) = 0) Then
        Print "usage: bmp filename (w/out .ext)"
        End
    Else
        flname = Command$ + ".bmp"
    End If
    
    '' initialize
    If (Not uglInit) Then ExitError "Init"
    
    '' change video-mode
    video = uglSetVideoDC(cFmt, xRes, yRes, 1)
    If (video = 0) Then ExitError "SetVideoDC"

    '' show it
    If (Not uglPutBMP(video, 0, 0, flname)) Then ExitError "put"
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
