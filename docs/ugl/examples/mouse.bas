''
'' mouse.bas -- mouse routines ex
''

DefInt A-Z
'$include: '..\inc\ugl.bi'
'$include: '..\inc\mouse.bi'

Type BUTTON
    box     As RECT
    clicked As Integer
    caption As String * 16
End Type

Const xRes = 320
Const yRes = 200
Const cFmt = UGL.8BIT

Declare Sub ExitError (msg As String)

Declare Sub DrawButton (dc As Long, b As BUTTON)

'':::
    Dim video As Long
    Dim mouse As MOUSEINF
    Dim cross As Long
    Dim exbutton As BUTTON

    If (Not uglInit) Then ExitError "Init"

    '' make cross cursor
    cross = uglNew(UGL.MEM, cFmt, 16, 16)
    If (cross = 0) Then ExitError "New cross"
    uglClear cross, uglColor(cFmt, 255, 0, 255)
    uglVLine cross, 8, 0, 15, uglColor(cFmt, 255, 0, 0)
    uglHLine cross, 0, 8, 15, uglColor(cFmt, 255, 0, 0)

    '' change video mode
    video = uglSetVideoDC(cFmt, xRes, yRes, 1)
    If (video = 0) Then ExitError "SetVideoDC"

    '' try starting mouse driver
    If (Not mouseInit(video, mouse)) Then ExitError "mouseInit"

    '' define a exit box
    exbutton.box.x1 = xRes\2 - 32
    exbutton.box.y1 = yRes\2 - 12
    exbutton.box.x2 = xRes\2 + 32
    exbutton.box.y2 = yRes\2 + 12
    
    '' test using default cursor        
    uglRect video, 32, 32, xRes-1-32, yRes-1-32, -1
    mouseRange 32, 32, xRes-1-32, yRes-1-32
    mousePos xRes\2, yRes\2

    mouseShow
    Do
        exbutton.clicked = 0
        DrawButton video, exbutton
        Do
            If (mouse.left) Then exbutton.clicked = mouseIn(exbutton.box)
        Loop Until (exbutton.clicked)

        DrawButton video, exbutton
        Do
        Loop While (mouse.left)
    Loop Until (mouseIn(exbutton.box))
    mouseHide

    '' reset
    uglClear video, 0

    If (Not mouseReset(video, mouse)) Then ExitError "mouseReset"
    mouseRatio 4, 4
    mouseCursor cross, 8, 8
    mousePos xRes\2, yRes\2

    uglRect video, 0, 0, xRes-1, yRes-1, -1

    mouseShow
    Do
        exbutton.clicked = 0
        DrawButton video, exbutton
        Do
            If (mouse.right) Then exbutton.clicked = mouseIn(exbutton.box)
        Loop Until (exbutton.clicked)

        DrawButton video, exbutton
        Do
        Loop While (mouse.right)
    Loop Until (mouseIn(exbutton.box))
    mouseHide

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

'':::
Sub DrawButton (dc As Long, b As BUTTON) Static
    Dim bgc As Long, tlc As Long, brc As Long

    bgc = uglColor(cFmt, 128, 128, 128)
    If (Not b.clicked) Then
        tlc = uglColor(cFmt, 255, 255, 255)
        brc = uglColor(cFmt, 64, 64, 64)
    Else
        tlc = uglColor(cFmt, 64, 64, 64)
        brc = uglColor(cFmt, 255, 255, 255)
    End If

    mouseHide

    uglRectF dc, b.box.x1, b.box.y1, b.box.x2, b.box.y2, bgc
    uglHLine dc, b.box.x1,   b.box.y1,   b.box.x2-1, tlc
    uglVLine dc, b.box.x1,   b.box.y1,   b.box.y2-1, tlc
    uglHLine dc, b.box.x1+1, b.box.y2,   b.box.x2, brc
    uglVLine dc, b.box.x2,   b.box.y1+1, b.box.y2, brc

    mouseShow
End Sub
