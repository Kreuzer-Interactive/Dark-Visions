''
'' ucbez3d.bas -- cubic bezier curve generation ex.
''                Demonstrates how to use ugluCubicBez3D to get the
''                X, Y and Z coordinates for a cubic curve.
''
''

Defint a-z
'$include: '..\inc\ugl.bi'
'$include: '..\inc\uglu.bi'

Const xRes = 320*2
Const yRes = 200*2
Const cFmt = UGL.8BIT

Const POINTS = 16

Declare Sub ExitError (msg As String)

'':::
    Dim video As Long
    Dim cbz As CUBICBEZ3D
    Dim cbzex As CUBICBEZ
    Dim curve(POINTS) As PNT3D
    Dim bmp As Long
                

    '' initialize
    If (Not uglInit) Then ExitError "init"
    
    Randomize Timer
    
    video = uglSetVideodc(cFmt, xRes, yRes, 2)
    If (video = 0) Then ExitError "setvideodc"

    '' create a new dc and load the bitmap in it
    bmp = uglNew(UGL.MEM, cFmt, 32, 32)
    If (bmp = 0) Then ExitError "newbmp"

    colors& = uglColors(cFmt)

    ''fill the bmp
    For i = 32 To 4 Step - 1
        uglCircleF bmp, 16, 16, i, Rnd * colors&
    Next i

    '' generate four random points for our spline
    cbz.a.x = Rnd * xRes: cbz.a.y = Rnd * yRes
    cbz.b.x = Rnd * xRes: cbz.b.y = Rnd * yRes
    cbz.c.x = Rnd * xRes: cbz.c.y = Rnd * yRes
    cbz.d.x = Rnd * xRes: cbz.d.y = Rnd * yRes
    
    '' Copy it to cbzex for drawing
    cbzex.a.x = cbz.a.x: cbzex.a.y = cbz.a.y
    cbzex.b.x = cbz.b.x: cbzex.b.y = cbz.b.y
    cbzex.c.x = cbz.c.x: cbzex.c.y = cbz.c.y
    cbzex.d.x = cbz.d.x: cbzex.d.y = cbz.d.y

    '' tell ugluCubicBez3D to generate the curve
    '' with points precision.
    ugluCubicBez3D curve(0), cbz, POINTS
                
    '' set the move direction
    movedirection = 1
                
    '' start timing (for fps counter)
    tmrini! = Timer
    Do
        '' set the visible page
        uglSetVisPage flips
                        
        '' set the other page for drawing on
        Wait &h3da, 8
        flips = 1 xor flips
        uglSetWrkPage flips
                        
        '' get the pressed key
        keydown$ = Inkey$
                     
        '' wait for vertical retrace and clear the dc
        '' with the color 0                
        uglClear video, 0

        '' draw the curve on screen and put the bitmap
        '' at the current point of the curve that we
        '' stored in the array curve
        uglCubicBez video, cbzex, POINTS, UGL.WHITE16
        uglPut video, curve(i).x, curve(i).y, bmp
                        
        '' instead of making a delay and lowering the 
        '' framerate we move to the next point every 
        '' two loops. (by adding m to i)
        If (a = 1) Then
            i = i + movedirection
            a = 0
        Else
            a = a + 1
        End If

        '' if n has been pressed we want to generate a new curve
        If (keydown$ = "n") Then
            '' generate four random points for our spline
            cbz.a.x = Rnd * xRes: cbz.a.y = Rnd * yRes
            cbz.b.x = Rnd * xRes: cbz.b.y = Rnd * yRes
            cbz.c.x = Rnd * xRes: cbz.c.y = Rnd * yRes
            cbz.d.x = Rnd * xRes: cbz.d.y = Rnd * yRes
            
            '' Copy it to cbzex for drawing
            cbzex.a.x = cbz.a.x: cbzex.a.y = cbz.a.y
            cbzex.b.x = cbz.b.x: cbzex.b.y = cbz.b.y
            cbzex.c.x = cbz.c.x: cbzex.c.y = cbz.c.y
            cbzex.d.x = cbz.d.x: cbzex.d.y = cbz.d.y
        
            '' tell ugluCubicBez3D to generate the curve
            '' with points precision.
            ugluCubicBez3D curve(0), cbz, POINTS
        End If
                    
        '' if i is at the first or last point of the curve
        '' we should change the moving direction
        If (i >= POINTS) Then movedirection = -1
        If (i <= 0) Then movedirection = 1
                 
        '' for the framerate counter
        frames! = frames! + 1
    Loop Until (keydown$ = Chr$(27))
    tmrend! = Timer
                
    uglRestore
    uglEnd
    Print frames! / (tmrend! - tmrini!)
    End

'':::
Sub ExitError (msg As String)
    uglRestore
    uglEnd
    Print "error! "; msg
    End
End Sub

