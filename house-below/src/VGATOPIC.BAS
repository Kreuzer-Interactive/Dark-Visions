REM $DYNAMIC
DEFINT A-Z
'$INCLUDE: 'VGA.BI'

SUB AddTopic (id, text$, source$)
 topiccount = topiccount + 1
 topicid(topiccount) = id: topictext$(topiccount) = text$
 topicsource$(topiccount) = source$
END SUB

SUB BuildTopics (person)
 DIM previous
 previous = topiccount: topiccount = 0
 CALL SyncKnowledge
 SELECT CASE person
 CASE 1
  CALL AddTopic(1, "Why did my uncle invite me?", "")
  IF learned(kPatients) THEN
   CALL AddTopic(2, "About my uncle's patients...", SourceName$(learned(kPatients)))
  ELSEIF visited(10) THEN
   CALL AddTopic(2, "About the people downstairs...", "Your visit downstairs")
  END IF
  IF learned(kClock) THEN CALL AddTopic(3, "What is wrong with the clock?", SourceName$(learned(kClock)))
  CALL AddTopic(4, "Does anyone else live here?", "")
  CALL AddTopic(5, "Where should I begin?", "")
  CALL AddTopic(6, "Where is my uncle?", "")
 CASE 2
  IF flags(3) OR inv(10) THEN CALL AddTopic(1, "I read the treatment ledger.", "Treatment ledger")
  IF learned(kPreparation) THEN CALL AddTopic(2, "What did the preparation do?", SourceName$(learned(kPreparation)))
  IF learned(kWardKey) THEN
   IF inv(6) THEN
    CALL AddTopic(3, "About the ward key...", "Elias gave you the key")
   ELSE
    CALL AddTopic(3, "May I have the ward key?", "")
    topicsource$(topiccount) = SourceName$(learned(kWardKey))
   END IF
  END IF
  CALL AddTopic(4, "Can I help you?", "")
  CALL AddTopic(5, "What happened to you?", "")
  CALL AddTopic(6, "What do you want to do?", "")
 CASE 3
  IF learned(kLake) THEN CALL AddTopic(1, "How do I reach the lake?", SourceName$(learned(kLake)))
  IF learned(kMachine) THEN CALL AddTopic(2, "How can I fix the machinery?", SourceName$(learned(kMachine)))
  CALL AddTopic(3, "Why have you stayed here?", "")
  CALL AddTopic(4, "Where does this path lead?", "")
  CALL AddTopic(5, "What keeps you busy?", "")
  CALL AddTopic(6, "What kind of place is this?", "")
 CASE 4
  CALL AddTopic(1, "What must I do?", "")
  CALL AddTopic(2, "What happened with my uncle?", "")
  IF flags(6) AND flags(11) AND flags(9) THEN CALL AddTopic(3, "The names, air and route are safe.", "Your completed preparations")
  CALL AddTopic(4, "How are you feeling?", "")
  CALL AddTopic(5, "Who is here with you?", "")
  CALL AddTopic(6, "How long have you been here?", "")
 CASE 5
  IF learned(kPressure) THEN CALL AddTopic(1, "How do I release the pressure?", SourceName$(learned(kPressure)))
  IF learned(kFan) THEN CALL AddTopic(2, "How do I power the fan?", SourceName$(learned(kFan)))
  IF learned(kCrossing) THEN CALL AddTopic(3, "How can we cross the reservoir?", SourceName$(learned(kCrossing)))
  CALL AddTopic(4, "What did you work on?", "")
  CALL AddTopic(5, "Are you able to walk?", "")
  CALL AddTopic(6, "What are those voices?", "")
 CASE 6
  CALL AddTopic(1, "What are your names?", "")
  CALL AddTopic(2, "When did you arrive?", "")
  IF learned(kRescue) THEN CALL AddTopic(3, "What should we take with us?", SourceName$(learned(kRescue)))
  CALL AddTopic(4, "What would you like me to do?", "")
  CALL AddTopic(5, "What are these folders?", "")
  CALL AddTopic(6, "How are you holding up?", "")
 CASE 8
  CALL AddTopic(1, "What should I call you?", "")
  CALL AddTopic(2, "Do you know my uncle?", "")
  IF carscene = 0 THEN CALL AddTopic(3, "Will you be waiting?", "")
  IF flags(29) THEN CALL AddTopic(4, "Were you a jockey?", "His burgundy and gold silks")
  IF flags(28) THEN CALL AddTopic(5, "You used to drive horses?", "Pike's introduction")
  IF learned(kWindow) AND carscene = 0 THEN CALL AddTopic(6, "Did you see that shadow?", SourceName$(learned(kWindow)))
 END SELECT
 IF topiccount > previous THEN topicpage = 0
END SUB

FUNCTION ContextPick% (person, title$, greeting$)
 CALL BuildTopics(person)
 ContextPick% = TalkPick%(person, title$, greeting$, "", "", "")
END FUNCTION

SUB FillTopics (page)
 DIM i, n, lastpage
 lastpage = (topiccount - 1) \ 3
 topicpage = page
 IF topicpage < 0 THEN topicpage = lastpage
 IF topicpage > lastpage THEN topicpage = 0
 FOR i = 1 TO 3
  n = topicpage * 3 + i
  choices$(i) = "": rowid(i) = 0: rowsource$(i) = ""
  IF n <= topiccount THEN
   choices$(i) = topictext$(n): rowid(i) = topicid(n)
   rowsource$(i) = topicsource$(n)
  END IF
 NEXT
END SUB

FUNCTION PageInput%
 DIM delta
 PageInput% = 0
 IF topiccount <= 3 THEN EXIT FUNCTION
 IF keys$ = "[" OR keys$ = CHR$(0) + CHR$(73) THEN delta = -1
 IF keys$ = "]" OR keys$ = CHR$(0) + CHR$(81) THEN delta = 1
 IF click AND my >= 112 AND my < 124 THEN
  IF mx >= 224 AND mx < 244 THEN delta = -1
  IF mx >= 284 AND mx < 304 THEN delta = 1
 END IF
 IF delta THEN CALL FillTopics(topicpage + delta): PageInput% = -1
END FUNCTION

SUB TopicHeader
 DIM i, s$, col
 CALL Txt(18, 116, "* Clue   Blue = asked", 252)
 s$ = "Point at a question to see its source."
 i = ChoiceAt%(mx, my)
 IF i >= 1 AND i <= 3 THEN
  s$ = "A general question."
  IF rowsource$(i) <> "" THEN s$ = "From: " + rowsource$(i)
 END IF
 CALL Txt(18, 127, s$, 245)
 IF topiccount > 3 THEN
  CALL Txt(251, 104, "PgUp/Dn", 252)
  col = 243: IF mx >= 224 AND mx < 244 AND my >= 112 AND my < 124 THEN col = 250
  CALL Box(224, 112, 20, 12, col): CALL Txt(232, 115, "<", 246)
  col = 243: IF mx >= 284 AND mx < 304 AND my >= 112 AND my < 124 THEN col = 250
  CALL Box(284, 112, 20, 12, col): CALL Txt(292, 115, ">", 246)
  s$ = LTRIM$(STR$(topicpage + 1)) + "/" + LTRIM$(STR$((topiccount + 2) \ 3))
  CALL Txt(254, 115, s$, 246)
 END IF
END SUB
