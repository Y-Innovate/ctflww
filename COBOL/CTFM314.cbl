       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM314.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * GET /leaderboard/{eventID}: scores are calculated, not stored. *
      * Score = solve values + awards - hint costs. During a freeze   *
      * everything after the freeze time is left out.                 *
      * ADMINVIEW Y (GET /admin/leaderboard, set by CTFC530 only):    *
      * the freeze is ignored and a draft is an empty board.          *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success, also when there are no teams                 *
      * 04 01 = Event not found, or still a draft (not for ADMINVIEW) *
      * 08 21 = Error: SQL error in SELECT                            *
      * 08 61/62/63 = Error: SQL error on OPEN/CLOSE/FETCH            *
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

       01 WORK.
          05 W-PGMNAME    PIC X(8).
          05 W-SQLCODE    PIC -99999.
          05 W-EVENTID    PIC S9(9) COMP-5.
          05 W-RANK-SINCE PIC S9(9) COMP-5.
          05 W-CUTOFF     PIC X(26).
          05 W-FROZEN     PIC X.
          05 W-ADMIN      PIC X.
          05 W-RANKNO     PIC S9(9) COMP-5.
          05 W-TEAMID     PIC S9(9) COMP-5.
          05 W-TEAMNAME.
             49 W-TEAMNAME-LEN  PIC S9(4) COMP-5.
             49 W-TEAMNAME-TEXT PIC N(30).
          05 W-SCORE      PIC S9(9) COMP-5.
          05 W-SOLVES     PIC S9(9) COMP-5.

       01 C-CODES.
          05 C-A          PIC N VALUE N'A'.
          05 C-C          PIC N VALUE N'C'.
          05 C-D          PIC N VALUE N'D'.
          05 C-F          PIC N VALUE N'F'.
          05 C-I          PIC N VALUE N'I'.
          05 C-N          PIC N VALUE N'N'.
          05 C-P          PIC N VALUE N'P'.
          05 C-R          PIC N VALUE N'R'.
          05 C-S          PIC N VALUE N'S'.
          05 C-Y          PIC N VALUE N'Y'.
          05 C-CATEGORY   PIC N(8) VALUE N'CATEGORY'.
          05 C-SETTINGS   PIC N(8) VALUE N'SETTINGS'.

       01 ERROR-MESSAGE.
          05 ERROR-LEN    PIC S9(4) COMP
                                     VALUE +720.
          05 ERROR-TEXT   PIC X(72) OCCURS 10 TIMES
                INDEXED BY ERROR-INDEX.
       77 ERROR-TEXT-LEN  PIC S9(9) COMP
                                     VALUE +72.

       LINKAGE SECTION.
       01 P-LCTFM314.
           COPY LCTFM314.

       PROCEDURE DIVISION USING P-LCTFM314.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R100-GET-CUTOFF

           IF RETURNCODE OF P-LCTFM314 = N'00'
              PERFORM R007-OPEN-CURSOR
           END-IF

           IF RETURNCODE OF P-LCTFM314 = N'00'
              PERFORM R210-FETCH-CURSOR

              PERFORM WITH TEST BEFORE
                UNTIL RETURNCODE OF P-LCTFM314 NOT = N'00'
                   OR SQLCODE NOT = 0
                   OR BOARD-COUNT OF P-LCTFM314 >= 20
                 PERFORM R210-FETCH-CURSOR
              END-PERFORM

              PERFORM R190-CLOSE-CURSOR
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM314
           MOVE N'00' TO REASONCODE OF P-LCTFM314
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM314

           MOVE 0 TO BOARD-COUNT OF P-LCTFM314
           MOVE EVENTID OF P-LCTFM314 TO W-EVENTID
           MOVE RANK-SINCE OF P-LCTFM314 TO W-RANK-SINCE
           IF ADMINVIEW OF P-LCTFM314 = N'Y'
              MOVE 'Y' TO W-ADMIN
           ELSE
              MOVE 'N' TO W-ADMIN
           END-IF
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R100-GET-CUTOFF: The freeze time, or far future when none or  *
      * for the admin                                                 *
      *===============================================================*
       R100-GET-CUTOFF SECTION.
           EXEC SQL
              SELECT CHAR(COALESCE(
                        CASE WHEN FREEZETS <= CURRENT TIMESTAMP
                              AND :W-ADMIN <> 'Y'
                             THEN FREEZETS END,
                        TIMESTAMP('9999-12-31-23.59.59.999999'))),
                     CASE WHEN FREEZETS <= CURRENT TIMESTAMP
                          THEN 'Y' ELSE 'N' END
                INTO :W-CUTOFF,
                     :W-FROZEN
                FROM TBCTF002
               WHERE EVENTID = :W-EVENTID
                 AND (EVENTSTATUS <> :C-D
                  OR  :W-ADMIN = 'Y')
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              MOVE FUNCTION NATIONAL-OF(W-FROZEN) TO
                   ISFROZEN OF P-LCTFM314
           WHEN 100
              MOVE N'04' TO RETURNCODE OF P-LCTFM314
              MOVE N'01' TO REASONCODE OF P-LCTFM314
              MOVE N'Event not found' TO
                   INFOMESSAGE OF P-LCTFM314
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM314
              MOVE N'21' TO REASONCODE OF P-LCTFM314
              STRING N'SELECT gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM314
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R100-GET-CUTOFF-END.
           EXIT.

      *===============================================================*
      * R007-OPEN-CURSOR: Open the leaderboard cursor                 *
      *===============================================================*
       R007-OPEN-CURSOR SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              WITH SOLVECOUNT AS (
                 SELECT CHALLENGEID, COUNT(*) AS N
                   FROM TBCTF014
                  WHERE EVENTID = :W-EVENTID
                    AND CREATEDDATE <= :W-CUTOFF
                  GROUP BY CHALLENGEID),
              CHALLVALUE AS (
                 SELECT EC.CHALLENGEID,
                     CASE WHEN EC.SCORETYPE = :C-D
                          THEN MAX(EC.MINPOINTS, CAST(CEILING(
                               1E0 * (EC.MINPOINTS - EC.INITPOINTS)
                                   * MAX(COALESCE(SC.N, 0) - 1, 0)
                                   * MAX(COALESCE(SC.N, 0) - 1, 0)
                                   / (EC.DECAYSOLVES * EC.DECAYSOLVES)
                               + EC.INITPOINTS) AS INTEGER))
                          ELSE EC.INITPOINTS END AS POINTS
                   FROM TBCTF011 EC
                   LEFT JOIN SOLVECOUNT SC
                     ON SC.CHALLENGEID = EC.CHALLENGEID
                  WHERE EC.EVENTID = :W-EVENTID),
              SCORELINES (TEAMID, POINTS, SCOREDATE, ISSOLVE) AS (
                 SELECT S.TEAMID, CV.POINTS,
                        S.CREATEDDATE AS SCOREDATE, 1 AS ISSOLVE
                   FROM TBCTF014 S
                   JOIN CHALLVALUE CV
                     ON CV.CHALLENGEID = S.CHALLENGEID
                  WHERE S.EVENTID = :W-EVENTID
                    AND S.CREATEDDATE <= :W-CUTOFF
                 UNION ALL
                 SELECT A.TEAMID, A.POINTS,
                        CASE WHEN A.POINTS > 0
                             THEN A.CREATEDDATE END, 0
                   FROM TBCTF016 A
                  WHERE A.EVENTID = :W-EVENTID
                    AND A.CREATEDDATE <= :W-CUTOFF
                 UNION ALL
                 SELECT H.TEAMID, 0 - H.COST,
                        CAST(NULL AS TIMESTAMP), 0
                   FROM TBCTF015 H
                  WHERE H.EVENTID = :W-EVENTID
                    AND H.CREATEDDATE <= :W-CUTOFF),
              TOTALS AS (
                 SELECT TEAMID, SUM(POINTS) AS SCORE,
                        MAX(SCOREDATE) AS LASTSCORE,
                        SUM(ISSOLVE) AS SOLVES
                   FROM SCORELINES
                  GROUP BY TEAMID),
              RANKED AS (
                 SELECT T.TEAMID, T.TEAMNAME,
                        COALESCE(TT.SCORE, 0) AS SCORE,
                        COALESCE(TT.SOLVES, 0) AS SOLVES,
                        ROW_NUMBER() OVER (
                          ORDER BY COALESCE(TT.SCORE, 0) DESC,
                                   COALESCE(TT.LASTSCORE, TIMESTAMP(
                                   '9999-12-31-23.59.59.999999')) ASC,
                                   T.TEAMID ASC) AS RANKNO
                   FROM TBCTF005 T
                   LEFT JOIN TOTALS TT
                     ON TT.TEAMID = T.TEAMID
                  WHERE T.EVENTID = :W-EVENTID)
              SELECT RANKNO, TEAMID, TEAMNAME, SCORE, SOLVES
                FROM RANKED
               WHERE RANKNO > :W-RANK-SINCE
               ORDER BY RANKNO
               FETCH FIRST 20 ROWS ONLY
                 FOR FETCH ONLY
           END-EXEC

           EXEC SQL
              OPEN C1
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM314
              MOVE N'61' TO REASONCODE OF P-LCTFM314
              STRING N'OPEN CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM314
              PERFORM R900-DSNTIAR
           END-IF
           .
       R007-OPEN-CURSOR-END.
           EXIT.

      *===============================================================*
      * R190-CLOSE-CURSOR: Close the leaderboard cursor               *
      *===============================================================*
       R190-CLOSE-CURSOR SECTION.
           EXEC SQL
              CLOSE C1
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM314
              MOVE N'62' TO REASONCODE OF P-LCTFM314
              STRING N'CLOSE CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM314
              PERFORM R900-DSNTIAR
           END-IF
           .
       R190-CLOSE-CURSOR-END.
           EXIT.

      *===============================================================*
      * R210-FETCH-CURSOR: Fetch one row                              *
      *===============================================================*
       R210-FETCH-CURSOR SECTION.
           EXEC SQL
              FETCH C1
               INTO :W-RANKNO,
                    :W-TEAMID,
                    :W-TEAMNAME,
                    :W-SCORE,
                    :W-SOLVES
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO BOARD-COUNT OF P-LCTFM314
              MOVE W-RANKNO TO
                   RANKNO OF P-LCTFM314(BOARD-COUNT OF P-LCTFM314)
              MOVE W-TEAMID TO
                   TEAMID OF P-LCTFM314(BOARD-COUNT OF P-LCTFM314)
              MOVE W-TEAMNAME TO
                   TEAMNAME OF P-LCTFM314(BOARD-COUNT OF P-LCTFM314)
              MOVE W-SCORE TO
                   SCORE OF P-LCTFM314(BOARD-COUNT OF P-LCTFM314)
              MOVE W-SOLVES TO
                   SOLVECOUNT OF P-LCTFM314(BOARD-COUNT OF P-LCTFM314)
           WHEN 100
              CONTINUE
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM314
              MOVE N'63' TO REASONCODE OF P-LCTFM314
              STRING N'FETCH CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM314
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R210-FETCH-CURSOR-END.
           EXIT.

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

       END PROGRAM CTFM314.
