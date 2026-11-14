       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM312.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * GET /challenges/{challengeID}: one challenge for the team.    *
      * ATTEMPTSLEFT: wrong attempts left, -1 = no limit.             *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Not found or not visible                              *
      * 08 21 = Error: SQL error in SELECT                            *
      * 08 50 = Error: no active place in a team, or locked           *
      * 08 53 = Error: event has not started                          *
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
          05 W-POINTS     PIC S9(9) COMP-5.
          05 W-SOLVES     PIC S9(9) COMP-5.
          05 W-WRONG      PIC S9(9) COMP-5.

           COPY CTFCTXW.

       01 ERROR-MESSAGE.
          05 ERROR-LEN    PIC S9(4) COMP
                                     VALUE +720.
          05 ERROR-TEXT   PIC X(72) OCCURS 10 TIMES
                INDEXED BY ERROR-INDEX.
       77 ERROR-TEXT-LEN  PIC S9(9) COMP
                                     VALUE +72.

       LINKAGE SECTION.
       01 P-LCTFM312.
           COPY LCTFM312.

       PROCEDURE DIVISION USING P-LCTFM312.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R100-GET-CONTEXT
           PERFORM R101-NEED-TEAM
           PERFORM R102-NEED-STARTED

           IF RETURNCODE OF P-LCTFM312 = N'00'
              PERFORM R120-SELECT
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM312
           MOVE N'00' TO REASONCODE OF P-LCTFM312
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM312
           MOVE EVENTID OF P-LCTFM312 TO W-EVENTID

           MOVE CHALLENGEID OF P-LCTFM312 TO W-CHALLENGEID
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R120-SELECT: SELECT the challenge                             *
      *===============================================================*
       R120-SELECT SECTION.
           EXEC SQL
              WITH SC AS (
                 SELECT CHALLENGEID, COUNT(*) AS N
                   FROM TBCTF014
                  WHERE EVENTID = :W-EVENTID
                    AND CREATEDDATE <= :W-CUTOFF
                  GROUP BY CHALLENGEID)
              SELECT C.CHALLENGETITLE,
                     C.CATEGORY,
                     R.TABVALUE,
                     C.DESCRIPTION,
                     EC.MAXATTEMPTS,
                     CASE WHEN EC.SCORETYPE = :C-D
                          THEN MAX(EC.MINPOINTS, CAST(CEILING(
                               1E0 * (EC.MINPOINTS - EC.INITPOINTS)
                                   * MAX(COALESCE(SC.N, 0) - 1, 0)
                                   * MAX(COALESCE(SC.N, 0) - 1, 0)
                                   / (EC.DECAYSOLVES * EC.DECAYSOLVES)
                               + EC.INITPOINTS) AS INTEGER))
                          ELSE EC.INITPOINTS END,
                     COALESCE(SC.N, 0),
                     (SELECT COUNT(*) FROM TBCTF013 U
                       WHERE U.EVENTID = EC.EVENTID
                         AND U.CHALLENGEID = EC.CHALLENGEID
                         AND U.TEAMID = :W-TEAMID
                         AND U.ISCORRECT = :C-N),
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
                     THEN 'Y' ELSE 'N' END
                INTO :DCLTBCTF007.CHALLENGETITLE,
                     :DCLTBCTF007.CATEGORY,
                     :DCLTBCTF001.TABVALUE
                       :DCLTBCTF001.TABVALUE-IND,
                     :DCLTBCTF007.DESCRIPTION,
                     :DCLTBCTF011.MAXATTEMPTS
                       :DCLTBCTF011.MAXATTEMPTS-IND,
                     :W-POINTS,
                     :W-SOLVES,
                     :W-WRONG,
                     :W-SOLVED,
                     :W-LOCKED
                FROM TBCTF011 EC
                JOIN TBCTF007 C
                  ON C.CHALLENGEID = EC.CHALLENGEID
                LEFT JOIN SC
                  ON SC.CHALLENGEID = EC.CHALLENGEID
                LEFT JOIN TBCTF001 R
                  ON R.TABLEID = :C-CATEGORY
                 AND R.TABKEY = C.CATEGORY
               WHERE EC.EVENTID = :W-EVENTID
                 AND EC.CHALLENGEID = :W-CHALLENGEID
                 AND EC.ISVISIBLE = :C-Y
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              IF W-LOCKED = 'Y'
                 MOVE N'08' TO RETURNCODE OF P-LCTFM312
                 MOVE N'50' TO REASONCODE OF P-LCTFM312
                 MOVE N'This challenge is still locked' TO
                      INFOMESSAGE OF P-LCTFM312
              ELSE
                 PERFORM R220-COPY-ROW
              END-IF
           WHEN 100
              MOVE N'04' TO RETURNCODE OF P-LCTFM312
              MOVE N'01' TO REASONCODE OF P-LCTFM312
              MOVE N'Challenge not found' TO
                   INFOMESSAGE OF P-LCTFM312
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM312
              MOVE N'21' TO REASONCODE OF P-LCTFM312
              STRING N'SELECT gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM312
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R120-SELECT-END.
           EXIT.

      *===============================================================*
      * R220-COPY-ROW: Copy the challenge                             *
      *===============================================================*
       R220-COPY-ROW SECTION.
           MOVE CHALLENGETITLE OF DCLTBCTF007 TO
                CHALLENGETITLE OF P-LCTFM312
           MOVE CATEGORY OF DCLTBCTF007 TO CATEGORY OF P-LCTFM312
           IF TABVALUE-IND OF DCLTBCTF001 < 0
              MOVE 0 TO CATEGORYNAME-LEN OF P-LCTFM312
           ELSE
              MOVE TABVALUE OF DCLTBCTF001 TO
                   CATEGORYNAME OF P-LCTFM312
           END-IF
           MOVE DESCRIPTION OF DCLTBCTF007 TO
                DESCRIPTION OF P-LCTFM312
           MOVE W-POINTS TO CURRENTPOINTS OF P-LCTFM312
           MOVE W-SOLVES TO SOLVECOUNT OF P-LCTFM312
           MOVE FUNCTION NATIONAL-OF(W-SOLVED) TO
                ISSOLVED OF P-LCTFM312
           IF MAXATTEMPTS-IND OF DCLTBCTF011 < 0
              MOVE -1 TO ATTEMPTSLEFT OF P-LCTFM312
           ELSE
              COMPUTE ATTEMPTSLEFT OF P-LCTFM312 =
                 FUNCTION MAX(0,
                    MAXATTEMPTS OF DCLTBCTF011 - W-WRONG)
           END-IF
           .
       R220-COPY-ROW-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM312==.

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

       END PROGRAM CTFM312.
