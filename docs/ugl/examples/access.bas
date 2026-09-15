''
'' access.bas -- direct dc access
''

DefInt A-Z
'$Include: '..\inc\ugl.bi'

Const xRes = 320 * 2
Const yRes = 200 * 2
Const cFmt = UGL.8BIT

Declare Sub ExitError (msg As String)

'':::
    Dim video As Long
    Dim fb As Long
    
    '' initialize
    If (Not uglInit) Then ExitError "Init"
    
    '' change video-mode
    video = uglSetVideoDC(cFmt, xRes, yRes, 1)
    If (video = 0) Then ExitError "SetVideoDC"
    
    for y = 0 to yRes-1
        c = rnd * 256

        fb = uglDCAccessWr( video, y )
        def seg = fb \ &h10000&
        ofs&    = fb and &h0000FFFF&

        for x = 0 to xRes-1
                poke ofs& + x-25, c
        next x
    next y
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
