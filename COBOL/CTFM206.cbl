       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM206.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * GET /myEvents: the events the player joined, also pending     *
      * places, oldest first. PHASE as in CTFM202. TEAMID 0 and an    *
      * empty TEAMNAME: no team yet. Draft events are left out.       *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success, also when there are no rows                  *
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

           EXEC SQL INCLUDE TBCTF002 END-EXEC.

           EXEC SQL INCLUDE TBCTF005 END-EXEC.

           EXEC SQL INCLUDE TBCTF006 END-EXEC.

       01 WORK.
          05 W-SQLCODE    PIC -99999.
          05 W-EVENT-SINCE PIC S9(9) COMP-5.
          05 W-PHASE      PIC X.
          05 W-TEAM-IND   PIC S9(4) COMP-5.
          05 W-NAME-IND   PIC S9(4) COMP-5.
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
       01 P-LCTFM206.
           COPY LCTFM206.

       PROCEDURE DIVISION USING P-LCTFM206.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R090-GET-USERID

           IF RETURNCODE OF P-LCTFM206 = N'00'
              PERFORM R007-OPEN-CURSOR
           END-IF

           IF RETURNCODE OF P-LCTFM206 = N'00'
              PERFORM R210-FETCH-CURSOR

              PERFORM WITH TEST BEFORE
                UNTIL RETURNCODE OF P-LCTFM206 NOT = N'00'
                   OR SQLCODE NOT = 0
                   OR EVENT-COUNT OF P-LCTFM206 >= 20
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
           MOVE N'00' TO RETURNCODE OF P-LCTFM206
           MOVE N'00' TO REASONCODE OF P-LCTFM206
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM206
           MOVE 0 TO EVENT-COUNT OF P-LCTFM206
           MOVE EVENTID-SINCE OF P-LCTFM206 TO W-EVENT-SINCE
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R007-OPEN-CURSOR: Open the cursor                             *
      *===============================================================*
       R007-OPEN-CURSOR SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT E.EVENTID,
                     E.EVENTNAME,
                     CASE WHEN E.EVENTSTATUS <> :C-P THEN ' '
                          WHEN CURRENT TIMESTAMP < E.STARTTS THEN 'U'
                          WHEN CURRENT TIMESTAMP >= E.ENDTS THEN 'E'
                          WHEN E.FREEZETS <= CURRENT TIMESTAMP
                          THEN 'F'
                          ELSE 'R' END,
                     E.PLAYMODE,
                     PA.PARTSTATUS,
                     T.TEAMID,
                     T.TEAMNAME
                FROM TBCTF003 P
                JOIN TBCTF006 PA
                  ON PA.PLAYERID = P.PLAYERID
                JOIN TBCTF002 E
                  ON E.EVENTID = PA.EVENTID
                LEFT JOIN TBCTF005 T
                  ON T.TEAMID = PA.TEAMID
               WHERE P.RACFUSERID = :W-USERID
                 AND E.EVENTSTATUS <> :C-D
                 AND PA.EVENTID > :W-EVENT-SINCE
               ORDER BY PA.EVENTID
               FETCH FIRST 20 ROWS ONLY
                 FOR FETCH ONLY
           END-EXEC

           EXEC SQL
              OPEN C1
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM206
              MOVE N'61' TO REASONCODE OF P-LCTFM206
              STRING N'OPEN CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM206
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
              MOVE N'08' TO RETURNCODE OF P-LCTFM206
              MOVE N'62' TO REASONCODE OF P-LCTFM206
              STRING N'CLOSE CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM206
              PERFORM R900-DSNTIAR
           END-IF
           .
       R190-CLOSE-CURSOR-END.
           EXIT.

      *===============================================================*
      * R210-FETCH-CURSOR: Fetch one event                            *
      *===============================================================*
       R210-FETCH-CURSOR SECTION.
           EXEC SQL
              FETCH C1
               INTO :DCLTBCTF002.EVENTID,
                    :DCLTBCTF002.EVENTNAME,
                    :W-PHASE,
                    :DCLTBCTF002.PLAYMODE,
                    :DCLTBCTF006.PARTSTATUS,
                    :DCLTBCTF005.TEAMID :W-TEAM-IND,
                    :DCLTBCTF005.TEAMNAME :W-NAME-IND
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO EVENT-COUNT OF P-LCTFM206
              MOVE EVENT-COUNT OF P-LCTFM206 TO W-I
              PERFORM R220-COPY-ROW
           WHEN 100
              CONTINUE
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM206
              MOVE N'63' TO REASONCODE OF P-LCTFM206
              STRING N'FETCH CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM206
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R210-FETCH-CURSOR-END.
           EXIT.

      *===============================================================*
      * R220-COPY-ROW: Copy the fetched event                         *
      *===============================================================*
       R220-COPY-ROW SECTION.
           MOVE EVENTID OF DCLTBCTF002 TO EVENTID OF P-LCTFM206(W-I)
           MOVE EVENTNAME OF DCLTBCTF002 TO EVENTNAME OF P-LCTFM206(W-I)
           MOVE FUNCTION NATIONAL-OF(W-PHASE) TO
                PHASE OF P-LCTFM206(W-I)
           MOVE PLAYMODE OF DCLTBCTF002 TO PLAYMODE OF P-LCTFM206(W-I)
           MOVE PARTSTATUS OF DCLTBCTF006 TO
                PARTSTATUS OF P-LCTFM206(W-I)
           IF W-TEAM-IND < 0
              MOVE 0 TO TEAMID OF P-LCTFM206(W-I)
              MOVE 0 TO TEAMNAME-LEN OF P-LCTFM206(W-I)
           ELSE
              MOVE TEAMID OF DCLTBCTF005 TO TEAMID OF P-LCTFM206(W-I)
              MOVE TEAMNAME OF DCLTBCTF005 TO
                   TEAMNAME OF P-LCTFM206(W-I)
           END-IF
           .
       R220-COPY-ROW-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM206==.

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

       END PROGRAM CTFM206.
