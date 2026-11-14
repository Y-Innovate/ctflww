       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM321.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * POST /teams: creates a team in a team event, with a random    *
      * join code, and makes the player its captain. Team names are   *
      * unique per event regardless of case. Only while registration  *
      * is open, and for a player with an active place and no team    *
      * yet.                                                          *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 08 02 = Error: team name required                             *
      * 08 11 = Error: team name taken                                *
      * 08 12 = Error: SQL error in INSERT                            *
      * 08 21 = Error: SQL error in SELECT                            *
      * 08 32 = Error: SQL error in UPDATE                            *
      * 08 50 = Error: not in the event, or place not active          *
      * 08 53 = Error: not a team event, registration closed, or in   *
      *         a team already                                        *
      * 08 90 = Error: CTFA990 or CTFA991 failed                      *
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
          05 W-JOINCODE   PIC X(12).
          05 W-NEWTEAMID  PIC S9(9) COMP-5.

           COPY CTFCTXW.

           COPY CTFSECW.

       01 ERROR-MESSAGE.
          05 ERROR-LEN    PIC S9(4) COMP
                                     VALUE +720.
          05 ERROR-TEXT   PIC X(72) OCCURS 10 TIMES
                INDEXED BY ERROR-INDEX.
       77 ERROR-TEXT-LEN  PIC S9(9) COMP
                                     VALUE +72.

       LINKAGE SECTION.
       01 P-LCTFM321.
           COPY LCTFM321.

       PROCEDURE DIVISION USING P-LCTFM321.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R100-GET-CONTEXT
           PERFORM R105-NEED-TEAMMODE
           PERFORM R104-NEED-ACTIVE

           IF RETURNCODE OF P-LCTFM321 = N'00'
              PERFORM R110-CHECK-PLACE
           END-IF

           IF RETURNCODE OF P-LCTFM321 = N'00'
              PERFORM R130-JOINCODE
           END-IF

           IF RETURNCODE OF P-LCTFM321 = N'00'
              PERFORM R140-INSERT-TEAM
           END-IF

           IF RETURNCODE OF P-LCTFM321 = N'00'
              PERFORM R150-UPDATE-PLACE
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM321
           MOVE N'00' TO REASONCODE OF P-LCTFM321
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM321
           MOVE EVENTID OF P-LCTFM321 TO W-EVENTID
           MOVE 0 TO TEAMID OF P-LCTFM321
           MOVE SPACES TO JOINCODE OF P-LCTFM321

           IF TEAMNAME-LEN OF P-LCTFM321 <= 0
           OR TEAMNAME-LEN OF P-LCTFM321 > 30
           OR TEAMNAME-TEXT OF P-LCTFM321
                 (1:TEAMNAME-LEN OF P-LCTFM321) = SPACES
              MOVE N'08' TO RETURNCODE OF P-LCTFM321
              MOVE N'02' TO REASONCODE OF P-LCTFM321
              MOVE N'Team name is required' TO
                   INFOMESSAGE OF P-LCTFM321
           END-IF
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R110-CHECK-PLACE: No team yet, registration open              *
      *===============================================================*
       R110-CHECK-PLACE SECTION.
           EVALUATE TRUE
           WHEN W-TEAMID-IND >= 0
              MOVE N'08' TO RETURNCODE OF P-LCTFM321
              MOVE N'53' TO REASONCODE OF P-LCTFM321
              MOVE N'You are in a team already' TO
                   INFOMESSAGE OF P-LCTFM321
           WHEN W-REGOPEN NOT = 'Y'
              MOVE N'08' TO RETURNCODE OF P-LCTFM321
              MOVE N'53' TO REASONCODE OF P-LCTFM321
              MOVE N'Registration for this event is closed' TO
                   INFOMESSAGE OF P-LCTFM321
           END-EVALUATE
           .
       R110-CHECK-PLACE-END.
           EXIT.

      *===============================================================*
      * R130-JOINCODE: A random join code (CTFA991)                   *
      *===============================================================*
       R130-JOINCODE SECTION.
           PERFORM R800-NEW-TOKEN

           IF A991-OK
              MOVE W-TOKEN(1:12) TO W-JOINCODE
           ELSE
              MOVE N'08' TO RETURNCODE OF P-LCTFM321
              MOVE N'90' TO REASONCODE OF P-LCTFM321
              MOVE N'CTFA991 failed' TO
                   INFOMESSAGE OF P-LCTFM321
           END-IF
           .
       R130-JOINCODE-END.
           EXIT.

      *===============================================================*
      * R140-INSERT-TEAM: INSERT the team; -803 = name taken          *
      *===============================================================*
       R140-INSERT-TEAM SECTION.
           MOVE TEAMNAME OF P-LCTFM321 TO TEAMNAME OF DCLTBCTF005
           MOVE TEAMNAME OF P-LCTFM321 TO TEAMKEY OF DCLTBCTF005
           MOVE SPACES TO TEAMKEY-TEXT OF DCLTBCTF005
           MOVE FUNCTION UPPER-CASE(
              TEAMNAME-TEXT OF P-LCTFM321
                 (1:TEAMNAME-LEN OF P-LCTFM321)) TO
              TEAMKEY-TEXT OF DCLTBCTF005
           MOVE FUNCTION NATIONAL-OF(W-JOINCODE) TO
                JOINCODE OF DCLTBCTF005

           EXEC SQL
              SELECT TEAMID
                INTO :W-NEWTEAMID
                FROM FINAL TABLE
                   (
              INSERT
                INTO TBCTF005
                     (EVENTID,
                      TEAMNAME,
                      TEAMKEY,
                      JOINCODE,
                      CAPTAINID,
                      MEMBERCOUNT,
                      CREATEDBY,
                      CREATEDDATE,
                      UPDATEDBY,
                      UPDATEDDATE)
              VALUES(:W-EVENTID,
                     :DCLTBCTF005.TEAMNAME,
                     :DCLTBCTF005.TEAMKEY,
                     :DCLTBCTF005.JOINCODE,
                     :W-PLAYERID,
                     1,
                     :W-USERID,
                     CURRENT TIMESTAMP,
                     :W-USERID,
                     CURRENT TIMESTAMP)
                     )
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              CONTINUE
           WHEN -803
              MOVE N'08' TO RETURNCODE OF P-LCTFM321
              MOVE N'11' TO REASONCODE OF P-LCTFM321
              MOVE N'This team name is taken' TO
                   INFOMESSAGE OF P-LCTFM321
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM321
              MOVE N'12' TO REASONCODE OF P-LCTFM321
              STRING N'INSERT team gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM321
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R140-INSERT-TEAM-END.
           EXIT.

      *===============================================================*
      * R150-UPDATE-PLACE: Put the place in the team                  *
      *===============================================================*
       R150-UPDATE-PLACE SECTION.
           EXEC SQL
              UPDATE TBCTF006
                 SET TEAMID = :W-NEWTEAMID,
                     UPDATEDBY = :W-USERID,
                     UPDATEDDATE = CURRENT TIMESTAMP
               WHERE EVENTID = :W-EVENTID
                 AND PLAYERID = :W-PLAYERID
                 AND TEAMID IS NULL
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              MOVE W-NEWTEAMID TO TEAMID OF P-LCTFM321
              MOVE JOINCODE OF DCLTBCTF005 TO JOINCODE OF P-LCTFM321
           WHEN 100
              MOVE N'08' TO RETURNCODE OF P-LCTFM321
              MOVE N'53' TO REASONCODE OF P-LCTFM321
              MOVE N'You are in a team already' TO
                   INFOMESSAGE OF P-LCTFM321
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM321
              MOVE N'32' TO REASONCODE OF P-LCTFM321
              STRING N'UPDATE place gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM321
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R150-UPDATE-PLACE-END.
           EXIT.

           COPY CTFSECP.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM321==.

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

       END PROGRAM CTFM321.
