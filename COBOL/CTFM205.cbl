       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM205.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * GET /teamMembers: the members of the player's own team in the *
      * event, by PLAYERID. ISCAPTAIN Y for the captain.              *
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

           EXEC SQL INCLUDE TBCTF006 END-EXEC.

       01 WORK.
          05 W-SQLCODE    PIC -99999.
          05 W-PLAYER-SINCE PIC S9(9) COMP-5.
          05 W-CAPTAIN    PIC X.
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
       01 P-LCTFM205.
           COPY LCTFM205.

       PROCEDURE DIVISION USING P-LCTFM205.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R100-GET-CONTEXT
           PERFORM R101-NEED-TEAM

           IF RETURNCODE OF P-LCTFM205 = N'00'
              PERFORM R007-OPEN-CURSOR
           END-IF

           IF RETURNCODE OF P-LCTFM205 = N'00'
              PERFORM R210-FETCH-CURSOR

              PERFORM WITH TEST BEFORE
                UNTIL RETURNCODE OF P-LCTFM205 NOT = N'00'
                   OR SQLCODE NOT = 0
                   OR MEMBER-COUNT OF P-LCTFM205 >= 20
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
           MOVE N'00' TO RETURNCODE OF P-LCTFM205
           MOVE N'00' TO REASONCODE OF P-LCTFM205
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM205
           MOVE 0 TO MEMBER-COUNT OF P-LCTFM205
           MOVE EVENTID OF P-LCTFM205 TO W-EVENTID
           MOVE PLAYERID-SINCE OF P-LCTFM205 TO W-PLAYER-SINCE
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R007-OPEN-CURSOR: Open the cursor                             *
      *===============================================================*
       R007-OPEN-CURSOR SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT PA.PLAYERID,
                     P.DISPLAYNAME,
                     CASE WHEN T.CAPTAINID = PA.PLAYERID
                          THEN 'Y' ELSE 'N' END
                FROM TBCTF006 PA
                JOIN TBCTF003 P
                  ON P.PLAYERID = PA.PLAYERID
                JOIN TBCTF005 T
                  ON T.TEAMID = PA.TEAMID
               WHERE PA.EVENTID = :W-EVENTID
                 AND PA.TEAMID = :W-TEAMID
                 AND PA.PLAYERID > :W-PLAYER-SINCE
               ORDER BY PA.PLAYERID
               FETCH FIRST 20 ROWS ONLY
                 FOR FETCH ONLY
           END-EXEC

           EXEC SQL
              OPEN C1
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM205
              MOVE N'61' TO REASONCODE OF P-LCTFM205
              STRING N'OPEN CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM205
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
              MOVE N'08' TO RETURNCODE OF P-LCTFM205
              MOVE N'62' TO REASONCODE OF P-LCTFM205
              STRING N'CLOSE CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM205
              PERFORM R900-DSNTIAR
           END-IF
           .
       R190-CLOSE-CURSOR-END.
           EXIT.

      *===============================================================*
      * R210-FETCH-CURSOR: Fetch one member                           *
      *===============================================================*
       R210-FETCH-CURSOR SECTION.
           EXEC SQL
              FETCH C1
               INTO :DCLTBCTF006.PLAYERID,
                    :DCLTBCTF003.DISPLAYNAME,
                    :W-CAPTAIN
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO MEMBER-COUNT OF P-LCTFM205
              MOVE MEMBER-COUNT OF P-LCTFM205 TO W-I
              PERFORM R220-COPY-ROW
           WHEN 100
              CONTINUE
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM205
              MOVE N'63' TO REASONCODE OF P-LCTFM205
              STRING N'FETCH CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM205
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R210-FETCH-CURSOR-END.
           EXIT.

      *===============================================================*
      * R220-COPY-ROW: Copy the fetched member                        *
      *===============================================================*
       R220-COPY-ROW SECTION.
           MOVE PLAYERID OF DCLTBCTF006 TO PLAYERID OF P-LCTFM205(W-I)
           MOVE DISPLAYNAME OF DCLTBCTF003 TO
                DISPLAYNAME OF P-LCTFM205(W-I)
           MOVE FUNCTION NATIONAL-OF(W-CAPTAIN) TO
                ISCAPTAIN OF P-LCTFM205(W-I)
           .
       R220-COPY-ROW-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM205==.

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

       END PROGRAM CTFM205.
