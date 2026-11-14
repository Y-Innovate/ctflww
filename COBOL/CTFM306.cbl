       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM306.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * POST /participants: an active player joins another event with *
      * its code. Same checks as POST /registrations (CTFREGP): code, *
      * window and cap. In an individual event the team of one is     *
      * created. If the event has a RACF group, the place is pending  *
      * and a CONNECT job is made, with a job token in LCTFC910 for   *
      * the caller, who commits and then starts the submit task;      *
      * otherwise the place is active at once. Nothing is committed   *
      * here.                                                         *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 08 11 = Error: in this event already                          *
      * 08 12 = Error: SQL error in INSERT                            *
      * 08 21 = Error: SQL error in SELECT                            *
      * 08 32 = Error: SQL error in UPDATE                            *
      * 08 50 = Error: player not active                              *
      * 08 51 = Error: wrong code or registration closed              *
      * 08 52 = Error: event full                                     *
      * 08 90 = Error: CTFA990, CTFA991 or settings failed            *
      * ------------------------------------------------------------- *
      * Updates:                                                      *
      *                                                               *
      * Date     Who What                                             *
      * -------- --- ------------------------------------------------ *
      * yy/mm/dd ii  description                                      *
      *===============================================================*

       DATA DIVISION.
       WORKING-STORAGE SECTION.
           EXEC SQL INCLUDE SQLCA END-EXEC.

           EXEC SQL INCLUDE TBCTF002 END-EXEC.

           EXEC SQL INCLUDE TBCTF003 END-EXEC.

           EXEC SQL INCLUDE TBCTF004 END-EXEC.

           EXEC SQL INCLUDE TBCTF005 END-EXEC.

           EXEC SQL INCLUDE TBCTF006 END-EXEC.

       01 WORK.
          05 W-SQLCODE    PIC -99999.
          05 W-PGMNAME    PIC X(8).
          05 W-COUNT      PIC S9(9) COMP-5.
          05 W-SECOK      PIC X.

           COPY CTFCTXW.

       01 W-LCTFM910.
           COPY LCTFM910.

           COPY CTFSECW.

           COPY CTFREGW.

       01 ERROR-MESSAGE.
          05 ERROR-LEN    PIC S9(4) COMP
                                     VALUE +720.
          05 ERROR-TEXT   PIC X(72) OCCURS 10 TIMES
                INDEXED BY ERROR-INDEX.
       77 ERROR-TEXT-LEN  PIC S9(9) COMP
                                     VALUE +72.

       LINKAGE SECTION.
       01 P-LCTFM306.
           COPY LCTFM306.
       01 P-LCTFC910.
           COPY LCTFC910.

       PROCEDURE DIVISION USING P-LCTFM306 P-LCTFC910.
       MAIN SECTION.
           PERFORM R001-INIT
           PERFORM R090-GET-USERID

           IF RETURNCODE OF P-LCTFM306 = N'00'
              PERFORM R100-SELECT-PLAYER
           END-IF

           IF RETURNCODE OF P-LCTFM306 = N'00'
              PERFORM R110-CHECK-EVENT
           END-IF

           IF RETURNCODE OF P-LCTFM306 = N'00'
              PERFORM R115-NOT-JOINED
           END-IF

           IF RETURNCODE OF P-LCTFM306 = N'00'
              PERFORM R120-TAKE-PLACE
           END-IF

           IF RETURNCODE OF P-LCTFM306 = N'00'
              PERFORM R130-SECRETS
           END-IF

           IF   RETURNCODE OF P-LCTFM306 = N'00'
           AND PLAYMODE OF DCLTBCTF002 = C-I
              PERFORM R150-INSERT-TEAM
           END-IF

           IF RETURNCODE OF P-LCTFM306 = N'00'
              PERFORM R160-INSERT-PLACE
           END-IF

           IF   RETURNCODE OF P-LCTFM306 = N'00'
           AND RACFGROUP-IND OF DCLTBCTF002 >= 0
              PERFORM R170-INSERT-JOB
           END-IF

           IF RETURNCODE OF P-LCTFM306 = N'00'
              PERFORM R180-ANSWER
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM306
           MOVE N'00' TO REASONCODE OF P-LCTFM306
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM306
           MOVE SPACES TO PARTSTATUS OF P-LCTFM306
           MOVE 0 TO TEAMID OF P-LCTFM306
           INITIALIZE P-LCTFC910

      *    For CTFREGP: a CONNECT job, checked with a job token
           MOVE C-N TO W-NEW-ACTION
           MOVE -1 TO W-JOBHASH-IND
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R100-SELECT-PLAYER: The signed-in player, if active           *
      *===============================================================*
       R100-SELECT-PLAYER SECTION.
           EXEC SQL
              SELECT PLAYERID,
                     DISPLAYNAME,
                     DISPLAYKEY
                INTO :DCLTBCTF003.PLAYERID,
                     :DCLTBCTF003.DISPLAYNAME,
                     :DCLTBCTF003.DISPLAYKEY
                FROM TBCTF003
               WHERE RACFUSERID = :W-USERID
                 AND PLAYERSTATUS = :C-A
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              MOVE PLAYERID OF DCLTBCTF003 TO PLAYERID OF P-LCTFC910
           WHEN 100
              MOVE N'08' TO RETURNCODE OF P-LCTFM306
              MOVE N'50' TO REASONCODE OF P-LCTFM306
              MOVE N'Only an active player can join an event' TO
                   INFOMESSAGE OF P-LCTFM306
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM306
              MOVE N'21' TO REASONCODE OF P-LCTFM306
              STRING N'SELECT player gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM306
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R100-SELECT-PLAYER-END.
           EXIT.

      *===============================================================*
      * R115-NOT-JOINED: Not in this event yet                        *
      *===============================================================*
       R115-NOT-JOINED SECTION.
           EXEC SQL
              SELECT COUNT(*)
                INTO :W-COUNT
                FROM TBCTF006
               WHERE EVENTID = :DCLTBCTF002.EVENTID
                 AND PLAYERID = :DCLTBCTF003.PLAYERID
           END-EXEC

           EVALUATE TRUE
           WHEN SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM306
              MOVE N'21' TO REASONCODE OF P-LCTFM306
              STRING N'SELECT place gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM306
              PERFORM R900-DSNTIAR
           WHEN W-COUNT > 0
              MOVE N'08' TO RETURNCODE OF P-LCTFM306
              MOVE N'11' TO REASONCODE OF P-LCTFM306
              MOVE N'You joined this event already' TO
                   INFOMESSAGE OF P-LCTFM306
           END-EVALUATE
           .
       R115-NOT-JOINED-END.
           EXIT.

      *===============================================================*
      * R130-SECRETS: Join code; with a group a job token             *
      *===============================================================*
       R130-SECRETS SECTION.
           MOVE 'Y' TO W-SECOK

           IF RACFGROUP-IND OF DCLTBCTF002 >= 0
              MOVE C-P TO W-NEW-PARTSTATUS
           ELSE
              MOVE C-A TO W-NEW-PARTSTATUS
           END-IF

           IF PLAYMODE OF DCLTBCTF002 = C-I
              PERFORM R800-NEW-TOKEN
              IF A991-OK
                 MOVE W-TOKEN(1:12) TO W-JOINCODE
              ELSE
                 MOVE 'N' TO W-SECOK
              END-IF
           END-IF

           IF  W-SECOK = 'Y'
           AND RACFGROUP-IND OF DCLTBCTF002 >= 0
              MOVE N'R' TO OPCODE OF W-LCTFM910
              MOVE 'CTFM910' TO W-PGMNAME
              CALL W-PGMNAME USING W-LCTFM910 P-LCTFC910
              IF RETURNCODE OF W-LCTFM910 NOT = N'00'
                 MOVE N'08' TO RETURNCODE OF P-LCTFM306
                 MOVE N'90' TO REASONCODE OF P-LCTFM306
                 MOVE INFOMESSAGE OF W-LCTFM910 TO
                      INFOMESSAGE OF P-LCTFM306
              END-IF
              IF RETURNCODE OF P-LCTFM306 = N'00'
                 PERFORM R800-NEW-TOKEN
                 IF A991-OK
                    PERFORM R810-DERIVE
                 END-IF
                 IF A991-OK
                    MOVE W-TOKENHASH TO W-JOBHASH
                    MOVE 0 TO W-JOBHASH-IND
                    MOVE W-TOKEN TO JOBTOKEN OF P-LCTFC910
                 ELSE
                    MOVE 'N' TO W-SECOK
                 END-IF
              END-IF
           END-IF

           IF W-SECOK = 'N'
              MOVE N'08' TO RETURNCODE OF P-LCTFM306
              MOVE N'90' TO REASONCODE OF P-LCTFM306
              MOVE N'CTFA991 failed' TO
                   INFOMESSAGE OF P-LCTFM306
           END-IF

           MOVE SPACES TO W-TOKEN
           MOVE SPACES TO W-PHRASE
           .
       R130-SECRETS-END.
           EXIT.

      *===============================================================*
      * R180-ANSWER: Status of the place, and the team                *
      *===============================================================*
       R180-ANSWER SECTION.
           MOVE W-NEW-PARTSTATUS TO PARTSTATUS OF P-LCTFM306
           IF PLAYMODE OF DCLTBCTF002 = C-I
              MOVE W-NEW-TEAMID TO TEAMID OF P-LCTFM306
           END-IF
           .
       R180-ANSWER-END.
           EXIT.

           COPY CTFSECP.

           COPY CTFREGP REPLACING ==:IO:== BY ==P-LCTFM306==.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM306==.

      *===============================================================*
      * R900-DSNTIAR: Format SQLCA information when error             *
      *===============================================================*
       R900-DSNTIAR SECTION.
           CALL 'DSNTIAR' USING SQLCA ERROR-MESSAGE ERROR-TEXT-LEN

           PERFORM VARYING ERROR-INDEX
              FROM 1 BY 1 UNTIL ERROR-INDEX = 10
                   DISPLAY ERROR-TEXT(ERROR-INDEX)
           END-PERFORM
           .
       R900-DSNTIAR-END.
           EXIT.

       END PROGRAM CTFM306.
