       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM414.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * GET /admin/solves: the solves in an event, by CHALLENGEID and *
      * TEAMID, both *-SINCE for paging. Filters, each optional:      *
      * team, challenge. Reversed solves are deleted, so they are     *
      * only in the submissions (CTFM413). The caller (the admin      *
      * wrapper) has checked CTF.ADMIN.                               *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success, also when there are no rows                  *
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

           EXEC SQL INCLUDE TBCTF014 END-EXEC.

       01 WORK.
          05 W-SQLCODE    PIC -99999.
          05 W-TEAM-FILTER PIC S9(9) COMP-5.
          05 W-CHALL-FILTER PIC S9(9) COMP-5.
          05 W-CHALL-SINCE PIC S9(9) COMP-5.
          05 W-TEAM-SINCE PIC S9(9) COMP-5.
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
       01 P-LCTFM414.
           COPY LCTFM414.

       PROCEDURE DIVISION USING P-LCTFM414.
       MAIN SECTION.
           PERFORM R001-INIT

      *    The admin wrapper has checked CTF.ADMIN already

           IF RETURNCODE OF P-LCTFM414 = N'00'
              PERFORM R007-OPEN-CURSOR
           END-IF

           IF RETURNCODE OF P-LCTFM414 = N'00'
              PERFORM R210-FETCH-CURSOR

              PERFORM WITH TEST BEFORE
                UNTIL RETURNCODE OF P-LCTFM414 NOT = N'00'
                   OR SQLCODE NOT = 0
                   OR SOLVE-COUNT OF P-LCTFM414 >= 20
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
           MOVE N'00' TO RETURNCODE OF P-LCTFM414
           MOVE N'00' TO REASONCODE OF P-LCTFM414
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM414
           MOVE 0 TO SOLVE-COUNT OF P-LCTFM414
           MOVE EVENTID-FILTER OF P-LCTFM414 TO W-EVENTID
           MOVE TEAMID-FILTER OF P-LCTFM414 TO W-TEAM-FILTER
           MOVE CHALLENGEID-FILTER OF P-LCTFM414 TO W-CHALL-FILTER
           MOVE CHALLENGEID-SINCE OF P-LCTFM414 TO W-CHALL-SINCE
           MOVE TEAMID-SINCE OF P-LCTFM414 TO W-TEAM-SINCE
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R007-OPEN-CURSOR: Open the cursor                             *
      *===============================================================*
       R007-OPEN-CURSOR SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT CHALLENGEID,
                     TEAMID,
                     PLAYERID,
                     SUBMISSIONID,
                     CREATEDDATE
                FROM TBCTF014
               WHERE EVENTID = :W-EVENTID
                 AND (:W-TEAM-FILTER = 0
                  OR  TEAMID = :W-TEAM-FILTER)
                 AND (:W-CHALL-FILTER = 0
                  OR  CHALLENGEID = :W-CHALL-FILTER)
                 AND (CHALLENGEID > :W-CHALL-SINCE
                  OR (CHALLENGEID = :W-CHALL-SINCE
                  AND TEAMID > :W-TEAM-SINCE))
               ORDER BY CHALLENGEID, TEAMID
               FETCH FIRST 20 ROWS ONLY
                 FOR FETCH ONLY
           END-EXEC

           EXEC SQL
              OPEN C1
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM414
              MOVE N'61' TO REASONCODE OF P-LCTFM414
              STRING N'OPEN CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM414
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
              MOVE N'08' TO RETURNCODE OF P-LCTFM414
              MOVE N'62' TO REASONCODE OF P-LCTFM414
              STRING N'CLOSE CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM414
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
                    :DCLTBCTF014.TEAMID,
                    :DCLTBCTF014.PLAYERID,
                    :DCLTBCTF014.SUBMISSIONID,
                    :DCLTBCTF014.CREATEDDATE
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO SOLVE-COUNT OF P-LCTFM414
              MOVE SOLVE-COUNT OF P-LCTFM414 TO W-I
              PERFORM R220-COPY-ROW
           WHEN 100
              CONTINUE
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM414
              MOVE N'63' TO REASONCODE OF P-LCTFM414
              STRING N'FETCH CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM414
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
                CHALLENGEID OF P-LCTFM414(W-I)
           MOVE TEAMID OF DCLTBCTF014 TO TEAMID OF P-LCTFM414(W-I)
           MOVE PLAYERID OF DCLTBCTF014 TO PLAYERID OF P-LCTFM414(W-I)
           MOVE SUBMISSIONID OF DCLTBCTF014 TO
                SUBMISSIONID OF P-LCTFM414(W-I)
           MOVE CREATEDDATE OF DCLTBCTF014 TO
                CREATEDDATE OF P-LCTFM414(W-I)
           .
       R220-COPY-ROW-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM414==.

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

       END PROGRAM CTFM414.
