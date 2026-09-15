'----- INSTALL.BAS - Dark Visions setup (DOS text-mode installer, QB4.5).
'----- Disk 1 carries INSTALL.EXE + GAME.ZIP + PKUNZIP.EXE and installs the game.
'----- If the player chooses the manual, it asks for Disk 2 (MANUAL.ZIP) and
'----- installs the 640x480 illustrated manual into the same folder.
'----- PKUNZIP is copied to the target with QB file I/O (NOT the DOS COPY command,
'----- which errors on real MS-DOS) so it is present after the Disk 2 swap. PKUNZIP
'----- output is shown on screen (no redirection) for maximum DOS compatibility.
DEFINT A-Z
TYPE RegTypeX
	ax AS INTEGER
	bx AS INTEGER
	cx AS INTEGER
	dx AS INTEGER
	bp AS INTEGER
	si AS INTEGER
	di AS INTEGER
	flags AS INTEGER
	ds AS INTEGER
	es AS INTEGER
END TYPE
DECLARE SUB INTERRUPTX (intnum AS INTEGER, inreg AS RegTypeX, outreg AS RegTypeX)
DECLARE SUB VbeInt (rx AS RegTypeX)
DECLARE FUNCTION ManualOK% ()
DECLARE FUNCTION VBb% (i AS INTEGER)
DECLARE FUNCTION VBw& (i AS INTEGER)
DECLARE SUB Backdrop ()
DECLARE SUB Panel (r1, c1, r2, c2, tit$)
DECLARE SUB Cent (r, s$)
DECLARE SUB At (r, c, s$)
DECLARE SUB Status (s$)
DECLARE SUB WaitKey ()
DECLARE SUB Quit ()
DECLARE SUB CopyFile (src$, dst$)
DECLARE FUNCTION Exists% (f$)
DECLARE FUNCTION YesNo% (r, defyes)
DECLARE FUNCTION GetPath$ (defp$)

DIM SHARED erflag AS INTEGER
DIM SHARED vbuf(0 TO 255) AS INTEGER
DIM dest AS STRING, wantman AS INTEGER, k AS STRING, ok AS INTEGER

'============ WELCOME ============
CALL Backdrop
CALL Panel(6, 15, 19, 66, " Setup ")
CALL Cent(8, "D A R K   V I S I O N S")
CALL Cent(10, "Setup Program")
CALL Cent(12, "This installs Dark Visions on your hard disk.")
CALL Cent(13, "You will need about 7 MB of free space.")
CALL Cent(16, "Press ENTER to continue  --  ESC to quit")
CALL Status("ENTER = continue     ESC = quit")
DO
	k = INKEY$
	IF k = CHR$(13) THEN EXIT DO
	IF k = CHR$(27) THEN CALL Quit
LOOP

'============ INSTALL LOCATION ============
CALL Backdrop
CALL Panel(7, 12, 16, 69, " Install Location ")
CALL Cent(9, "Where should Dark Visions be installed?")
dest = GetPath$("C:\DARKV")

'============ MANUAL CHOICE (only if the video card can show it) ============
CALL Backdrop
CALL Panel(7, 11, 18, 70, " Instruction Manual ")
IF ManualOK% THEN
	CALL Cent(9, "Your video card supports the illustrated manual.")
	CALL Cent(11, "Install it?  (640x480, 10 pages -- on Disk 2.)")
	wantman = YesNo%(14, -1)
ELSE
	wantman = 0
	CALL Cent(9, "This video card does not support the 640x480")
	CALL Cent(10, "SVGA/VESA graphics the illustrated manual needs.")
	CALL Cent(12, "The manual will be skipped.  The game still shows")
	CALL Cent(13, "text instructions if you answer YES at the start.")
	CALL Cent(16, "Press any key to continue.")
	CALL Status("Manual not supported on this system -- skipping")
	CALL WaitKey
END IF

