DefInt a-z
'$include: '..\inc\ugl.bi'
'$include: '..\inc\font.bi'

Const xRes = 320*2
Const yRes = 240*2
Const cFmt = UGL.8BIT

Declare Sub ExitError (msg As String)

'':::
    Dim video as long
    Dim uvf as long
    
    If ( not uglInit ) Then ExitError "Init"
    
    If ( len(command$) = 0 ) Then ExitError "usage: UVF fontfile (w/out .ext)"
    uvf = fontNew(command$ + ".uvf")
    If ( uvf = 0 ) Then ExitError "fontNew"
    
    video = uglSetVideoDC(cFmt, xRes, yRes, 1)
    If ( video = 0 ) Then ExitError "SetVideoDC"
    
    fontSetAlign FONT.HALIGN.LEFT, FONT.VALIGN.TOP
    'fontSetUnderline FONT.TRUE
    'fontSetStrikeOut FONT.TRUE
    'fontSetBGMode FONT.BG.OPAQUE
    fontSetBGColor &h80
    'fontSetOutline FONT.TRUE
        
    dim text as string
    text =  "AHMW" '"ABCD0123vwxyz"
    s = 9
    for a = 0 to 359 step 15
        uglClear video, 0            
        'fontSetAngle a
        fontSetSize s
        s = s + 1
        'fontSetOutline FONT.TRUE
        'fontTextOut video, xRes\2, 00+yRes\2, uglColor(cFmt, 0,133,184), uvf, text
        fontSetOutline FONT.FALSE
        fontTextOut video, 0, 0, uglColor(cFmt, 0,133,184-s*4), uvf, "ANAL - The rectum adventure"
        while len(inkey$) = 0:wend
    next a

    fontDel uvf
    
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
