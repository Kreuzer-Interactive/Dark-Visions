'By Jon Kreuzer
'Here are 28 sounds that can be used as is in your game, or you can
'Create variations on them.
'Note: The sounds heard will vary on different computers.
'----Space Blaster shot
DEFINT A-Q, S-Z 'Every variable but those beginning with r are integers
FOR D = 600 TO 50 STEP -12
SOUND D, .1: SOUND 50 + RND * 200, .1
NEXT D
PLAY "P2" 'pause to seperate sounds
'-----phone dial
FOR i = 1 TO 9
SOUND 300 + INT(RND * 10) * 100, 3
SOUND 32676, 2
NEXT i
PLAY "p2"
'----plane
FOR D = 1600 TO 100 STEP -5
SOUND D, .05: SOUND 50, .05
NEXT D
PLAY "p2"
'-----approaching helicopter/vehicle
rg = .4
FOR i = 50 TO 200 STEP 1
IF i / 20 = i \ 20 THEN rg = rg - .01: rf = rf + .01
SOUND 32676, rg
SOUND i, .05 + rf: SOUND 32676, rg: SOUND 80, .1 + rf
NEXT i
PLAY "p2"
'-----???????
FOR i = 200 TO 50 STEP -5
SOUND 100, .05: SOUND i, .05: SOUND 250 - i, .05
SOUND RND * 500 + 50, .05
NEXT i
FOR i = 400 TO 1000 STEP 20
SOUND i, .04: SOUND i - RND * 350, .1
NEXT i
PLAY "p2"
'-----conveyor belt 1
FOR i = 1 TO 40 STEP 1
SOUND 200, .1: SOUND 32676, .5
NEXT i
PLAY "p2"
'----conveyor belt 2
FOR D = 1 TO 25 STEP 1
SOUND 400, .05
SOUND 32676, .5
NEXT D
PLAY "p2"
'-----blaster 2
SOUND 1000, .5
FOR i = 1000 TO 600 STEP -5
IF RND * 1 < .1 THEN SOUND 1000, .05
SOUND i, .05: SOUND 100 + RND * 100, .05
NEXT i
FOR i = 600 TO 500 STEP -1
SOUND i, .05: SOUND 100 + RND * 100, .05
NEXT i
PLAY "p2"
'-----Some future vehicle moving
SOUND 1000, .5
FOR i = 1000 TO 600 STEP -5
IF RND * 1 < .1 THEN SOUND 1000, .05
SOUND i, .05: SOUND 1000 + RND * 100, .05
NEXT i
FOR i = 600 TO 500 STEP -1
SOUND i, .05: SOUND 1000 + RND * 100, .05
NEXT i
PLAY "p2"
'---Variation on future vehicle #1
SOUND 1000, .5
FOR i = 1000 TO 600 STEP -5
IF RND * 1 < .1 THEN SOUND 1000, .05
SOUND i, .05: SOUND 10000 + RND * 100, .05
NEXT i
FOR i = 600 TO 500 STEP -1
SOUND i, .05: SOUND 10000 + RND * 100, .05
NEXT i
PLAY "p2"
'----variation #2(Going up)
FOR i = 500 TO 700
SOUND i, .05
SOUND 32676, .1
NEXT i
PLAY "p2"
'----variation #3(Going down)
FOR i = 700 TO 500 STEP -1
SOUND i, .05
SOUND 32676, .1
NEXT i
PLAY "p2"
'----Strong water spray
FOR i = 1 TO 650
rg = rg + .5
SOUND RND * 900 + rg + 50, .05
SOUND 32676, .05
NEXT i
PLAY "p2"
'----Alien talking
FOR i = 50 TO 600 STEP 10
SOUND 32676, RND * .2 + .1
SOUND 400 + i * 2 + RND * 300, .1
NEXT i
PLAY "p2"
'----Climactic music
FOR i = 13000 TO 12020 STEP -10
SOUND i, 1 - rt
SOUND RND * 500 + 50, 1 - rt
SOUND 15000 - i, 1 - rt
SOUND 100, 1 - rt
rt = rt + .01
NEXT i
PLAY "p2"
'----Water pouring
FOR p = 1 TO 100 STEP 15
FOR i = 200 TO 50 STEP -10
SOUND i + RND * 10000, .2: SOUND 5676 - p * 10, .05: SOUND 100 + RND * 10000, .1
NEXT i
SOUND 32676, .6
SOUND 100, .1: SOUND 50, .3
NEXT p
PLAY "p2"
'----Pulsating generator
2 FOR p = 1 TO 100 STEP 15
FOR i = 200 TO 50 STEP -10
SOUND i, .2: SOUND 13676 - p * 10, .05: SOUND 100, .1
NEXT i
SOUND 32676, .6
SOUND 100, .1: SOUND 50, .3
NEXT p
PLAY "p2"
'----Spinner
3 rg = .01
FOR i = 1 TO 70
SOUND 400, .05
rg = rg * 1.1
SOUND 20000, rg
NEXT i
PLAY "p2"
'----Oscilating music notes
DIM rm(100): DIM rv(100)
FOR j = 1 TO 20
rm(j) = INT(RND * 600) + 150
IF RND < .8 THEN rv(j) = .2 ELSE rv(j) = .3
NEXT j
rm(31) = 1000: rv(31) = .4
FOR j = 1 TO 20
FOR i = 1 TO 20
SOUND rm(j) + RND * 25 - RND * 25, rv(j) + .1
NEXT i
SOUND 32676, .1
NEXT j
PLAY "p3"
'---Get object
667 SOUND 300, 1: SOUND 100, .5: SOUND 450, 1
SOUND 500, .1: SOUND 700, .5: PLAY "p3"
'---Walk
670 FOR YI = 1 TO 5
SOUND 70, .2: SOUND 100, .1: SOUND 32676, 3
NEXT YI: PLAY "p3"
'---Get/Use
671 SOUND 50, .1: SOUND 100, .5
FOR zi = 100 TO 600 STEP 100: SOUND zi, .1
NEXT zi
SOUND 700, .5: SOUND 1000, .5
PLAY "p3"
'---Opening passage
675 FOR di = 50 TO 100 STEP 5
SOUND di, .5: SOUND 10000, .1
NEXT di
FOR di = 100 TO 50 STEP -5
SOUND di, .5: SOUND 10000, .1
NEXT di
SOUND 32676, .5: SOUND 50, .5: PLAY "p3"
'---Open and shut cabine/safe
679 FOR di = 50 TO 80 STEP 1
SOUND 100, .1: SOUND di, .1
NEXT di
PLAY "p10"
FOR di = 1 TO 300 STEP 20
SOUND RND * 300 + 50, .1
NEXT di
SOUND 100, .2: SOUND 32676, 2: SOUND 100, .2: PLAY "p2"
'---Roar
FOR i = 50 TO 300 STEP 13
SOUND i, .2: SOUND 50, .3
NEXT i
FOR i = 300 TO 100 STEP -13
SOUND i, .2: SOUND 32676, .2: SOUND 80, .3
NEXT i
PLAY "p2"
'---plane crash
8 FOR i = 350 TO 50 STEP -2
SOUND i, .05: SOUND 32676, .3: SOUND 80, .1
NEXT i
SOUND 100, .1: SOUND 50, .3
FOR i = 1 TO 250
SOUND RND * 200 + 50, .05
SOUND 32676, .05
NEXT i
PLAY "p9p2"
'--buzz
 FOR i = 3300 TO 50 STEP -1
SOUND i, .05: SOUND 76, 0!: NEXT i
PLAY "p9p3"
'--alarm
FOR j = 1 TO 250: FOR i = 1 TO 50
SOUND 32676, 0
NEXT i: SOUND 32676, .7: NEXT j
PLAY "p2"
'--Subway
FOR i = 50 TO 500 STEP 2
SOUND i, .1
SOUND i * 2 - i + 25, .1: SOUND 32676, .1
NEXT i
FOR i = 1 TO 100
SOUND 500, .1: SOUND 525, .1: SOUND 32676, .1
NEXT i
FOR i = 500 TO 50 STEP -2
SOUND i, .1
SOUND i * 2 - i + 25, .1: SOUND 32676, .1
NEXT i

