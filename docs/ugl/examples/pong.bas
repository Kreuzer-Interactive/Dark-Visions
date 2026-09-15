'/////////////////////////////////////////////////////////////////////////////
'//|                                                                       |//
'//|     ////////////////                                                  |//
'//|     U G L  - P O N G                                                  |//
'//|     ////////////////                                                  |//
'//|                                                                       |//
'//|     Version: 1.1                                                      |//
'//|     Author:  Tomer Filiba                                             |//
'//|     Update:  Andre Victor                                             |//
'//|     Email:   thetomer@mail.com                                        |//
'//|     Website: http://bitwise.cjb.net                                   |//
'//|                                                                       |//
'//|                                                                       |//
'//|     A simple Pong game made with UGL so that blitz and v1ctor         |//
'//|     won't feel unneeded :)                                            |//
'//|     Anyway, it uses a very simple AI. Feel free to modify and         |//
'//|     learn from this UGL example. For questions or anything of         |//
'//|     the kind, email me.                                               |//
'//|                                                                       |//
'//|     This update uses the UGL version 0.18a. It shows how to use       |//
'//|     AUTOINIT timers, vector fonts and the built archive (those        |//
'//|     rawk!) capabilities of UGL.                                       |//
'//|                                                                       |//
'//|                                                                       |//
'//|                                                                       |//
'/////////////////////////////////////////////////////////////////////////////

Defint A-Z
'$Include: '..\inc\ugl.bi'
'$Include: '..\inc\kbd.bi'
'$Include: '..\inc\tmr.bi'
'$Include: '..\inc\font.bi'

Const radian = 3.14159265359# / 180

Const FPS% = 60                             '' how many frames p/ sec
Const cFmt% = UGL.16BIT                     '' screen bpp
Const xRes% = 640                           '' /      width
Const yRes% = 400                           '' /      height

Type box2D
    X1      As Integer
    Y1      As Integer
    X2      As Integer
    Y2      As Integer
End Type

Type PaddleType
    oX      As Integer
    oY      As Integer
    X       As Single
    Y       As Single
    wWidth  As Integer
    Height  As Integer
    Shifted As Integer
    Speed   As Integer                      ' pixels per frame
    lBoost  As Single
    rBoost  As Single
    oScore  As Integer
    Score   As Integer
    imgDC   As Long
End Type

Type BallType
    oX      As Integer
    oY      As Integer
    X       As Single
    Y       As Single
    Radius  As Integer
    Speed   As Integer                      ' pixels per frame
    Boost   As Single
    angle   As Integer                      ' angle in degrees
    imgDC   As Long
    bgDC    As Long
End Type

Type EnvType
    wWidth      As Integer
    Height      As Integer
    CFormat     As Integer
    PlayComputer As Integer
    CurrentFPS  As integer

    ViewPage    As Integer
    WorkPage    As Integer
    VideoDC     As Long
    hFont       As Long
    Keyboard    As TKBD
    fpsTimer    As TMR                      '' expires every frame
    secTimer    As TMR                      '' /       every second
End Type

Declare Sub doBall ()
Declare Sub doComputer ()
Declare Sub doDraw ()
Declare Sub doPlayer ()
Declare Sub doStatistics ()
Declare Function InitPong% ()
Declare Sub PlayPong ()
Declare Sub EndPong ()
Declare Sub uglWrite (X%, Y%, text$, size%)

'----------------------------------------------------------------------------

'$Static
Dim Shared Env As EnvType
Dim Shared Box As box2D, Ball As BallType
Dim Shared Player As PaddleType, Comp As PaddleType

    On Error Goto OnGlobalError

    If ( Not InitPong ) Then End

    PlayPong

    EndPong
    End

OnGlobalError:
    EndPong
    Cls
    Print "ERROR #"; Err; " - "; ERROR$
    End

