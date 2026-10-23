REM $DYNAMIC
' Dark Visions: The House Below. QuickBASIC 4.5 / uGL / DOS.
' 320x200 indexed VGA (mode 13h), 16 illustrated rooms, persistent inventory.
DEFINT A-Z
'$INCLUDE: 'UGL.BI'
DECLARE SUB Txt (x, y, s$, c)
DECLARE FUNCTION Tw% (s$)
DECLARE FUNCTION Pow2% (n)
DECLARE SUB Wrap (x, y, s$, c, wide)
DECLARE SUB Box (x, y, w, h, c)
DECLARE SUB DrawScene ()
DECLARE SUB Present ()
DECLARE SUB Cursor ()
DECLARE SUB InitPointer ()
DECLARE SUB EndPointer ()
DECLARE SUB ReadPointer (x, y, buttons)
DECLARE SUB PositionPointer (x, y)
DECLARE SUB RefreshPointer ()
DECLARE SUB Actor (x, y, who, stepn)
DECLARE SUB InitActors ()
DECLARE SUB PrepareActors (n)
DECLARE SUB WalkPlayer ()
DECLARE SUB CheckActors ()
DECLARE SUB CheckTalk ()
DECLARE SUB CheckPortraits ()
DECLARE FUNCTION FacePixels% (dc AS LONG, w, h, x, y, flipped)
DECLARE SUB BeginTalk (person)
DECLARE SUB EndTalk ()
DECLARE SUB Speak (person, title$, text$)
DECLARE SUB Reply (mood, title$, text$)
DECLARE SUB PrepareFaces ()
DECLARE SUB DrawFaces ()
DECLARE FUNCTION PortraitFile$ (person, mood, quiet)
DECLARE SUB DrawDialog ()
DECLARE SUB DrawSpeech ()
DECLARE SUB StartSpeech (stamp AS SINGLE)
DECLARE SUB AdvanceSpeech (stamp AS SINGLE)
DECLARE FUNCTION Speaking% ()
DECLARE FUNCTION RevealSpeech% (requested)
DECLARE SUB RevealWrap (x, y, text$, wide, shown)
DECLARE SUB RevealWrapInk (x, y, text$, wide, shown, ink)
DECLARE SUB SpeechLayout ()
DECLARE FUNCTION PageStart% ()
DECLARE FUNCTION PageEnd% ()
DECLARE FUNCTION NextPage% ()
DECLARE FUNCTION OnLastPage% ()
DECLARE FUNCTION MenuMode% ()
DECLARE FUNCTION LeaveAt% (x, y)
DECLARE SUB RRect (x0, y0, x1, y1, c)
DECLARE SUB DrawPanel (edge)
DECLARE SUB DrawTail (tipx, edge)
DECLARE SUB DrawTickets ()
DECLARE SUB CheckSpeech ()
DECLARE SUB CheckContext ()
DECLARE SUB Learn (fact, origin)
DECLARE SUB Observe (h)
DECLARE SUB SyncKnowledge ()
DECLARE SUB LegacyKnowledge ()
DECLARE SUB RescuePlan (origin)
DECLARE FUNCTION SourceName$ (origin)
DECLARE SUB BuildTopics (person)
DECLARE SUB AddTopic (id, text$, source$)
DECLARE SUB FillTopics (page)
DECLARE SUB AddTopicR (id, text$, source$)
DECLARE FUNCTION ContextPick% (person, title$, greeting$)
DECLARE SUB SetChoices ()
DECLARE SUB StepChoice (delta)
DECLARE FUNCTION ChoiceAt% (x, y)
DECLARE FUNCTION TextLines% (text$, wide)
DECLARE FUNCTION FaceName$ (person)
DECLARE SUB Icon (x, y, item)
DECLARE SUB EnterRoom (n)
DECLARE SUB Act (h)
DECLARE SUB Travel (h)
DECLARE SUB Opening ()
DECLARE SUB CarBackdrop ()
DECLARE SUB LetterBackdrop ()
DECLARE FUNCTION ReadLetter% ()
DECLARE SUB DrawOpening (dx, dy)
DECLARE FUNCTION CarReveal% ()
DECLARE FUNCTION IntroWait% (seconds AS SINGLE, advance)
DECLARE SUB DoorShade (level)
DECLARE SUB CoachmanTalk ()
DECLARE SUB FrontDoor ()
DECLARE SUB PlayerSays (text$)
DECLARE SUB CheckOpening ()
DECLARE SUB Special (n)
DECLARE SUB Talk (n)
DECLARE SUB JamesPatients ()
DECLARE SUB Say (title$, body$)
DECLARE FUNCTION Pick% (title$, body$, a$, b$, c$)
DECLARE FUNCTION TalkPick% (person, title$, body$, a$, b$, c$)
DECLARE SUB Poll ()
DECLARE FUNCTION Hit% (x, y)
DECLARE SUB Give (n, s$)
DECLARE SUB Journal ()
DECLARE SUB MapPage ()
DECLARE SUB SaveGame (slot)
DECLARE SUB LoadGame (slot)
DECLARE SUB DumpFrame (n)
DECLARE SUB TestGame ()
DECLARE SUB Check (ok, label$)
DECLARE FUNCTION FindHot% (value, kind)
DECLARE SUB Finish ()

COMMON SHARED video AS LONG, back AS LONG, art AS LONG
COMMON SHARED pal() AS tRGB
COMMON SHARED rt$(), rd$(), hn(), visited()
COMMON SHARED hx(), hy(), hr(), hb(), hk(), hv(), need()
COMMON SHARED names$(), descs$(), fw(), bits()
COMMON SHARED flags(), inv(), items$(), invlist()
' Stable topic IDs use six bits in flags 20-25 and 27; 26 is legacy James.
CONST kWindow = 1, kClock = 2, kPatients = 3, kPreparation = 4
CONST kWardKey = 5, kLake = 6, kMachine = 7, kRescue = 8
CONST kPressure = 9, kFan = 10, kCrossing = 11, kNames = 12
CONST kRecords = 13, kGrief = 14
' Conversation panel (mode 13h): bottom speech/menu panel and where the two busts stand.
CONST pnX0 = 5, pnX1 = 314, pnY0 = 145, pnY1 = 196
COMMON SHARED learned(), topicid(), topictext$(), topicsource$(), topicrep()
COMMON SHARED rowid(), rowsource$(), topiccount, topicpage
COMMON SHARED room, verb, selected, invpage, mx, my, click, rightclick, hover
COMMON SHARED oldleft, oldright, mouseok, keys$, px, py, tx, frame, hints, soundon
COMMON SHARED modal, heading$, body$, choices$(), nchoices, answer, testing, testpick
COMMON SHARED talkmenu, choicetop
COMMON SHARED choicex, choicew, choicestep, choiceh
COMMON SHARED convperson, convquit, utterance$, lastreply$
COMMON SHARED carscene, playerline, introshot
COMMON SHARED faceDC AS LONG, youDC AS LONG
COMMON SHARED faceMood, youMood, faceKey, youKey
COMMON SHARED speechcount, speechend
COMMON SHARED speechclock AS SINGLE, speechcredit AS SINGLE, speechdelay AS SINGLE
COMMON SHARED testtalk$, testforce
DECLARE FUNCTION RowHas% (person, id)
COMMON SHARED ioerr, running, dirty, oldmx, oldmy, countinv, failcount, testrun
COMMON SHARED sprites() AS LONG
