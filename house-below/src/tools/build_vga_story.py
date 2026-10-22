"""Authoring source for the DOS adventure's room graph and hotspot text."""
from pathlib import Path
import csv, json
ROOT=Path(__file__).resolve().parents[1]
rooms=[]
def room(title,desc):
    rooms.append(dict(title=title,description=desc,hotspots=[])); return len(rooms)
def hot(name,rect,kind,value,text,need=0):
    rooms[-1]['hotspots'].append(dict(name=name,rect=rect,kind=kind,value=value,need=need,text=text))
def exit(name,dest,need=0,text=None):
    hot(name,[0,0,0,0],1,dest,text or 'The passage leads to '+name+'.',need)
def obj(name,rect,action,text): hot(name,rect,3,action,text)
def person(name,x,y,who,text): hot(name,[x-12,y-43,x+12,y],4,who,text)
def take(name,rect,item,text): hot(name,rect,2,item,text)

room('RAVENHURST / OUTSIDE','The motorcar has stopped beside the open gates. Your coachman waits on the left, by the car. Across the wet drive, the lit front door promises shelter.')
person('Coachman',148,168,8,'A heavyset man in a rain-dark coat and scally cap. Beneath the coat: burgundy racing silks with gold diamonds, cream breeches and riding boots. Unusual clothes for a motorcar driver.')
obj('Motorcar',[0,85,138,165],120,'The motorcar that brought you from the village. Rain ticks on its roof; the engine coughs as it cools. Your uncle is waiting inside, according to his letter.')
obj('Ravenhurst plaque',[278,82,299,126],120,'Dr. Frank Mahler. Private practice. Below the name, someone scratched: THEY ASKED HIM TO STOP.')
obj('Iron gates',[245,74,273,160],120,'The gates stand open. A path of reflected lamplight leads from the car to the front door. You have not crossed the threshold yet.')
obj('House windows',[108,14,222,83],120,'Lamplight burns behind the rain-streaked windows. A shadow crosses an upstairs curtain, then disappears.')
exit('FRONT DOOR > Knock / enter',2,1,'Follow the drive to the front door. James will answer your knock and check your invitation.')
hot('Front door',[169,86,190,116],1,2,'The lit front door stands beyond the rain-soaked drive. ACT on it to knock. James will meet you there.',1)

room('THE ENTRANCE HALL','Warm light, cold stone. Somewhere beneath the staircase, machinery keeps time.')
obj('Family portrait',[49,22,80,75],120,'Frank beside his late wife. His expression is almost hopeful. The paint around her eyes is worn away.')
person('James',265,162,1,"James's dark coat is carefully brushed. His hands are folded. When he catches your eye, he straightens his cuffs.")
exit('Go outside',1,text='The front doors lead back down the drive to the iron gates and the rain.'); exit('Guest room',3); exit('Library',4); exit('Dining room',5)

room('THE GUEST ROOM','Your uncle prepared a room. He did not prepare an explanation. The clock has stopped.')
obj('Grandfather clock',[163,33,194,146],102,'A hand is missing. Scratched below the dial: VIII / IV. Eight hours, four five-minute marks.')
obj('Bedside letter',[195,100,228,131],120,'A half-written apology: If the clock opens the way, do not let the house decide who leaves.')
exit('Hall',2); exit('Hidden stairs',9,2)

room('THE LIBRARY','Books climb into shadow. A patient is reading the same sentence over and over.')
person('Elias Hart',124,162,2,'Elias keeps a brass key in his closed hand. He needs to know you have read the records.')
take('Brass clock hand',[190,118,220,142],3,'A clock hand has been used as a bookmark. Someone wanted the clock to remain silent.')
obj('Annotated volume',[35,80,75,126],120,'The margin reads: It let me read again. Then another voice began reading with me. Signed E.H.')
exit('Hall',2); exit('Study',7); exit('Chapel',13)

