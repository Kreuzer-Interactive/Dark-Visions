''
'' kbd.bas -- keyboard routines ex
''

DefInt A-Z
'$Include: '..\inc\ugl.bi'
'$Include: '..\inc\kbd.bi'

Const xRes = 320*2
Const yRes = 200*2
Const cFmt = UGL.8BIT

Const wStep = 2
Const hStep = 1

Declare Sub ExitError (msg As String)

'':::
    Dim video As Long
    Dim kbd As TKBD

    Dim bmpW As Integer, bmpH As Integer

    bmpW = 64
    bmpH = 64
    
    '' initialize
    If (Not uglInit) Then ExitError "Init"
    
    '' change video-mode
    video = uglSetVideoDC(cFmt, xRes, yRes, 1)
    If (video = 0) Then ExitError "SetVideoDC"

    kbdInit kbd

    x = (xRes\2) - (bmpW\2)
    y = (yRes\2) - (bmpH\2)
    moved = -1
    Do                                
        If (kbd.left) Then
            moved = -1
            uglRectF video, x+bmpW-1-wStep, y, x+bmpW-1, y+bmpH-1, 0
            x = x - wStep
            If (x + bmpW-1 < 0) Then x = xRes-1 + (x + (bmpW-1))
        Elseif (kbd.right) Then
            moved = -1
            uglRectF video, x, y, x+1+wStep, y+bmpH-1, 0
            x = x + wStep
            If (x > xRes-1) Then x = -bmpW + (x - (xRes-1))
        End If
        If (kbd.up) Then
            moved = -1
            uglRectF video, x, y+bmpH-1-hStep, x+bmpW-1, y+bmpH-1, 0
            y = y - hStep
            If (y + bmpH-1 < 0) Then y = yRes-1 + (y + (bmpH-1))
        Elseif (kbd.down) Then
            moved = -1
            uglRectF video, x, y, x+bmpW-1, y+hStep, 0
            y = y + hStep
            If (y > yRes-1) Then y = -bmpH + (y - (yRes-1))
        End If
        If (kbd.plus) Then
            moved = -1                        
            bmpW = bmpW + 1
            bmpH = bmpH + 1
        Elseif (kbd.min) Then
            If (bmpW > 3) Then
                moved = -1
                uglVLine video, x+bmpW-1, y, y+bmpH-1, 0
                bmpW = bmpW - 1                                
            End If
            If (bmpH > 3) Then
                moved = -1
                uglHLine video, x, y+bmpH-1, x+bmpW-1, 0
                bmpH = bmpH - 1
            End If
        End If

        If (moved) Then
            moved = 0
            uglRectF video, x+1, y+1, x+bmpW-2, y+bmpH-2, uglColor(cFmt, 0, 127, 0)
            uglRect video, x, y, x+bmpW-1, y+bmpH-1, uglColor(cFmt, 255, 255, 255)
        End If
    Loop Until (kbd.esc)

    uglRestore

    Print "Press Any Key..."

    kbdPause
    Do
    Loop Until (Len(Inkey$) <> 0)

    uglEnd
    End

'':::
Sub ExitError (msg As String)
    uglRestore
    uglEnd
    Print "ERROR! "; msg
    End
End Sub
