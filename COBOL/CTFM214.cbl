       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM214.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * GET /progressSolves: the team's own solves, also after a      *
      * freeze, by CHALLENGEID. CURRENTPOINTS is the value on the     *
      * board, so solve counts up to the freeze, as in CTFM320.       *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success, also when there are no rows                  *
      * 08 21 = Error: SQL error in SELECT                            *
      * 08 50 = Error: no active place in a team                      *
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

           EXEC SQL INCLUDE TBCTF003 END-EXEC.

           EXEC SQL INCLUDE TBCTF007 END-EXEC.

           EXEC SQL INCLUDE TBCTF014 END-EXEC.

       01 WORK.
          05 W-SQLCODE    PIC -99999.
          05 W-CHALL-SINCE PIC S9(9) COMP-5.
          05 W-POINTS     PIC S9(9) COMP-5.
          05 W-I          PIC S9(4) COMP-5.

           COPY CTFCTXW.

       01 ERROR-MESSAGE.
          05 ERROR-LEN    PIC S9(4) COMP
                                     VALUE +720.
          05 ERROR-TEXT   PIC X(72) OCCURS 10 TIMES
                INDEXED BY ERROR-INDEX.
       77 ERROR-TEXT-LEN  PIC S9(9) COMP
                                     VALUE +72.

       LINKAGE SECTION.
       01 P-LCTFM214.
           COPY LCTFM214.

       PROCEDURE DIVISION USING P-LCTFM214.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R100-GET-CONTEXT
           PERFORM R101-NEED-TEAM

           IF RETURNCODE OF P-LCTFM214 = N'00'
              PERFORM R007-OPEN-CURSOR
           END-IF

           IF RETURNCODE OF P-LCTFM214 = N'00'
              PERFORM R210-FETCH-CURSOR

              PERFORM WITH TEST BEFORE
                UNTIL RETURNCODE OF P-LCTFM214 NOT = N'00'
                   OR SQLCODE NOT = 0
                   OR SOLVE-COUNT OF P-LCTFM214 >= 20
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
           MOVE N'00' TO RETURNCODE OF P-LCTFM214
           MOVE N'00' TO REASONCODE OF P-LCTFM214
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM214
           MOVE 0 TO SOLVE-COUNT OF P-LCTFM214
           MOVE EVENTID OF P-LCTFM214 TO W-EVENTID
           MOVE CHALLENGEID-SINCE OF P-LCTFM214 TO W-CHALL-SINCE
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R007-OPEN-CURSOR: Open the cursor                             *
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
              SELECT S.CHALLENGEID,
                     C.CHALLENGETITLE,
                     CASE WHEN EC.SCORETYPE = :C-D
                          THEN MAX(EC.MINPOINTS, CAST(CEILING(
                               1E0 * (EC.MINPOINTS - EC.INITPOINTS)
                                   * MAX(COALESCE(SC.N, 0) - 1, 0)
                                   * MAX(COALESCE(SC.N, 0) - 1, 0)
                                   / (EC.DECAYSOLVES * EC.DECAYSOLVES)
                               + EC.INITPOINTS) AS INTEGER))
                          ELSE EC.INITPOINTS END,
                     P.DISPLAYNAME,
                     S.CREATEDDATE
                FROM TBCTF014 S
                JOIN TBCTF011 EC
                  ON EC.EVENTID = S.EVENTID
                 AND EC.CHALLENGEID = S.CHALLENGEID
                JOIN TBCTF007 C
                  ON C.CHALLENGEID = S.CHALLENGEID
                JOIN TBCTF003 P
                  ON P.PLAYERID = S.PLAYERID
                LEFT JOIN SC
                  ON SC.CHALLENGEID = S.CHALLENGEID
               WHERE S.EVENTID = :W-EVENTID
                 AND S.TEAMID = :W-TEAMID
                 AND S.CHALLENGEID > :W-CHALL-SINCE
               ORDER BY S.CHALLENGEID
               FETCH FIRST 20 ROWS ONLY
                 FOR FETCH ONLY
           END-EXEC

           EXEC SQL
              OPEN C1
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM214
              MOVE N'61' TO REASONCODE OF P-LCTFM214
              STRING N'OPEN CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM214
              PERFORM R900-DSNTIAR
           END-IF
           .
       R007-OPEN-CURSOR-END.
           EXIT.

      *===============================================================*
      * R190-CLOSE-CURSOR: Close the cursor                           *
      *===============================================================*
       R190-CLOSE-CURSOR SECTION.
           EXEC SQL
              CLOSE C1
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM214
              MOVE N'62' TO REASONCODE OF P-LCTFM214
              STRING N'CLOSE CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM214
              PERFORM R900-DSNTIAR
           END-IF
           .
       R190-CLOSE-CURSOR-END.
           EXIT.

      *===============================================================*
      * R210-FETCH-CURSOR: Fetch one solve                            *
      *===============================================================*
       R210-FETCH-CURSOR SECTION.
           EXEC SQL
              FETCH C1
               INTO :DCLTBCTF014.CHALLENGEID,
                    :DCLTBCTF007.CHALLENGETITLE,
                    :W-POINTS,
                    :DCLTBCTF003.DISPLAYNAME,
                    :DCLTBCTF014.CREATEDDATE
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO SOLVE-COUNT OF P-LCTFM214
              MOVE SOLVE-COUNT OF P-LCTFM214 TO W-I
              PERFORM R220-COPY-ROW
           WHEN 100
              CONTINUE
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM214
              MOVE N'63' TO REASONCODE OF P-LCTFM214
              STRING N'FETCH CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM214
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R210-FETCH-CURSOR-END.
           EXIT.

      *===============================================================*
      * R220-COPY-ROW: Copy the fetched solve                         *
      *===============================================================*
       R220-COPY-ROW SECTION.
           MOVE CHALLENGEID OF DCLTBCTF014 TO
                CHALLENGEID OF P-LCTFM214(W-I)
           MOVE CHALLENGETITLE OF DCLTBCTF007 TO
                CHALLENGETITLE OF P-LCTFM214(W-I)
           MOVE W-POINTS TO CURRENTPOINTS OF P-LCTFM214(W-I)
           MOVE DISPLAYNAME OF DCLTBCTF003 TO
                SOLVEDBY OF P-LCTFM214(W-I)
           MOVE CREATEDDATE OF DCLTBCTF014 TO
                SOLVEDDATE OF P-LCTFM214(W-I)
           .
       R220-COPY-ROW-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM214==.

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

       END PROGRAM CTFM214.