'============ INSTALL GAME ============
CALL Backdrop
CALL Panel(8, 14, 13, 67, " Installing ")
CALL Cent(10, "Installing Dark Visions to")
COLOR 14, 1
CALL Cent(11, dest)
COLOR 7, 1
CALL Status("Please wait ...")
'----- make the target folder (ignore "already exists")
erflag = 0
ON ERROR GOTO fhandler
MKDIR dest
ON ERROR GOTO 0
'----- copy PKUNZIP to the hard disk with QB I/O so it survives the disk swap
CALL CopyFile("A:\PKUNZIP.EXE", dest + "\PKUNZIP.EXE")
IF Exists%(dest + "\PKUNZIP.EXE") = 0 THEN
	CALL Backdrop
	CALL Panel(8, 11, 15, 70, " Error ")
	CALL Cent(10, "Could not read PKUNZIP.EXE from drive A:.")
	CALL Cent(12, "Put Disk 1 in drive A: and run  INSTALL  again.")
	CALL Status("Press any key to quit")
	CALL WaitKey
	CALL Quit
END IF
'----- extract the game (PKUNZIP output shown on a clean screen, classic style)
COLOR 7, 0: CLS
COLOR 15, 0: PRINT " Installing Dark Visions game files, please wait ..."
PRINT
COLOR 7, 0
SHELL dest + "\PKUNZIP.EXE -o A:\GAME.ZIP " + dest + "\"
IF Exists%(dest + "\GAME.EXE") = 0 THEN
	CALL Backdrop
	CALL Panel(8, 11, 15, 70, " Error ")
	CALL Cent(10, "The game did not install.")
	CALL Cent(12, "Put Disk 1 in drive A: and run  INSTALL  again.")
	CALL Status("Press any key to quit")
	CALL WaitKey
	CALL Quit
END IF

'============ MANUAL (Disk 2) ============
IF wantman THEN
	CALL Backdrop
	CALL Panel(7, 9, 16, 72, " Instruction Manual  (Disk 2) ")
	CALL Cent(10, "Remove Disk 1, insert DISK 2 in drive A:,")
	CALL Cent(11, "then press ENTER.     ( ESC skips the manual )")
	CALL Status("Insert Disk 2, then press ENTER")
	ok = 0
	DO
		k = INKEY$
		IF k = CHR$(27) THEN EXIT DO
		IF k = CHR$(13) THEN
			IF Exists%("A:\MANUAL.ZIP") THEN
				ok = -1: EXIT DO
			ELSE
				CALL Cent(13, "MANUAL.ZIP not found on A: -- please insert Disk 2.")
			END IF
		END IF
	LOOP
	IF ok THEN
		COLOR 7, 0: CLS
		COLOR 15, 0: PRINT " Installing the illustrated manual, please wait ..."
		PRINT
		COLOR 7, 0
		SHELL dest + "\PKUNZIP.EXE -o A:\MANUAL.ZIP " + dest + "\"
	END IF
END IF

'============ DONE ============
CALL Backdrop
CALL Panel(7, 13, 18, 68, " Complete ")
CALL Cent(9, "Dark Visions is installed.")
CALL Cent(11, "To play, type:")
COLOR 14, 1
CALL Cent(13, "CD " + dest)
CALL Cent(14, "DARKV")
COLOR 7, 1
CALL Cent(16, "Enjoy -- and mind the shadows.")
CALL Status("Press any key to exit")
CALL WaitKey
CALL Quit

'----- module-level error trap (reached only via ON ERROR)
fhandler:
	erflag = -1
	RESUME NEXT

'==================== helpers ====================
SUB At (r, c, s$)
	COLOR 7, 1
	LOCATE r, c: PRINT s$;
END SUB

SUB Backdrop
	COLOR 7, 1: CLS
	COLOR 15, 3
	LOCATE 1, 1: PRINT SPACE$(80);
	LOCATE 1, 3: PRINT "DARK VISIONS  --  Setup";
	LOCATE 1, 62: PRINT "(c) 1993, 2026";
	COLOR 7, 1
