''
'' bmp.bas -- BMP loading ex
''

DefInt A-Z
'$Include: '..\inc\ugl.bi'
'$Include: '..\inc\kbd.bi'

Const xRes = 320
Const yRes = 200
Const cFmt = UGL.8BIT

Const wStep = 4
Const hStep = 3

Declare Sub ExitError (msg As String)

'':::
    Dim kbd As TKBD
    Dim video As Long
    Dim bmp As Long, bmpDC as TDC
    Dim flname As String
    dim bg as long

    bg = uglColor( cFmt, 255, 0, 0 )
    
    If (Len(Command$) = 0) Then
        Print "usage: bmp filename (w/out .bmp extension)"
        Print "           or an UAR (PAK) archive: arc_path\arc_file.pak::filepath/somebmp"
        End
    Else
        flname = Command$ + ".bmp"
    End If
    
    '' initialize
    If (Not uglInit) Then ExitError "Init"
    
    '' load the BMP                          
    bmp = uglNewBMP(UGL.EMS, cFmt, flname)
    If (bmp = 0) Then ExitError "BMPload"

    uglDCget bmp, bmpDC

    '' change video-mode
    video = uglSetVideoDC(cFmt, xRes, yRes, 1)
    If (video = 0) Then ExitError "SetVideoDC"

    uglClear video, bg

    '' show it
    kbdInit kbd

    x = (xRes\2) - (bmpDC.xRes\2)
    y = (yRes\2) - (bmpDC.yRes\2)
    moved = -1
    Do                                
        If (kbd.left) Then
            moved = -1
            uglRectF video, x+bmpDc.xRes-wStep, y, _ 
                            x+bmpDc.xRes-1, y+bmpDc.yRes-1, bg
            x = x - wStep
            If (x + bmpDc.xRes-1 < 0) Then x = xRes-1 + (x + (bmpDc.xRes-1))
        Elseif (kbd.right) Then
            moved = -1
            uglRectF video, x, y, x+wStep, y+bmpDc.yRes-1, bg
            x = x + wStep
            If (x > xRes-1) Then x = -bmpDc.xRes + (x - (xRes-1))
        End If
        If (kbd.up) Then
            moved = -1
            uglRectF video, x, y+bmpDc.yRes-hStep, _
                            x+bmpDc.xRes-1, y+bmpDc.yRes-1, bg
            y = y - hStep
            If (y + bmpDc.yRes-1 < 0) Then y = yRes-1 + (y + (bmpDc.yRes-1))
        Elseif (kbd.down) Then
            moved = -1
            uglRectF video, x, y, x+bmpDc.xRes-1, y+hStep, bg
            y = y + hStep
            If (y > yRes-1) Then y = -bmpDc.yRes + (y - (yRes-1))
        End If

        If (moved) Then
            moved = 0
            uglPut video, x, y, bmp
        End If
    Loop Until (kbd.esc)        

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
