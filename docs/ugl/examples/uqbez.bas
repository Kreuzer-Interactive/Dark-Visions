''
'' uqbez.bas -- quadric bezier curve generation ex.
''              Demonstrates how to use ugluQuadricBez to get the
''              X and Y coordinates for a qudric curve.
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
    Dim qbz As QUADBEZ
    Dim curve(POINTS) As PNT2D
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

    '' generate three random points for our spline                    
    qbz.a.x = Rnd * xRes: qbz.a.y = Rnd * yRes
    qbz.b.x = Rnd * xRes: qbz.b.y = Rnd * yRes
    qbz.c.x = Rnd * xRes: qbz.c.y = Rnd * yRes
                            
    '' tell ugluQuadricBez to generate the curve
    '' with points precision.
    ugluQuadricBez curve(0), qbz, POINTS
                
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
        uglQuadricBez video, qbz, POINTS, UGL.WHITE16
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
            qbz.a.x = Rnd * xRes: qbz.a.y = Rnd * yRes
            qbz.b.x = Rnd * xRes: qbz.b.y = Rnd * yRes
            qbz.c.x = Rnd * xRes: qbz.c.y = Rnd * yRes
            ugluQuadricBez curve(0), qbz, POINTS
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