END SUB

SUB Cent (r, s$)
	COLOR 15, 1
	LOCATE r, (80 - LEN(s$)) \ 2 + 1: PRINT s$;
	COLOR 7, 1
END SUB

'----- copy a file with QB binary I/O (no DOS COPY; real MS-DOS rejects some COPY forms)
SUB CopyFile (src$, dst$)
	DIM total AS LONG
	DIM bpos AS LONG
	erflag = 0
	ON ERROR GOTO fhandler
	fh1 = FREEFILE
	OPEN src$ FOR BINARY ACCESS READ AS #fh1
	IF erflag THEN
		ON ERROR GOTO 0
		EXIT SUB
	END IF
	total = LOF(fh1)
	fh2 = FREEFILE
	OPEN dst$ FOR OUTPUT AS #fh2
	CLOSE #fh2
	OPEN dst$ FOR BINARY AS #fh2
	bpos = 1
	DO WHILE bpos <= total
		chunk = 16384
		IF total - bpos + 1 < chunk THEN chunk = CINT(total - bpos + 1)
		buf$ = SPACE$(chunk)
		GET #fh1, bpos, buf$
		PUT #fh2, bpos, buf$
		bpos = bpos + chunk
	LOOP
	CLOSE #fh1
	CLOSE #fh2
	ON ERROR GOTO 0
END SUB

'----- editable path field with a default
FUNCTION GetPath$ (defp$)
	DIM p$, k$
	p$ = defp$
	COLOR 15, 1: LOCATE 12, 22: PRINT "Path:";
	DO
		COLOR 14, 1: LOCATE 12, 28: PRINT p$ + "_" + SPACE$(40 - LEN(p$));
		CALL Status("Type a path   BKSP = edit   ENTER = accept")
		DO: k$ = INKEY$: LOOP WHILE k$ = ""
		IF k$ = CHR$(13) THEN
			IF LEN(p$) > 0 THEN EXIT DO
		ELSEIF k$ = CHR$(8) THEN
			IF LEN(p$) > 0 THEN p$ = LEFT$(p$, LEN(p$) - 1)
		ELSEIF k$ = CHR$(27) THEN
			CALL Quit
		ELSEIF LEN(k$) = 1 THEN
			IF k$ >= " " AND LEN(p$) < 40 THEN p$ = p$ + UCASE$(k$)
		END IF
	LOOP
	GetPath$ = p$
END FUNCTION

SUB Panel (r1, c1, r2, c2, tit$)
	DIM r, w
	w = c2 - c1 + 1
	COLOR 15, 1
	LOCATE r1, c1: PRINT CHR$(201) + STRING$(w - 2, 205) + CHR$(187);
	FOR r = r1 + 1 TO r2 - 1
		LOCATE r, c1: PRINT CHR$(186) + SPACE$(w - 2) + CHR$(186);
	NEXT
	LOCATE r2, c1: PRINT CHR$(200) + STRING$(w - 2, 205) + CHR$(188);
	IF LEN(tit$) > 0 THEN
		COLOR 14, 1
		LOCATE r1, c1 + (w - LEN(tit$)) \ 2: PRINT tit$;
	END IF
	COLOR 7, 1
END SUB

SUB Quit
	COLOR 7, 0: CLS
	SCREEN 0: WIDTH 80
	SYSTEM
END SUB

SUB Status (s$)
	COLOR 15, 3
	LOCATE 25, 1: PRINT SPACE$(79);
	LOCATE 25, 3: PRINT s$;
	COLOR 7, 1
END SUB

SUB WaitKey
	DO: LOOP WHILE INKEY$ <> ""
	DO: LOOP WHILE INKEY$ = ""
END SUB

