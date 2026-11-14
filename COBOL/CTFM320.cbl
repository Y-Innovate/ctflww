       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM320.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * GET /progress/{eventID}: summary of the player's team. All the*
      * team's own solves, awards and hint costs count, also after a  *
      * freeze, at the challenge values of the board (solve counts up *
      * to the freeze), so nothing about other teams is revealed. When*
      * the freeze is lifted the score is the leaderboard score.      *
      * JOINCODE is only returned to the captain.                     *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 08 21 = Error: SQL error in SELECT                            *
      * 08 50 = Error: no active place in a team                      *
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
          05 W-SCORE      PIC S9(9) COMP-5.
          05 W-SOLVES     PIC S9(9) COMP-5.
          05 W-HINTS      PIC S9(9) COMP-5.

           COPY CTFCTXW.

       01 ERROR-MESSAGE.
          05 ERROR-LEN    PIC S9(4) COMP
                                     VALUE +720.
          05 ERROR-TEXT   PIC X(72) OCCURS 10 TIMES
                INDEXED BY ERROR-INDEX.
       77 ERROR-TEXT-LEN  PIC S9(9) COMP
                                     VALUE +72.

       LINKAGE SECTION.
       01 P-LCTFM320.
           COPY LCTFM320.

       PROCEDURE DIVISION USING P-LCTFM320.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R100-GET-CONTEXT
           PERFORM R101-NEED-TEAM

           IF RETURNCODE OF P-LCTFM320 = N'00'
              PERFORM R120-SELECT-TEAM
           END-IF

           IF RETURNCODE OF P-LCTFM320 = N'00'
              PERFORM R130-SCORE
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM320
           MOVE N'00' TO REASONCODE OF P-LCTFM320
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM320
           MOVE EVENTID OF P-LCTFM320 TO W-EVENTID
           MOVE 0 TO TEAMID OF P-LCTFM320
           MOVE 0 TO TEAMNAME-LEN OF P-LCTFM320
           MOVE N'N' TO ISCAPTAIN OF P-LCTFM320
           MOVE SPACES TO JOINCODE OF P-LCTFM320
           MOVE 0 TO MEMBERCOUNT OF P-LCTFM320
           MOVE 0 TO SCORE OF P-LCTFM320
           MOVE 0 TO SOLVECOUNT OF P-LCTFM320
           MOVE 0 TO HINTCOUNT OF P-LCTFM320
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R120-SELECT-TEAM: The team                                    *
      *===============================================================*
       R120-SELECT-TEAM SECTION.
           EXEC SQL
              SELECT TEAMNAME,
                     JOINCODE,
                     CAPTAINID,
                     MEMBERCOUNT
                INTO :DCLTBCTF005.TEAMNAME,
                     :DCLTBCTF005.JOINCODE,
                     :DCLTBCTF005.CAPTAINID,
                     :DCLTBCTF005.MEMBERCOUNT
                FROM TBCTF005
               WHERE TEAMID = :W-TEAMID
           END-EXEC

           IF SQLCODE = 0
              MOVE W-TEAMID TO TEAMID OF P-LCTFM320
              MOVE TEAMNAME OF DCLTBCTF005 TO TEAMNAME OF P-LCTFM320
              MOVE MEMBERCOUNT OF DCLTBCTF005 TO
                   MEMBERCOUNT OF P-LCTFM320
              IF CAPTAINID OF DCLTBCTF005 = W-PLAYERID
                 MOVE N'Y' TO ISCAPTAIN OF P-LCTFM320
                 MOVE JOINCODE OF DCLTBCTF005 TO JOINCODE OF P-LCTFM320
              END-IF
           ELSE
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM320
              MOVE N'21' TO REASONCODE OF P-LCTFM320
              STRING N'SELECT team gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM320
              PERFORM R900-DSNTIAR
           END-IF
           .
       R120-SELECT-TEAM-END.
           EXIT.

      *===============================================================*
      * R130-SCORE: Score, solves and hints of the team               *
      *===============================================================*
       R130-SCORE SECTION.
           EXEC SQL
              WITH SC AS (
                 SELECT CHALLENGEID, COUNT(*) AS N
                   FROM TBCTF014
                  WHERE EVENTID = :W-EVENTID
                    AND CREATEDDATE <= :W-CUTOFF
                  GROUP BY CHALLENGEID),
              CV AS (
                 SELECT EC.CHALLENGEID,
                        CASE WHEN EC.SCORETYPE = :C-D
                             THEN MAX(EC.MINPOINTS, CAST(CEILING(
                                  1E0 * (EC.MINPOINTS - EC.INITPOINTS)
                                      * MAX(COALESCE(SC.N, 0) - 1, 0)
                                      * MAX(COALESCE(SC.N, 0) - 1, 0)
                                      / (EC.DECAYSOLVES
                                       * EC.DECAYSOLVES)
                                  + EC.INITPOINTS) AS INTEGER))
                             ELSE EC.INITPOINTS END AS POINTS
                   FROM TBCTF011 EC
                   LEFT JOIN SC
                     ON SC.CHALLENGEID = EC.CHALLENGEID
                  WHERE EC.EVENTID = :W-EVENTID)
              SELECT COALESCE((SELECT SUM(CV.POINTS)
                                 FROM TBCTF014 S
                                 JOIN CV
                                   ON CV.CHALLENGEID = S.CHALLENGEID
                                WHERE S.EVENTID = :W-EVENTID
                                  AND S.TEAMID = :W-TEAMID), 0)
                   + COALESCE((SELECT SUM(A.POINTS)
                                 FROM TBCTF016 A
                                WHERE A.EVENTID = :W-EVENTID
                                  AND A.TEAMID = :W-TEAMID), 0)
                   - COALESCE((SELECT SUM(H.COST)
                                 FROM TBCTF015 H
                                WHERE H.EVENTID = :W-EVENTID
                                  AND H.TEAMID = :W-TEAMID), 0),
                     (SELECT COUNT(*)
                        FROM TBCTF014 S
                       WHERE S.EVENTID = :W-EVENTID
                         AND S.TEAMID = :W-TEAMID),
                     (SELECT COUNT(*)
                        FROM TBCTF015 H
                       WHERE H.EVENTID = :W-EVENTID
                         AND H.TEAMID = :W-TEAMID)
                INTO :W-SCORE,
                     :W-SOLVES,
                     :W-HINTS
                FROM SYSIBM.SYSDUMMY1
           END-EXEC

           IF SQLCODE = 0
              MOVE W-SCORE TO SCORE OF P-LCTFM320
              MOVE W-SOLVES TO SOLVECOUNT OF P-LCTFM320
              MOVE W-HINTS TO HINTCOUNT OF P-LCTFM320
           ELSE
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM320
              MOVE N'21' TO REASONCODE OF P-LCTFM320
              STRING N'SELECT score gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM320
              PERFORM R900-DSNTIAR
           END-IF
           .
       R130-SCORE-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM320==.

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

       END PROGRAM CTFM320.
