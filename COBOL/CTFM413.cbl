       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM413.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * GET /admin/submissions: the attempts in an event, newest first,*
      * so SUBMISSIONID-SINCE pages downwards; 0 = start. Filters, each*
      * optional: team, player, challenge, ISCORRECT Y or N. A reversed*
      * solve keeps ISCORRECT Y and has REVERSEDBY, REVERSEDDATE and  *
      * REVERSEREASON. The caller (the admin wrapper) has checked     *
      * CTF.ADMIN.                                                    *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success, also when there are no rows                  *
      * 08 01 = Error: invalid isCorrect filter                       *
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

           EXEC SQL INCLUDE TBCTF013 END-EXEC.

       01 WORK.
          05 W-SQLCODE    PIC -99999.
          05 W-SUBM-SINCE PIC S9(9) COMP-5.
          05 W-TEAM-FILTER PIC S9(9) COMP-5.
          05 W-PLAYER-FILTER PIC S9(9) COMP-5.
          05 W-CHALL-FILTER PIC S9(9) COMP-5.
          05 W-CORRECT    PIC N.
          05 W-ALL-CORRECT PIC X.
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
       01 P-LCTFM413.
           COPY LCTFM413.

       PROCEDURE DIVISION USING P-LCTFM413.
       MAIN SECTION.
           PERFORM R001-INIT

      *    The admin wrapper has checked CTF.ADMIN already

           PERFORM R002-CHECKPARM

           IF RETURNCODE OF P-LCTFM413 = N'00'
              PERFORM R007-OPEN-CURSOR
           END-IF

           IF RETURNCODE OF P-LCTFM413 = N'00'
              PERFORM R210-FETCH-CURSOR

              PERFORM WITH TEST BEFORE
                UNTIL RETURNCODE OF P-LCTFM413 NOT = N'00'
                   OR SQLCODE NOT = 0
                   OR SUBM-COUNT OF P-LCTFM413 >= 20
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
           MOVE N'00' TO RETURNCODE OF P-LCTFM413
           MOVE N'00' TO REASONCODE OF P-LCTFM413
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM413
           MOVE 0 TO SUBM-COUNT OF P-LCTFM413
           MOVE EVENTID-FILTER OF P-LCTFM413 TO W-EVENTID
           MOVE TEAMID-FILTER OF P-LCTFM413 TO W-TEAM-FILTER
           MOVE PLAYERID-FILTER OF P-LCTFM413 TO W-PLAYER-FILTER
           MOVE CHALLENGEID-FILTER OF P-LCTFM413 TO W-CHALL-FILTER
           MOVE SUBMISSIONID-SINCE OF P-LCTFM413 TO W-SUBM-SINCE
           MOVE ISCORRECT-FILTER OF P-LCTFM413 TO W-CORRECT
           IF W-CORRECT = NX'0000'
              MOVE SPACES TO W-CORRECT
           END-IF
           MOVE FUNCTION UPPER-CASE(W-CORRECT) TO W-CORRECT
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R002-CHECKPARM: Check the input                               *
      *===============================================================*
       R002-CHECKPARM SECTION.
           IF W-CORRECT = SPACES
              MOVE 'Y' TO W-ALL-CORRECT
           ELSE
              MOVE 'N' TO W-ALL-CORRECT
              IF W-CORRECT NOT = C-Y AND W-CORRECT NOT = C-N
                 MOVE N'08' TO RETURNCODE OF P-LCTFM413
                 MOVE N'01' TO REASONCODE OF P-LCTFM413
                 MOVE N'isCorrect_filter must be Y or N' TO
                      INFOMESSAGE OF P-LCTFM413
              END-IF
           END-IF
           .
       R002-CHECKPARM-END.
           EXIT.

      *===============================================================*
      * R007-OPEN-CURSOR: Open the cursor                             *
      *===============================================================*
       R007-OPEN-CURSOR SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT SUBMISSIONID,
                     EVENTID,
                     CHALLENGEID,
                     TEAMID,
                     PLAYERID,
                     SUBMITTEDTEXT,
                     ISCORRECT,
                     REVERSEDBY,
                     REVERSEDDATE,
                     REVERSEREASON,
                     CREATEDDATE
                FROM TBCTF013
               WHERE EVENTID = :W-EVENTID
                 AND (:W-TEAM-FILTER = 0
                  OR  TEAMID = :W-TEAM-FILTER)
                 AND (:W-PLAYER-FILTER = 0
                  OR  PLAYERID = :W-PLAYER-FILTER)
                 AND (:W-CHALL-FILTER = 0
                  OR  CHALLENGEID = :W-CHALL-FILTER)
                 AND (:W-ALL-CORRECT = 'Y'
                  OR  ISCORRECT = :W-CORRECT)
                 AND (:W-SUBM-SINCE = 0
                  OR  SUBMISSIONID < :W-SUBM-SINCE)
               ORDER BY SUBMISSIONID DESC
               FETCH FIRST 20 ROWS ONLY
                 FOR FETCH ONLY
           END-EXEC

           EXEC SQL
              OPEN C1
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM413
              MOVE N'61' TO REASONCODE OF P-LCTFM413
              STRING N'OPEN CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM413
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
              MOVE N'08' TO RETURNCODE OF P-LCTFM413
              MOVE N'62' TO REASONCODE OF P-LCTFM413
              STRING N'CLOSE CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM413
              PERFORM R900-DSNTIAR
           END-IF
           .
       R190-CLOSE-CURSOR-END.
           EXIT.

      *===============================================================*
      * R210-FETCH-CURSOR: Fetch one submission                       *
      *===============================================================*
       R210-FETCH-CURSOR SECTION.
           EXEC SQL
              FETCH C1
               INTO :DCLTBCTF013.SUBMISSIONID,
                    :DCLTBCTF013.EVENTID,
                    :DCLTBCTF013.CHALLENGEID,
                    :DCLTBCTF013.TEAMID,
                    :DCLTBCTF013.PLAYERID,
                    :DCLTBCTF013.SUBMITTEDTEXT,
                    :DCLTBCTF013.ISCORRECT,
                    :DCLTBCTF013.REVERSEDBY
                      :DCLTBCTF013.REVERSEDBY-IND,
                    :DCLTBCTF013.REVERSEDDATE
                      :DCLTBCTF013.REVERSEDDATE-IND,
                    :DCLTBCTF013.REVERSEREASON
                      :DCLTBCTF013.REVERSEREASON-IND,
                    :DCLTBCTF013.CREATEDDATE
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO SUBM-COUNT OF P-LCTFM413
              MOVE SUBM-COUNT OF P-LCTFM413 TO W-I
              PERFORM R220-COPY-ROW
           WHEN 100
              CONTINUE
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM413
              MOVE N'63' TO REASONCODE OF P-LCTFM413
              STRING N'FETCH CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM413
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R210-FETCH-CURSOR-END.
           EXIT.

      *===============================================================*
      * R220-COPY-ROW: Copy the fetched submission                    *
      *===============================================================*
       R220-COPY-ROW SECTION.
           MOVE SUBMISSIONID OF DCLTBCTF013 TO
                SUBMISSIONID OF P-LCTFM413(W-I)
           MOVE EVENTID OF DCLTBCTF013 TO EVENTID OF P-LCTFM413(W-I)
           MOVE CHALLENGEID OF DCLTBCTF013 TO
                CHALLENGEID OF P-LCTFM413(W-I)
           MOVE TEAMID OF DCLTBCTF013 TO TEAMID OF P-LCTFM413(W-I)
           MOVE PLAYERID OF DCLTBCTF013 TO PLAYERID OF P-LCTFM413(W-I)
           MOVE SUBMITTEDTEXT OF DCLTBCTF013 TO
                SUBMITTEDTEXT OF P-LCTFM413(W-I)
           MOVE ISCORRECT OF DCLTBCTF013 TO ISCORRECT OF P-LCTFM413(W-I)
           IF REVERSEDBY-IND OF DCLTBCTF013 < 0
              MOVE SPACES TO REVERSEDBY OF P-LCTFM413(W-I)
              MOVE SPACES TO REVERSEDDATE OF P-LCTFM413(W-I)
              MOVE 0 TO REVERSEREASON-LEN OF P-LCTFM413(W-I)
           ELSE
              MOVE REVERSEDBY OF DCLTBCTF013 TO
                   REVERSEDBY OF P-LCTFM413(W-I)
              MOVE REVERSEDDATE OF DCLTBCTF013 TO
                   REVERSEDDATE OF P-LCTFM413(W-I)
              MOVE REVERSEREASON OF DCLTBCTF013 TO
                   REVERSEREASON OF P-LCTFM413(W-I)
           END-IF
           MOVE CREATEDDATE OF DCLTBCTF013 TO
                CREATEDDATE OF P-LCTFM413(W-I)
           .
       R220-COPY-ROW-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM413==.

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

       END PROGRAM CTFM413.
