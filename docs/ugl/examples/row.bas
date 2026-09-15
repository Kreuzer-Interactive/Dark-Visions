DefInt A-Z
'$Include: '..\inc\ugl.bi'

Const xRes = 320
Const yRes = 200
Const cFmt = UGL.16BIT

Const bmpW = 32
Const bmpH = 32

Declare Sub ExitError (msg As String)

'':::
    Dim video As Long
    Dim bmp As Long
    Dim buffer(0 to bmpW-1) As Integer
    
    '' initialize
    If (Not uglInit) Then ExitError "Init"
    
    '' change video-mode
    video = uglSetVideoDC(cFmt, xRes, yRes, 1)
    If (video = 0) Then ExitError "SetVideoDC"

    colors& = uglColors(cFmt)

    '' allocate bmp
    bmp = uglNew(UGL.EMS, cFmt, bmpW, bmpH)
    If (bmp = 0) Then ExitError "New bmp"

    '' calc buffer far pointer
    buffPtr& = (VarSeg(buffer(0)) * 65536) + VarPtr(buffer(0))

    '' fill buffer()
    For x = 0 To bmpW-1
        uglPSet video, x, 0, Rnd * colors&
    Next x
    uglRowRead video, 0, 0, bmpW, UGL.BF.16BIT, buffPtr&
        
    '' fill the bitmap
    For y = 0 To bmpH-1
        uglRowWrite bmp, 0, y, bmpW, UGL.BF.16BIT, buffPtr&
    Next y

    '' show it
    For y = 0 To yRes-1 Step bmpH
        For x = 0 To xRes-1 Step bmpW
            uglPut video, x, y, bmp
        Next x
    Next y
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
