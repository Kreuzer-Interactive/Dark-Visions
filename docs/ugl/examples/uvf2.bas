DefInt a-z
'$include: '..\inc\ugl.bi'
'$include: '..\inc\font.bi'

Const xRes = 320'*2
Const yRes = 200'*2
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
    
    fontSetAlign FONT.HALIGN.CENTER, FONT.VALIGN.BASELINE
        
    colors& = uglColors(cFmt)
    do
        fontSetAngle cint(rnd*359)
        fontSetSize 36 + cint(rnd*72)
        fontTextOut video, _
                    -16+Clng(Rnd*(xRes+32)), _
                    -16+Clng(Rnd*(yRes+32)), _
                    Rnd*colors&, _
                    uvf, _
                    "UVF!"
    loop until len(inkey$) > 0

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