room('THE DINING ROOM','Six places are laid. No one has eaten. The silver reflects a room that feels too crowded.')
take('Bent hairpin',[106,109,144,134],2,'A bent hairpin beside an untouched plate. Thin enough to lift a simple drawer catch.')
obj('Place cards',[168,107,217,136],120,'Elias. Clara. Thomas. Miriam. Four names in careful handwriting. Two other chairs have no names.')
exit('Hall',2); exit('Conservatory',6)

room('THE CONSERVATORY','Moonlight filters through wet glass. Someone has kept the plants alive despite everything.')
person('Ada Finch',78,164,3,'The gardener smells of soil and lamp oil. She has seen lights beneath the lake.')
take('Oil can',[219,116,254,143],5,'A small can of machine oil. Its label warns that the generator bearings must never run dry.')
obj('Stone basin',[149,90,201,139],120,'The overflow runs toward the lake. Beneath it, pipes pulse with a sickly sweet vapor.')
exit('Dining',5); exit('Boathouse',14)

room("MAHLER'S STUDY",'Private letters. Altered charts. A locked drawer. This was never merely an invitation to observe.')
obj('Locked desk',[70,112,217,151],103,'The drawer is caught on a spring latch. A thin piece of wire could lift it.')
obj('Three-symbol safe',[260,50,300,113],104,'Three symbols guard the safe. An inscription reads: Follow the chapel glass from night into dawn.')
obj('Prescription notes',[112,92,180,112],120,'Preparation R. Early improvement. Later auditory phenomena. The later pages no longer mention permission.')
exit('Library',4); exit('Attic lab',8)

room('THE ATTIC LABORATORY','Your uncle is gone. The apparatus still breathes. His final work is not an answer; it is a choice.')
obj('Mixing apparatus',[38,62,128,145],110,'Three fictional reagents remain: azure, amber, clear. Read the notebook before mixing.')
obj('Laboratory notebook',[152,123,210,153],118,'A reversal sequence: AZURE, then AMBER, then CLEAR. It binds the vapor in the pipes. Do not give Preparation R to anyone.')
obj("Frank's last letter",[241,113,289,151],120,'I thought I could hear her. They asked me to stop. I wrote that down, and continued. Do not mistake my grief for an excuse.')
exit('Study',7)

room('THE HIDDEN STAIR','The clock slides aside. The air below is warmer than it should be, and carries a faint voice.')
obj('Pipe diagram',[43,58,78,113],120,'Power feeds ventilation. Ventilation feeds the ward. The reservoir carries the outflow. Shut the source before opening the gate.')
exit('Guest room',3); exit('Lower ward',10); exit('Generator',15)

room('THE LOWER WARD','Beds stand behind ironwork. These people are waiting for someone to believe them.')
person('Clara Vale',76,164,4,'Clara speaks steadily. She wants the names preserved, the vapor stopped, and a safe route out.')
person('Thomas Reed',260,164,5,'Thomas has watched the pressure gauge through sleepless nights.')
obj('Vapor inlet',[28,73,51,117],111,'A dosing inlet. The laboratory reversal mixture could bind the remaining vapor.')
obj('Ward gate',[176,44,218,115],112,'The gate is locked. Clara will not lead anyone out until the records, air and escape route are safe.')
exit('Stairs',9); exit('Archive',11); exit('Boiler',12); exit('Reservoir',16)

room('THE RECORD ARCHIVE','Names have been replaced by numbers. You can put them back before this house is emptied.')
obj('Patient register',[129,111,228,151],106,'Four folders, four missing names. Match them in admission order using Miriam and the brass nameplates.')
obj('Brass nameplates',[36,61,72,119],117,'Admissions: E.H. on Monday; C.V. on Tuesday; T.R. on Wednesday; M.B. on Thursday.')
person('Miriam Bell',269,166,6,'Miriam remembers every name. She refuses to leave as Patient Four.')
exit('Ward',10)

room('THE BOILER ROOM','A low mechanical heartbeat. Three controls separate the patients from the source of the vapor.')
obj('Pressure controls',[119,78,274,145],107,'Three valves: ISOLATE, RETURN, RELEASE. Thomas knows the safe sequence. The powered fan must run first.')
obj('Pressure gauge',[177,48,204,78],120,'The needle must return to zero before the ward can open. Forcing the release now would spread the vapor.')
exit('Ward',10); exit('Generator',15)

