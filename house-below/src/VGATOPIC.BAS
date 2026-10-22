REM $DYNAMIC
DEFINT A-Z
'$INCLUDE: 'VGA.BI'

SUB AddTopic (id, text$, source$)
 topiccount = topiccount + 1
 topicid(topiccount) = id: topictext$(topiccount) = text$
 topicsource$(topiccount) = source$: topicrep(topiccount) = 0
END SUB

' A topic whose answer changes with the story stays in the menu after it is asked.
SUB AddTopicR (id, text$, source$)
 CALL AddTopic(id, text$, source$)
 topicrep(topiccount) = -1
END SUB

SUB BuildTopics (person)
 DIM previous
 previous = topiccount: topiccount = 0
 CALL SyncKnowledge
 SELECT CASE person
 CASE 1
  CALL AddTopic(1, "Why did my uncle invite me?", "")
  IF learned(kPatients) THEN
   CALL AddTopicR(2, "Tell me about the patients.", SourceName$(learned(kPatients)))
  ELSEIF visited(10) THEN
   CALL AddTopicR(2, "Who are the people downstairs?", "Your visit downstairs")
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
    CALL AddTopicR(3, "Tell me about the ward key.", "Elias gave you the key")
   ELSE
    CALL AddTopicR(3, "May I have the ward key?", "")
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

' The menu shows the first three questions you have not asked yet (clue questions come first
' in each person's list). Asked questions vanish; new ones appear as you learn things.
SUB FillTopics (page)
 DIM i, n, k
 topicpage = 0
 FOR i = 1 TO 3
  choices$(i) = "": rowid(i) = 0: rowsource$(i) = ""
 NEXT
 k = 0
 FOR n = 1 TO topiccount
  IF k < 3 THEN
   IF topicrep(n) OR (flags(19 + talkmenu) AND Pow2%(topicid(n) - 1)) = 0 THEN
    k = k + 1
    choices$(k) = topictext$(n): rowid(k) = topicid(n): rowsource$(k) = topicsource$(n)
   END IF
  END IF
 NEXT
END SUB