'':::
Sub doBall

    If ( Ball.Boost > 1.0# ) Then
        Ball.Boost = Ball.Boost - .25#
    ElseIf ( Ball.Boost < 1.0# ) Then
        Ball.Boost = 1.0#
    End If

    Ball.oX = Ball.X
    Ball.oY = Ball.Y
    Ball.X = Ball.X + (Ball.Speed * Cos(Ball.angle * radian) * Ball.Boost)
    Ball.Y = Ball.Y + (Ball.Speed * Sin(Ball.angle * radian) * Ball.Boost)

    If ( Ball.X > Box.X2 - Ball.Radius * 2 ) Then   '' hit left wall
        Ball.X = Box.X2 - Ball.Radius * 2
        Ball.angle = -180 - Ball.angle
    ElseIf ( Ball.X < Box.X1 ) Then                 '' hit right wall
        Ball.X = Box.X1
        Ball.angle = -180 - Ball.angle
    End If

    If ( Ball.Y > Box.Y2 - Ball.Radius * 2 ) Then   '' hit bottom wall
        Ball.X = Comp.X + (Comp.wWidth\2) - (Ball.Radius\2)
        Ball.Y = Comp.Y + Comp.Height + (Ball.Radius*2)
        Ball.angle = Rnd * 180
        Comp.Score = Comp.Score + 1
        Ball.Boost = 1.0#

    ElseIf ( Ball.Y < Box.Y1 ) Then                 '' hit top wall
        Ball.X = Player.X + (Player.wWidth\2) - (Ball.Radius\2)
        Ball.Y = Player.Y - Player.Height - (Ball.Radius*2)
        Ball.angle = 180 + (Rnd * 180)
        Player.Score = Player.Score + 1
        Ball.Boost = 1.0#
    End If

    '' hit player
    If ( Ball.Y + Ball.Radius * 2 >= Player.Y And Ball.Y + Ball.Radius * 2 < Player.Y + Player.Height ) Then
        If ( (Ball.X >= Player.X And Ball.X < Player.X + Player.Shifted) Or (Ball.X + Ball.Radius * 2 >= Player.X And Ball.X + Ball.Radius * 2 < Player.X + Player.Shifted) ) Then
            Ball.Y = Player.Y - Ball.Radius * 2 - 1
            Ball.angle = -Ball.angle - 45
        ElseIf ( (Ball.X >= Player.X + Player.Shifted And Ball.X < Player.X + Player.wWidth - Player.Shifted) Or (Ball.X + Ball.Radius * 2 >= Player.X + Player.Shifted And Ball.X + Ball.Radius * 2 < Player.X + Player.wWidth - Player.Shifted) ) Then
            Ball.Y = Player.Y - Ball.Radius * 2 - 1
            Ball.angle = -Ball.angle
        ElseIf ( (Ball.X >= Player.X + Player.wWidth - Player.Shifted And Ball.X < Player.X + Player.wWidth) Or (Ball.X + Ball.Radius * 2 >= Player.X + Player.wWidth - Player.Shifted And Ball.X + Ball.Radius * 2 < Player.X + Player.wWidth) ) Then
            Ball.Y = Player.Y - Ball.Radius * 2 - 1
            Ball.angle = -Ball.angle + 45
        End If
        Ball.Boost = 2.0#
    End If

    '' hit computer
    If ( (Ball.Y >= Comp.Y And Ball.Y < Comp.Y + Comp.Height) ) Then
        If ( (Ball.X >= Comp.X And Ball.X < Comp.X + Comp.Shifted) Or (Ball.X + Ball.Radius * 2 >= Comp.X And Ball.X + Ball.Radius * 2 < Comp.X + Comp.Shifted) ) Then
            Ball.Y = Comp.Y + Comp.Height + 1
            Ball.angle = -Ball.angle + 45
        ElseIf ( (Ball.X >= Comp.X + Comp.Shifted And Ball.X < Comp.X + Comp.wWidth - Comp.Shifted) Or (Ball.X + Ball.Radius * 2 >= Comp.X + Comp.Shifted And Ball.X + Ball.Radius * 2 < Comp.X + Comp.wWidth - Comp.Shifted) ) Then
            Ball.Y = Comp.Y + Comp.Height + 1
            Ball.angle = -Ball.angle
        ElseIf ( (Ball.X >= Comp.X + Comp.wWidth - Comp.Shifted And Ball.X < Comp.X + Comp.wWidth) Or (Ball.X + Ball.Radius * 2 >= Comp.X + Comp.wWidth - Comp.Shifted And Ball.X + Ball.Radius * 2 < Comp.X + Comp.wWidth) ) Then
            Ball.Y = Comp.Y + Comp.Height + 1
            Ball.angle = -Ball.angle - 45
        End If
        Ball.Boost = 2.0#
    End If

    Ball.angle = Ball.angle Mod 360
    If ( Ball.angle < 0 ) Then Ball.angle = Ball.angle + 360

    Select Case Ball.angle
        Case 0 To 15
            Ball.angle = Ball.angle + 15

        Case 90-15 To 90+15
            If ( Ball.angle <= 90 ) Then
                Ball.angle = Ball.angle - 15
            Else
                Ball.angle = Ball.angle + 15
            End If

        Case 180-15 To 180+15
            If ( Ball.angle <= 180 ) Then
                Ball.angle = Ball.angle - 15
            Else
                Ball.angle = Ball.angle + 15
            End If

        Case 270-15 To 270+15
            If ( Ball.angle <= 270 ) Then
                Ball.angle = Ball.angle - 15
            Else
                Ball.angle = Ball.angle + 15
            End If

        Case 360-15 To 360
            Ball.angle = Ball.angle - 15
    End Select

End Sub

'':::
Sub doComputer
    Dim hit

    Comp.oX = Comp.X
    Comp.oY = Comp.Y

    If ( Ball.angle > 180 And Ball.angle < 360 ) Then
        If ( Abs(Comp.X - Ball.X) > Comp.Speed ) Then
            If ( Comp.X + Comp.wWidth / 2 > Ball.X ) Then
                Comp.X = Comp.X - Comp.Speed
                If ( Comp.X < Box.X1 ) Then Comp.X = Box.X1
            ElseIf ( Comp.X + Comp.wWidth / 2 < Ball.X ) Then
                Comp.X = Comp.X + Comp.Speed
                If ( Comp.X > Box.X2 - Comp.wWidth ) Then Comp.X = Box.X2 - Comp.wWidth
            End If
        End If
    Else
        If ( Abs(Comp.X - (Box.X1 + Box.X2 - Comp.wWidth) / 2) > Comp.Speed ) Then
            If ( Comp.X > (Box.X1 + Box.X2 - Comp.wWidth) / 2 ) Then
                Comp.X = Comp.X - Comp.Speed
                If ( Comp.X < Box.X1 ) Then Comp.X = Box.X1
            ElseIf ( Comp.X < (Box.X1 + Box.X2 - Comp.wWidth) / 2 ) Then
                Comp.X = Comp.X + Comp.Speed
                If ( Comp.X > Box.X2 - Comp.wWidth ) Then Comp.X = Box.X2 - Comp.wWidth
            End If
        End If
    End If
End Sub

'':::
Sub doDraw
    Static angle As Integer, espc As Integer, edir As Integer
    Static sScl As Single

    uglClear Env.VideoDC, uglColor(Env.CFormat, 0, 64, 64)

    '' update "UGL Pong" logo
    angle = (angle + (360 \ (FPS*6))) Mod 360
    If ( edir = 0 ) Then edir = 1
    espc = espc + edir
    If ( espc >= 25 ) Then
        edir = -1
    ElseIf ( espc <= 0 ) Then
        edir = 1
    End If

    If ( Player.Score <> Player.oScore ) Then
        Player.oScore = Player.Score
        sScl = 4.0#
    End If

    If ( sScl > 1.0# ) Then
        sScl = sScl - .1#
    Else
        sScl = 1.0#
    End If

    '' show it
    oAngle = fontAngle( angle )
    oESpc = fontExtraSpc( espc )
    outline = fontOutline( FONT.TRUE )
    fontSetSize (36 * (xRes \ 320)) * sScl
    hAlign = fontHAlign( FONT.HALIGN.CENTER )
    vAlign = fontVAlign( FONT.VALIGN.BASELINE )

    fontTextOut Env.VideoDC, Env.wWidth\2, Env.Height\2, _
                uglColor(Env.CFormat, 0, 128, 128), Env.hFont, "UGL Pong"

    fontSetVAlign vAlign
    fontSetHAlign hAlign
    fontSetOutline outline
    fontSetExtraSpc oESpc
    fontSetAngle oAngle

    '' put imgs
    uglPutMsk Env.VideoDC, Ball.X, Ball.Y, Ball.imgDC
    uglPutMsk Env.VideoDC, Player.X, Player.Y, Player.imgDC
    uglPutMsk Env.VideoDC, Comp.X, Comp.Y, Comp.imgDC

    '' show statistics
    doStatistics

    '' draw box
    uglRect Env.VideoDC, Box.X1, Box.Y1, Box.X2, Box.Y2, -1

    '' page-flip
    Swap Env.ViewPage, Env.WorkPage
    uglSetVisPage Env.ViewPage
    Wait &H3DA, 8
    uglSetWrkPage Env.WorkPage
End Sub

'':::
Sub doPlayer
    Player.oX = Player.X
    Player.oY = Player.Y

    If ( Env.Keyboard.SpcBar ) Then
        Env.PlayComputer = Not Env.PlayComputer
        Env.Keyboard.SpcBar = 0
    End If

    If ( Env.PlayComputer ) Then
        If ( Ball.angle > 0 And Ball.angle < 180 ) Then
            If ( Abs(Player.X - Ball.X) > Comp.Speed ) Then
                If ( Player.X + Player.wWidth / 2 > Ball.X ) Then
                    Player.X = Player.X - Player.Speed
                    If ( Player.X < Box.X1 ) Then Player.X = Box.X1
                ElseIf ( Player.X + Player.wWidth / 2 < Ball.X ) Then
                    Player.X = Player.X + Player.Speed
                    If ( Player.X > Box.X2 - Player.wWidth ) Then Player.X = Box.X2 - Player.wWidth
                End If
            End If
        Else
            If ( Abs(Player.X + -(Box.X1 + Box.X2 - Player.wWidth) / 2) > Comp.Speed ) Then
                If ( Player.X > (Box.X1 + Box.X2 - Player.wWidth) / 2 ) Then
                    Player.X = Player.X - Player.Speed
                    If ( Player.X < Box.X1 ) Then Player.X = Box.X1
                ElseIf ( Player.X < (Box.X1 + Box.X2 - Player.wWidth) / 2 ) Then
                    Player.X = Player.X + Player.Speed
                    If ( Player.X > Box.X2 - Player.wWidth ) Then Player.X = Box.X2 - Player.wWidth
                End If
            End If
        End If

    Else
        '' break?
        If ( Env.Keyboard.ctrl ) Then
            Player.lBoost = Player.lBoost - .325#
            Player.rBoost = Player.rBoost - .325#
        End If

        If ( Player.lBoost > 0.0# ) Then
            Player.lBoost = Player.lBoost - .075#
        Else
            Player.lBoost = 0.0#
        End If
        If ( Player.rBoost > 0.0# ) Then
            Player.rBoost = Player.rBoost - .075#
        Else
            Player.rBoost = 0.0#
        End If

        If ( Env.Keyboard.Left ) Then
            If ( Player.lBoost < 2.5# ) Then Player.lBoost = Player.lBoost + .25#
        ElseIf ( Env.Keyboard.Right ) Then
            If ( Player.rBoost < 2.5# ) Then Player.rBoost = Player.rBoost + .25#
        End If

        Player.X = Player.X + (Player.Speed * (Player.rBoost - Player.lBoost))
        If ( Player.X <= Box.X1 ) Then
            Player.X = Box.X1
            Player.lBoost = 0.0#
            Player.rBoost = 0.0#
        ElseIf ( Player.X => Box.X2 - Player.wWidth ) Then
            Player.X = Box.X2 - Player.wWidth
            Player.lBoost = 0.0#
            Player.rBoost = 0.0#
        End If
    End If

End Sub

'':::
Sub doStatistics
    uglWrite Box.X1+4+0  , Box.Y1+4+0 , "FPS:", 15
    uglWrite Box.X1+4+100, Box.Y1+4+0 , STR$(Env.CurrentFPS), 15
    uglWrite Box.X1+4+0  , Box.Y1+4+20, "Player:", 15
    uglWrite Box.X1+4+100, Box.Y1+4+20, STR$(Player.Score), 15
    uglWrite Box.X1+4+0  , Box.Y1+4+40, "Computer:", 15
    uglWrite Box.X1+4+100, Box.Y1+4+40, STR$(Comp.Score), 15
End Sub

'':::
Sub EndPong
    kbdEnd
    tmrEnd
    uglRestore
    uglEnd
End Sub

'':::
Function InitPong%

    InitPong = 0

    If ( Not uglInit ) Then
        Print "ERROR: Cannot initialize UGL"
        Exit Function
    End If

    Env.hFont = fontNew("game.dat::arial.uvf")
    If ( Env.hFont = 0 ) Then
        Print "ERROR: Cannot load font"
        uglEnd
        Exit Function
    End If

    Randomize Timer

    Env.wWidth = xRes
    Env.Height = yRes
    Env.CFormat = cFmt

    Box.X1 = 10
    Box.Y1 = 10
    Box.X2 = Env.wWidth - 10
    Box.Y2 = Env.Height - 10

    Player.Speed = 3 * (xRes \ 320)
    Player.wWidth = 80
    Player.Height = 15
    Player.Shifted = 7
    Player.X = (Box.X1 + Box.X2 - Player.wWidth) \ 2
    Player.Y = Box.Y2 - Player.Height
    Player.Score = 0
    Player.imgDC = uglNewBMP(UGL.MEM, Env.CFormat, "game.dat::plyr.bmp")

    Comp.Speed = 3 * (xRes \ 320)
    Comp.wWidth = 40
    Comp.Height = 15
    Comp.Shifted = 7
    Comp.X = (Box.X1 + Box.X2 - Comp.wWidth) \ 2
    Comp.Y = Box.Y1
    Comp.imgDC = uglNewBMP(UGL.MEM, Env.CFormat, "game.dat::comp.bmp")
    Comp.Score = 0

    Ball.Radius = 10
    Ball.Speed = 4 * (xRes \ 320)
    Ball.X = (Box.X1 + Box.X2 - Ball.Radius) \ 2
    Ball.Y = (Box.Y1 + Box.Y2 - Ball.Radius) \ 2
    Ball.angle = 270 + 15 + (Rnd * 30)
    Ball.imgDC = uglNew(UGL.MEM, Env.CFormat, Ball.Radius * 2 + 1, Ball.Radius * 2 + 1)
    uglClear Ball.imgDC, uglColor(Env.CFormat, 255, 0, 255)
    uglCircleF Ball.imgDC, Ball.Radius, Ball.Radius, Ball.Radius, -1
    uglCircle Ball.imgDC, Ball.Radius, Ball.Radius, Ball.Radius, 0

    Env.VideoDC = uglSetVideoDC(Env.CFormat, Env.wWidth, Env.Height, 2)
    If ( Env.VideoDC = 0 ) Then
        Print "ERROR: Cannot set video mode"
        uglEnd
        Exit Function
    End If

    Dim cr as CLIPRECT
    cr.xMin = Box.X1: cr.yMin = Box.Y1
    cr.xMax = Box.X2: cr.yMax = Box.Y2
    uglSetClipRect Env.VideoDC, cr

    Env.ViewPage = 0
    Env.WorkPage = 1
    uglSetWrkPage Env.WorkPage
    uglSetVisPage Env.ViewPage

    '' create a timer used to reset the fps counter, that expires
    '' every second
    tmrNew Env.secTimer, TMR.AUTOINIT, tmrSec2Freq&(1)

    '' create a timer that is used to run at a fixed number of frames
    '' per second, meaning if the system is too slow, frames will be
    '' skipped but game speed will stay the same, and if the system is
    '' too fast, no more than the number of fps chosen will be drawn
    tmrNew Env.fpsTimer, TMR.AUTOINIT, tmrMs2Freq&(1000 \ FPS)

    kbdInit Env.Keyboard
    tmrInit

    InitPong = -1
End Function

'':::
Sub PlayPong
    Dim fpsCounter As Integer
    fpsCounter = 0

    Env.fpsTimer.counter = 0
    Do
        If ( Env.fpsTimer.counter > 0 ) Then
            '' do game logic until frame counter is 0
            Do
                doBall
                doPlayer
                doComputer
                Env.fpsTimer.counter = Env.fpsTimer.counter - 1
            Loop While ( Env.fpsTimer.counter > 0 )

            '' redraw screen
            doDraw
            fpsCounter = fpsCounter + 1

            '' time to reset fpsCounter? (one second elapsed?)
            If ( Env.secTimer.counter > 0 ) Then
                Env.secTimer.counter = Env.secTimer.counter - 1
                Env.CurrentFPS = fpsCounter - 1
                fpsCounter = 0
            End If
        End If
    '' stop? (esc pressed?)
    Loop Until ( Env.Keyboard.Esc )
End Sub

'':::
Sub uglWrite (X, Y, text$, size)
    fontSetSize size
    fontTextOut Env.VideoDC, X, Y, uglColor(Env.CFormat, 255, 255, 255), Env.hFont, text$
End Sub