'----- highlighted Yes / No selector (arrows + ENTER, or Y/N)
FUNCTION YesNo% (r, defyes)
	DIM sel, k$
	sel = defyes
	DO
		IF sel THEN
			COLOR 0, 7: LOCATE r, 31: PRINT "  Yes  ";
			COLOR 15, 1: LOCATE r, 43: PRINT "  No  ";
		ELSE
			COLOR 15, 1: LOCATE r, 31: PRINT "  Yes  ";
			COLOR 0, 7: LOCATE r, 43: PRINT "  No  ";
		END IF
		COLOR 7, 1
		CALL Status("LEFT / RIGHT to choose     ENTER to accept")
		k$ = INKEY$
		IF LEN(k$) = 2 THEN
			IF ASC(RIGHT$(k$, 1)) = 75 THEN sel = -1
			IF ASC(RIGHT$(k$, 1)) = 77 THEN sel = 0
		ELSEIF k$ = CHR$(13) THEN
			YesNo% = sel: EXIT FUNCTION
		ELSEIF k$ = "Y" OR k$ = "y" THEN
			YesNo% = -1: EXIT FUNCTION
		ELSEIF k$ = "N" OR k$ = "n" THEN
			YesNo% = 0: EXIT FUNCTION
		END IF
	LOOP
END FUNCTION

FUNCTION Exists% (f$)
	DIM fh
	fh = FREEFILE
	erflag = 0
	ON ERROR GOTO fhandler
	OPEN f$ FOR INPUT AS #fh
	ON ERROR GOTO 0
	IF erflag = 0 THEN
		CLOSE #fh
		Exists% = -1
	ELSE
		Exists% = 0
	END IF
END FUNCTION

'----- one VESA INT 10h call with ES:DI -> vbuf (the 256-byte info block)
SUB VbeInt (rx AS RegTypeX)
	DIM rx2 AS RegTypeX, vi AS INTEGER
	rx.bp = 0: rx.si = 0: rx.flags = 0: rx.ds = -1
	rx.es = VARSEG(vbuf(0)): rx.di = VARPTR(vbuf(0))
	vi = &H10
	CALL INTERRUPTX(vi, rx, rx2)
	rx.ax = rx2.ax: rx.bx = rx2.bx: rx.cx = rx2.cx: rx.dx = rx2.dx
END SUB

'----- byte / word i of vbuf (unsigned)
FUNCTION VBb% (i AS INTEGER)
	DIM w AS LONG
	w = vbuf(i \ 2)
	IF w < 0 THEN w = w + 65536
	IF (i AND 1) THEN VBb% = w \ 256 ELSE VBb% = w AND 255
END FUNCTION

FUNCTION VBw& (i AS INTEGER)
	VBw& = VBb%(i) + 256& * VBb%(i + 1)
END FUNCTION

'----- TRUE if the card has VESA VBE with 640x480x256 (mode 101h) = what the
'----- illustrated manual needs. Non-destructive (query only, screen untouched).
FUNCTION ManualOK%
	DIM rx AS RegTypeX, i AS INTEGER
	ManualOK% = 0
	'----- VBE present? (4F00h -> "VESA" signature, AL = 4Fh)
	FOR i = 0 TO 255: vbuf(i) = 0: NEXT
	rx.ax = &H4F00: rx.bx = 0: rx.cx = 0: rx.dx = 0
	CALL VbeInt(rx)
	IF rx.ax <> &H4F THEN EXIT FUNCTION
	IF VBb%(0) <> 86 OR VBb%(1) <> 69 OR VBb%(2) <> 83 OR VBb%(3) <> 65 THEN EXIT FUNCTION
	'----- mode 101h (640x480x256) present + supported by this hardware?
	FOR i = 0 TO 255: vbuf(i) = 0: NEXT
	rx.ax = &H4F01: rx.bx = 0: rx.cx = &H101: rx.dx = 0
	CALL VbeInt(rx)
	IF rx.ax <> &H4F THEN EXIT FUNCTION
	IF (VBw&(0) AND 1) = 0 THEN EXIT FUNCTION
	IF VBw&(18) = 640 AND VBw&(20) = 480 AND VBb%(25) = 8 THEN ManualOK% = -1
END FUNCTION
