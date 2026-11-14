       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM311.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * GET /challenges: the board for the player's team. During a    *
      * freeze values and solve counts are those at the freeze time;  *
      * the team's own solves are always shown.                       *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success, also when there are no challenges            *
      * 08 21 = Error: SQL error in SELECT                            *
      * 08 50 = Error: player has no active place in a team           *
      * 08 53 = Error: event has not started                          *
      * 08 61/62/63 = Error: SQL error on OPEN/CLOSE/FETCH            *
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

           EXEC SQL INCLUDE TBCTF001 END-EXEC.

           EXEC SQL INCLUDE TBCTF007 END-EXEC.

           EXEC SQL INCLUDE TBCTF011 END-EXEC.

       01 WORK.
          05 W-SQLCODE    PIC -99999.
          05 W-SORT-SINCE PIC S9(4) COMP-5.
          05 W-CHALL-SINCE PIC S9(9) COMP-5.
          05 W-POINTS     PIC S9(9) COMP-5.
          05 W-SOLVES     PIC S9(9) COMP-5.

           COPY CTFCTXW.

       01 ERROR-MESSAGE.
          05 ERROR-LEN    PIC S9(4) COMP
                                     VALUE +720.
          05 ERROR-TEXT   PIC X(72) OCCURS 10 TIMES
                INDEXED BY ERROR-INDEX.
       77 ERROR-TEXT-LEN  PIC S9(9) COMP
                                     VALUE +72.

       LINKAGE SECTION.
       01 P-LCTFM311.
           COPY LCTFM311.

       PROCEDURE DIVISION USING P-LCTFM311.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R100-GET-CONTEXT
           PERFORM R101-NEED-TEAM
           PERFORM R102-NEED-STARTED

           IF RETURNCODE OF P-LCTFM311 = N'00'
              PERFORM R007-OPEN-CURSOR
           END-IF

           IF RETURNCODE OF P-LCTFM311 = N'00'
              PERFORM R210-FETCH-CURSOR

              PERFORM WITH TEST BEFORE
                UNTIL RETURNCODE OF P-LCTFM311 NOT = N'00'
                   OR SQLCODE NOT = 0
                   OR CHALL-COUNT OF P-LCTFM311 >= 20
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
           MOVE N'00' TO RETURNCODE OF P-LCTFM311
           MOVE N'00' TO REASONCODE OF P-LCTFM311
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM311
           MOVE EVENTID OF P-LCTFM311 TO W-EVENTID

           MOVE 0 TO CHALL-COUNT OF P-LCTFM311
           MOVE SORTORDER-SINCE OF P-LCTFM311 TO W-SORT-SINCE
           MOVE CHALLENGEID-SINCE OF P-LCTFM311 TO W-CHALL-SINCE
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R007-OPEN-CURSOR: Open the board cursor                       *
      *===============================================================*
       R007-OPEN-CURSOR SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              WITH SC AS (
                 SELECT CHALLENGEID, COUNT(*) AS N
                   FROM TBCTF014
                  WHERE EVENTID = :W-EVENTID
                    AND CREATEDDATE <= :W-CUTOFF
                  GROUP BY CHALLENGEID)
              SELECT EC.CHALLENGEID,
                     C.CHALLENGETITLE,
                     C.CATEGORY,
                     R.TABVALUE,
                     CASE WHEN EC.SCORETYPE = :C-D
                          THEN MAX(EC.MINPOINTS, CAST(CEILING(
                               1E0 * (EC.MINPOINTS - EC.INITPOINTS)
                                   * MAX(COALESCE(SC.N, 0) - 1, 0)
                                   * MAX(COALESCE(SC.N, 0) - 1, 0)
                                   / (EC.DECAYSOLVES * EC.DECAYSOLVES)
                               + EC.INITPOINTS) AS INTEGER))
                          ELSE EC.INITPOINTS END,
                     COALESCE(SC.N, 0),
                     CASE WHEN EXISTS
                       (SELECT 1 FROM TBCTF014 S
                         WHERE S.EVENTID = EC.EVENTID
                           AND S.CHALLENGEID = EC.CHALLENGEID
                           AND S.TEAMID = :W-TEAMID)
                     THEN 'Y' ELSE 'N' END,
                     CASE WHEN EXISTS
                       (SELECT 1 FROM TBCTF012 Q
                         WHERE Q.EVENTID = EC.EVENTID
                           AND Q.CHALLENGEID = EC.CHALLENGEID
                           AND NOT EXISTS
                               (SELECT 1 FROM TBCTF014 S
                                 WHERE S.EVENTID = Q.EVENTID
                                   AND S.CHALLENGEID = Q.REQCHALLENGEID
                                   AND S.TEAMID = :W-TEAMID))
                     THEN 'Y' ELSE 'N' END,
                     EC.SORTORDER
                FROM TBCTF011 EC
                JOIN TBCTF007 C
                  ON C.CHALLENGEID = EC.CHALLENGEID
                LEFT JOIN SC
                  ON SC.CHALLENGEID = EC.CHALLENGEID
                LEFT JOIN TBCTF001 R
                  ON R.TABLEID = :C-CATEGORY
                 AND R.TABKEY = C.CATEGORY
               WHERE EC.EVENTID = :W-EVENTID
                 AND EC.ISVISIBLE = :C-Y
                 AND (EC.SORTORDER > :W-SORT-SINCE
                  OR (EC.SORTORDER = :W-SORT-SINCE
                 AND  EC.CHALLENGEID > :W-CHALL-SINCE))
               ORDER BY EC.SORTORDER, EC.CHALLENGEID
               FETCH FIRST 20 ROWS ONLY
                 FOR FETCH ONLY
           END-EXEC

           EXEC SQL
              OPEN C1
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM311
              MOVE N'61' TO REASONCODE OF P-LCTFM311
              STRING N'OPEN CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM311
              PERFORM R900-DSNTIAR
           END-IF
           .
       R007-OPEN-CURSOR-END.
           EXIT.

      *===============================================================*
      * R190-CLOSE-CURSOR: Close the board cursor                     *
      *===============================================================*
       R190-CLOSE-CURSOR SECTION.
           EXEC SQL
              CLOSE C1
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM311
              MOVE N'62' TO REASONCODE OF P-LCTFM311
              STRING N'CLOSE CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM311
              PERFORM R900-DSNTIAR
           END-IF
           .
       R190-CLOSE-CURSOR-END.
           EXIT.

      *===============================================================*
      * R210-FETCH-CURSOR: Fetch one challenge                        *
      *===============================================================*
       R210-FETCH-CURSOR SECTION.
           EXEC SQL
              FETCH C1
               INTO :DCLTBCTF011.CHALLENGEID,
                    :DCLTBCTF007.CHALLENGETITLE,
                    :DCLTBCTF007.CATEGORY,
                    :DCLTBCTF001.TABVALUE
                      :DCLTBCTF001.TABVALUE-IND,
                    :W-POINTS,
                    :W-SOLVES,
                    :W-SOLVED,
                    :W-LOCKED,
                    :DCLTBCTF011.SORTORDER
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO CHALL-COUNT OF P-LCTFM311
              PERFORM R220-COPY-ROW
           WHEN 100
              CONTINUE
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM311
              MOVE N'63' TO REASONCODE OF P-LCTFM311
              STRING N'FETCH CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM311
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R210-FETCH-CURSOR-END.
           EXIT.

      *===============================================================*
      * R220-COPY-ROW: Copy the fetched challenge                     *
      *===============================================================*
       R220-COPY-ROW SECTION.
           MOVE CHALLENGEID OF DCLTBCTF011 TO
                CHALLENGEID OF P-LCTFM311(CHALL-COUNT OF P-LCTFM311)
           MOVE CHALLENGETITLE OF DCLTBCTF007 TO
                CHALLENGETITLE OF P-LCTFM311(CHALL-COUNT OF P-LCTFM311)
           MOVE CATEGORY OF DCLTBCTF007 TO
                CATEGORY OF P-LCTFM311(CHALL-COUNT OF P-LCTFM311)
           IF TABVALUE-IND OF DCLTBCTF001 < 0
              MOVE 0 TO
                   CATEGORYNAME-LEN OF
                      P-LCTFM311(CHALL-COUNT OF P-LCTFM311)
           ELSE
              MOVE TABVALUE OF DCLTBCTF001 TO
                   CATEGORYNAME OF P-LCTFM311(CHALL-COUNT OF P-LCTFM311)
           END-IF
           MOVE W-POINTS TO
                CURRENTPOINTS OF P-LCTFM311(CHALL-COUNT OF P-LCTFM311)
           MOVE W-SOLVES TO
                SOLVECOUNT OF P-LCTFM311(CHALL-COUNT OF P-LCTFM311)
           MOVE FUNCTION NATIONAL-OF(W-SOLVED) TO
                ISSOLVED OF P-LCTFM311(CHALL-COUNT OF P-LCTFM311)
           MOVE FUNCTION NATIONAL-OF(W-LOCKED) TO
                ISLOCKED OF P-LCTFM311(CHALL-COUNT OF P-LCTFM311)
           MOVE SORTORDER OF DCLTBCTF011 TO
                SORTORDER OF P-LCTFM311(CHALL-COUNT OF P-LCTFM311)
           .
       R220-COPY-ROW-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM311==.

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

       END PROGRAM CTFM311.
