''
'' mouse.bas -- mouse routines ex
''

DefInt A-Z
'$include: '..\inc\ugl.bi'
'$include: '..\inc\mouse.bi'
'$include: '..\inc\tmr.bi'

Const xRes = 320'*2
Const yRes = 200'*2
Const cFmt = UGL.8BIT
Const pages = 8

Declare Sub ExitError (msg As String)

'':::
    Dim video As Long
    Dim mouse As MOUSEINF
    Dim t As TMR
    dim fuck as long

    If (Not uglInit) Then ExitError "Init"

    '' change video mode
    video = uglSetVideoDC(cFmt, xRes, yRes, pages)
    If (video = 0) Then ExitError "SetVideoDC"

    wPg = 1
    uglSetVisPage 0
    uglSetWrkPage wPg

    '' try starting mouse driver
    If (Not mouseInit(video, mouse)) Then ExitError "mouseInit"

    fuck = uglNew( UGL.MEM, cFmt, 32, 32 )
    uglClear fuck, uglColor( cFmt, 255, 0, 255 )
    uglCircleF fuck, 16, 16, 16, &h80
    uglCircle fuck, 16, 16, 16, -1

    tmrInit
    tmrNew t, TMR.AUTOINIT, tmrMs2Freq(1000\pages)

    '' test using default cursor
    mouseRange 32, 32, xRes-1-32, yRes-1-32
    mousePos xRes\2, yRes\2

    t.counter = 0
    mouseShow
    Do
        if ( t.counter > 0 ) then
            t.counter = 0

            'wait &h3DA, &h08
            mouseHide

            vPg = wPg
            wPg = (wPg + 1) mod pages
            uglSetVisPage vPg
            uglSetWrkPage wPg
            uglClear video, rnd * 128
            uglRect video, 32, 32, xRes-1-32, yRes-1-32, -1
            uglPutMsk video, rnd * xRes, rnd * yRes, fuck

            mouseShow
        end if
    Loop Until (mouse.left or mouse.right)
    mouseHide

    tmrEnd
    mouseEnd

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
