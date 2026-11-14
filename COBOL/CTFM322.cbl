       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM322.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * POST /teamMembers: joins the team with this join code.        *
      * MEMBERCOUNT is raised with a guarded UPDATE, so a team cannot *
      * grow past MAXTEAMSIZE when players join at the same moment.   *
      * Only while registration is open, and for a player with an     *
      * active place and no team yet.                                 *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = No team with this join code in the event              *
      * 08 02 = Error: join code required                             *
      * 08 21 = Error: SQL error in SELECT                            *
      * 08 32 = Error: SQL error in UPDATE                            *
      * 08 50 = Error: not in the event, or place not active          *
      * 08 52 = Error: team is full                                   *
      * 08 53 = Error: not a team event, registration closed, or in   *
      *         a team already                                        *
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
          05 W-JOINCODE   PIC N(12).

           COPY CTFCTXW.

       01 ERROR-MESSAGE.
          05 ERROR-LEN    PIC S9(4) COMP
                                     VALUE +720.
          05 ERROR-TEXT   PIC X(72) OCCURS 10 TIMES
                INDEXED BY ERROR-INDEX.
       77 ERROR-TEXT-LEN  PIC S9(9) COMP
                                     VALUE +72.

       LINKAGE SECTION.
       01 P-LCTFM322.
           COPY LCTFM322.

       PROCEDURE DIVISION USING P-LCTFM322.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R100-GET-CONTEXT
           PERFORM R105-NEED-TEAMMODE
           PERFORM R104-NEED-ACTIVE

           IF RETURNCODE OF P-LCTFM322 = N'00'
              PERFORM R110-CHECK-PLACE
           END-IF

           IF RETURNCODE OF P-LCTFM322 = N'00'
              PERFORM R120-JOIN-TEAM
           END-IF

           IF RETURNCODE OF P-LCTFM322 = N'00'
              PERFORM R150-UPDATE-PLACE
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM322
           MOVE N'00' TO REASONCODE OF P-LCTFM322
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM322
           MOVE EVENTID OF P-LCTFM322 TO W-EVENTID
           MOVE 0 TO TEAMID OF P-LCTFM322
           MOVE 0 TO TEAMNAME-LEN OF P-LCTFM322
           MOVE FUNCTION UPPER-CASE(JOINCODE OF P-LCTFM322) TO
                W-JOINCODE

           IF W-JOINCODE = SPACES
              MOVE N'08' TO RETURNCODE OF P-LCTFM322
              MOVE N'02' TO REASONCODE OF P-LCTFM322
              MOVE N'Join code is required' TO
                   INFOMESSAGE OF P-LCTFM322
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
              MOVE N'08' TO RETURNCODE OF P-LCTFM322
              MOVE N'53' TO REASONCODE OF P-LCTFM322
              MOVE N'You are in a team already' TO
                   INFOMESSAGE OF P-LCTFM322
           WHEN W-REGOPEN NOT = 'Y'
              MOVE N'08' TO RETURNCODE OF P-LCTFM322
              MOVE N'53' TO REASONCODE OF P-LCTFM322
              MOVE N'Registration for this event is closed' TO
                   INFOMESSAGE OF P-LCTFM322
           END-EVALUATE
           .
       R110-CHECK-PLACE-END.
           EXIT.

      *===============================================================*
      * R120-JOIN-TEAM: Take a place in the team, if not full         *
      *===============================================================*
       R120-JOIN-TEAM SECTION.
           EXEC SQL
              SELECT TEAMID,
                     TEAMNAME
                INTO :DCLTBCTF005.TEAMID,
                     :DCLTBCTF005.TEAMNAME
                FROM FINAL TABLE
                   (
              UPDATE TBCTF005
                 SET MEMBERCOUNT = MEMBERCOUNT + 1,
                     UPDATEDBY = :W-USERID,
                     UPDATEDDATE = CURRENT TIMESTAMP
               WHERE EVENTID = :W-EVENTID
                 AND JOINCODE = :W-JOINCODE
                 AND MEMBERCOUNT < :W-MAXTEAMSIZE
                   )
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              CONTINUE
           WHEN 100
              PERFORM R125-WHY-NOT
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM322
              MOVE N'32' TO REASONCODE OF P-LCTFM322
              STRING N'UPDATE team gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM322
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R120-JOIN-TEAM-END.
           EXIT.

      *===============================================================*
      * R125-WHY-NOT: Wrong join code, or team full                   *
      *===============================================================*
       R125-WHY-NOT SECTION.
           EXEC SQL
              SELECT TEAMID
                INTO :DCLTBCTF005.TEAMID
                FROM TBCTF005
               WHERE EVENTID = :W-EVENTID
                 AND JOINCODE = :W-JOINCODE
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              MOVE N'08' TO RETURNCODE OF P-LCTFM322
              MOVE N'52' TO REASONCODE OF P-LCTFM322
              MOVE N'This team is full' TO
                   INFOMESSAGE OF P-LCTFM322
           WHEN 100
              MOVE N'04' TO RETURNCODE OF P-LCTFM322
              MOVE N'01' TO REASONCODE OF P-LCTFM322
              MOVE N'No team with this join code' TO
                   INFOMESSAGE OF P-LCTFM322
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM322
              MOVE N'21' TO REASONCODE OF P-LCTFM322
              STRING N'SELECT team gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM322
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R125-WHY-NOT-END.
           EXIT.

      *===============================================================*
      * R150-UPDATE-PLACE: Put the place in the team                  *
      *===============================================================*
       R150-UPDATE-PLACE SECTION.
           EXEC SQL
              UPDATE TBCTF006
                 SET TEAMID = :DCLTBCTF005.TEAMID,
                     UPDATEDBY = :W-USERID,
                     UPDATEDDATE = CURRENT TIMESTAMP
               WHERE EVENTID = :W-EVENTID
                 AND PLAYERID = :W-PLAYERID
                 AND TEAMID IS NULL
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              MOVE TEAMID OF DCLTBCTF005 TO TEAMID OF P-LCTFM322
              MOVE TEAMNAME OF DCLTBCTF005 TO TEAMNAME OF P-LCTFM322
           WHEN 100
              MOVE N'08' TO RETURNCODE OF P-LCTFM322
              MOVE N'53' TO REASONCODE OF P-LCTFM322
              MOVE N'You are in a team already' TO
                   INFOMESSAGE OF P-LCTFM322
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM322
              MOVE N'32' TO REASONCODE OF P-LCTFM322
              STRING N'UPDATE place gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM322
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R150-UPDATE-PLACE-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM322==.

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

       END PROGRAM CTFM322.
