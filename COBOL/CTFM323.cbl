       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM323.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * DELETE /teamMembers/{playerID}: with the player's own ID,     *
      * leaves the team; a captain with other members has to hand over*
      * first, and the last member deletes the team. With another ID, *
      * the captain removes that member. Only before the event starts,*
      * so points cannot move between teams.                          *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Player not in your team                               *
      * 08 21 = Error: SQL error in SELECT                            *
      * 08 32 = Error: SQL error in UPDATE                            *
      * 08 42 = Error: SQL error in DELETE                            *
      * 08 50 = Error: no active place in a team, or not captain      *
      * 08 53 = Error: not a team event, event started, captain       *
      *         has to hand over first, or team changed meanwhile     *
      * 08 90 = Error: CTFA990 failed                                 *
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

           EXEC SQL INCLUDE TBCTF005 END-EXEC.

       01 WORK.
          05 W-SQLCODE    PIC -99999.
          05 W-TARGET     PIC S9(9) COMP-5.

           COPY CTFCTXW.

       01 ERROR-MESSAGE.
          05 ERROR-LEN    PIC S9(4) COMP
                                     VALUE +720.
          05 ERROR-TEXT   PIC X(72) OCCURS 10 TIMES
                INDEXED BY ERROR-INDEX.
       77 ERROR-TEXT-LEN  PIC S9(9) COMP
                                     VALUE +72.

       LINKAGE SECTION.
       01 P-LCTFM323.
           COPY LCTFM323.

       PROCEDURE DIVISION USING P-LCTFM323.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R100-GET-CONTEXT
           PERFORM R105-NEED-TEAMMODE
           PERFORM R101-NEED-TEAM

           IF  RETURNCODE OF P-LCTFM323 = N'00'
           AND W-STARTED = 'Y'
              MOVE N'08' TO RETURNCODE OF P-LCTFM323
              MOVE N'53' TO REASONCODE OF P-LCTFM323
              MOVE N'Nobody can leave a team after the start' TO
                   INFOMESSAGE OF P-LCTFM323
           END-IF

           IF RETURNCODE OF P-LCTFM323 = N'00'
              PERFORM R120-SELECT-TEAM
           END-IF

           IF RETURNCODE OF P-LCTFM323 = N'00'
              PERFORM R130-CHECK-RULES
           END-IF

           IF RETURNCODE OF P-LCTFM323 = N'00'
              PERFORM R140-UPDATE-PLACE
           END-IF

           IF RETURNCODE OF P-LCTFM323 = N'00'
              PERFORM R150-UPDATE-TEAM
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM323
           MOVE N'00' TO REASONCODE OF P-LCTFM323
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM323
           MOVE EVENTID OF P-LCTFM323 TO W-EVENTID
           MOVE PLAYERID OF P-LCTFM323 TO W-TARGET
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R120-SELECT-TEAM: Captain and size of the team                *
      *===============================================================*
       R120-SELECT-TEAM SECTION.
           EXEC SQL
              SELECT CAPTAINID,
                     MEMBERCOUNT
                INTO :DCLTBCTF005.CAPTAINID,
                     :DCLTBCTF005.MEMBERCOUNT
                FROM TBCTF005
               WHERE TEAMID = :W-TEAMID
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM323
              MOVE N'21' TO REASONCODE OF P-LCTFM323
              STRING N'SELECT team gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM323
              PERFORM R900-DSNTIAR
           END-IF
           .
       R120-SELECT-TEAM-END.
           EXIT.

      *===============================================================*
      * R130-CHECK-RULES: Leave yourself, or captain removes          *
      *===============================================================*
       R130-CHECK-RULES SECTION.
           EVALUATE TRUE
           WHEN W-TARGET = W-PLAYERID
              IF  CAPTAINID OF DCLTBCTF005 = W-PLAYERID
              AND MEMBERCOUNT OF DCLTBCTF005 > 1
                 MOVE N'08' TO RETURNCODE OF P-LCTFM323
                 MOVE N'53' TO REASONCODE OF P-LCTFM323
                 MOVE N'Hand over captaincy before you leave' TO
                      INFOMESSAGE OF P-LCTFM323
              END-IF
           WHEN CAPTAINID OF DCLTBCTF005 NOT = W-PLAYERID
              MOVE N'08' TO RETURNCODE OF P-LCTFM323
              MOVE N'50' TO REASONCODE OF P-LCTFM323
              MOVE N'Only the captain can remove a member' TO
                   INFOMESSAGE OF P-LCTFM323
           END-EVALUATE
           .
       R130-CHECK-RULES-END.
           EXIT.

      *===============================================================*
      * R140-UPDATE-PLACE: Take the place out of the team             *
      *===============================================================*
       R140-UPDATE-PLACE SECTION.
           EXEC SQL
              UPDATE TBCTF006
                 SET TEAMID = NULL,
                     UPDATEDBY = :W-USERID,
                     UPDATEDDATE = CURRENT TIMESTAMP
               WHERE EVENTID = :W-EVENTID
                 AND PLAYERID = :W-TARGET
                 AND TEAMID = :W-TEAMID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              CONTINUE
           WHEN 100
              MOVE N'04' TO RETURNCODE OF P-LCTFM323
              MOVE N'01' TO REASONCODE OF P-LCTFM323
              MOVE N'This player is not in your team' TO
                   INFOMESSAGE OF P-LCTFM323
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM323
              MOVE N'32' TO REASONCODE OF P-LCTFM323
              STRING N'UPDATE place gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM323
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R140-UPDATE-PLACE-END.
           EXIT.

      *===============================================================*
      * R150-UPDATE-TEAM: One member less; the last one deletes       *
      *===============================================================*
       R150-UPDATE-TEAM SECTION.
           IF  W-TARGET = W-PLAYERID
           AND MEMBERCOUNT OF DCLTBCTF005 = 1
      *       Guarded: someone may have joined since R120
              EXEC SQL
                 DELETE
                   FROM TBCTF005
                  WHERE TEAMID = :W-TEAMID
                    AND MEMBERCOUNT = 1
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 MOVE N'08' TO RETURNCODE OF P-LCTFM323
                 MOVE N'53' TO REASONCODE OF P-LCTFM323
                 MOVE N'Your team changed just now; try again' TO
                      INFOMESSAGE OF P-LCTFM323
              WHEN OTHER
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM323
                 MOVE N'42' TO REASONCODE OF P-LCTFM323
                 STRING N'DELETE team gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM323
                 PERFORM R900-DSNTIAR
              END-EVALUATE
           ELSE
              EXEC SQL
                 UPDATE TBCTF005
                    SET MEMBERCOUNT = MEMBERCOUNT - 1,
                        UPDATEDBY = :W-USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE TEAMID = :W-TEAMID
              END-EXEC

              IF SQLCODE NOT = 0
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM323
                 MOVE N'32' TO REASONCODE OF P-LCTFM323
                 STRING N'UPDATE team gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM323
                 PERFORM R900-DSNTIAR
              END-IF
           END-IF
           .
       R150-UPDATE-TEAM-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM323==.

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

       END PROGRAM CTFM323.
