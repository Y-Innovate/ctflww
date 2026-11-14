       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM324.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * PUT /teamCaptains/{eventID}: the captain hands over captaincy *
      * to PLAYERID, a member of the same team. Possible at any time. *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Player not in your team                               *
      * 08 21 = Error: SQL error in SELECT                            *
      * 08 32 = Error: SQL error in UPDATE                            *
      * 08 50 = Error: no active place in a team, or not captain      *
      * 08 53 = Error: not a team event                               *
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
       01 P-LCTFM324.
           COPY LCTFM324.

       PROCEDURE DIVISION USING P-LCTFM324.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R100-GET-CONTEXT
           PERFORM R105-NEED-TEAMMODE
           PERFORM R101-NEED-TEAM

           IF RETURNCODE OF P-LCTFM324 = N'00'
              PERFORM R120-HAND-OVER
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM324
           MOVE N'00' TO REASONCODE OF P-LCTFM324
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM324
           MOVE EVENTID OF P-LCTFM324 TO W-EVENTID
           MOVE PLAYERID OF P-LCTFM324 TO W-TARGET
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R120-HAND-OVER: Only the captain, only to a member            *
      *===============================================================*
       R120-HAND-OVER SECTION.
           EXEC SQL
              UPDATE TBCTF005 T
                 SET CAPTAINID = :W-TARGET,
                     UPDATEDBY = :W-USERID,
                     UPDATEDDATE = CURRENT TIMESTAMP
               WHERE T.TEAMID = :W-TEAMID
                 AND T.CAPTAINID = :W-PLAYERID
                 AND EXISTS
                     (SELECT 1 FROM TBCTF006 PA
                       WHERE PA.EVENTID = :W-EVENTID
                         AND PA.PLAYERID = :W-TARGET
                         AND PA.TEAMID = T.TEAMID)
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              CONTINUE
           WHEN 100
              PERFORM R125-WHY-NOT
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM324
              MOVE N'32' TO REASONCODE OF P-LCTFM324
              STRING N'UPDATE team gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM324
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R120-HAND-OVER-END.
           EXIT.

      *===============================================================*
      * R125-WHY-NOT: Not the captain, or not a member                *
      *===============================================================*
       R125-WHY-NOT SECTION.
           EXEC SQL
              SELECT CAPTAINID
                INTO :DCLTBCTF005.CAPTAINID
                FROM TBCTF005
               WHERE TEAMID = :W-TEAMID
           END-EXEC

           EVALUATE TRUE
           WHEN SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM324
              MOVE N'21' TO REASONCODE OF P-LCTFM324
              STRING N'SELECT team gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM324
              PERFORM R900-DSNTIAR
           WHEN CAPTAINID OF DCLTBCTF005 NOT = W-PLAYERID
              MOVE N'08' TO RETURNCODE OF P-LCTFM324
              MOVE N'50' TO REASONCODE OF P-LCTFM324
              MOVE N'Only the captain can hand over' TO
                   INFOMESSAGE OF P-LCTFM324
           WHEN OTHER
              MOVE N'04' TO RETURNCODE OF P-LCTFM324
              MOVE N'01' TO REASONCODE OF P-LCTFM324
              MOVE N'This player is not in your team' TO
                   INFOMESSAGE OF P-LCTFM324
           END-EVALUATE
           .
       R125-WHY-NOT-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM324==.

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

       END PROGRAM CTFM324.