room('THE ABANDONED CHAPEL','A private chapel built for forgiveness. The organ has not been played in years.')
obj('Stained glass',[37,23,137,100],114,'Three emblems rise toward the light: MOON, STAR, SUN. The same shapes are cut into the study safe.')
obj('Organ keyboard',[238,107,292,145],108,'The score is marked C - E - G. A brass tuning fork rests behind a resonant latch.')
exit('Library',4)

room('THE BOATHOUSE','Across the lake lies a road, a village, and people who might listen. The boat is large enough for everyone.')
take('Coil of rope',[35,115,84,149],7,'A strong mooring rope. Enough to secure the reservoir crossing.')
obj('Rowboat',[94,111,199,159],113,'The oars are ready. You will not abandon the people beneath the house.')
exit('Conservatory',6); exit('Reservoir',16,9)

room('THE GENERATOR','Copper coils wait in silence. The motor needs a fuse and oil before it can drive the ventilation fan.')
obj('Fuse cabinet',[250,70,287,117],105,'The cabinet has an empty fuse socket. The safe in the study held the maintenance supplies.')
obj('Dry motor bearings',[124,106,206,151],115,'The bearings are dry. Add machine oil before starting this generator.')
exit('Stairs',9); exit('Boiler',12)

room('THE RESERVOIR','The bridge is damaged and the sluice is locked by a humming metal latch. The lake waits beyond.')
obj('Resonant sluice latch',[258,70,289,119],109,'A resonant latch, and a broken safety cable. A tuning fork can release it once a rope secures the crossing.')
obj('Bridge anchor',[117,95,159,133],116,'The bridge needs a new safety line before anyone can cross.')
exit('Ward',10); exit('Boathouse',14,9)

# Human height at the foreground floor line, spawn, and horizontal floor limits.
# Larger nearby furnishings need taller actors; the deeper stair/lake views use less.
staging = [
    (84,212,168,169,230), (80,148,168,32,289),
    (84,90,168,25,145),   (84,238,168,88,284),
    (88,254,169,25,292),  (84,137,168,45,288),
    (84,244,169,30,292),  (80,225,169,135,228),
    (76,98,168,30,179),   (84,152,169,58,287),
    (84,103,169,85,288),  (84,61,169,30,107),
    (80,157,169,95,221),  (76,153,169,30,292),
    (84,232,169,214,291), (76,55,167,27,73),
]
# Exit buttons are explicitly visible along the bottom of each scene.
for r,stage in zip(rooms,staging):
    r['staging']=dict(zip(('height','spawn_x','floor_y','left','right'),stage))
    for h in r['hotspots']:
        if h['kind']==4:
            x=(h['rect'][0]+h['rect'][2])//2; y=h['rect'][3]
            height=stage[0]+y-stage[2]
            width=2*((height*24+44)//88)
            h['rect']=[x-width//2,y-height+1,x+width//2-1,y]
    exits=[h for h in r['hotspots'] if h['kind']==1 and h['rect']==[0,0,0,0]]
    for i,h in enumerate(exits):
        w=316//len(exits); h['rect']=[2+i*w,171,1+(i+1)*w,182]
    assert len(r['hotspots'])<=12
out=ROOT/'VGA';out.mkdir(exist_ok=True)
with (out/'STAGE.DAT').open('w',newline='') as f:
    csv.writer(f,lineterminator='\r\n').writerows(staging)
with (out/'WORLD.DAT').open('w',newline='') as f:
    w=csv.writer(f,lineterminator='\r\n',quoting=csv.QUOTE_NONNUMERIC)
    for r in rooms:
        w.writerow([r['title'],r['description'],len(r['hotspots'])])
        for h in r['hotspots']:
            w.writerow(h['rect']+[h['kind'],h['value'],h['need'],h['name'],h['text']])
(ROOT/'ART'/'vga-world.json').write_text(json.dumps(rooms,indent=2)+'\n')
print(f'Exported {len(rooms)} rooms, {sum(len(r["hotspots"]) for r in rooms)} hotspots.')
