       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM210.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * GET /challengeLinks: the links of a challenge, by LINKID.     *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success, also when there are no rows                  *
      * 04 01 = Challenge not found or not visible                    *
      * 08 21 = Error: SQL error in SELECT                            *
      * 08 50 = Error: no active place in a team, or locked           *
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

           EXEC SQL INCLUDE TBCTF010 END-EXEC.

       01 WORK.
          05 W-SQLCODE    PIC -99999.
          05 W-LINK-SINCE PIC S9(9) COMP-5.
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
       01 P-LCTFM210.
           COPY LCTFM210.

       PROCEDURE DIVISION USING P-LCTFM210.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R100-GET-CONTEXT
           PERFORM R101-NEED-TEAM
           PERFORM R102-NEED-STARTED
           PERFORM R106-CHECK-CHALLENGE

           IF RETURNCODE OF P-LCTFM210 = N'00'
              PERFORM R007-OPEN-CURSOR
           END-IF

           IF RETURNCODE OF P-LCTFM210 = N'00'
              PERFORM R210-FETCH-CURSOR

              PERFORM WITH TEST BEFORE
                UNTIL RETURNCODE OF P-LCTFM210 NOT = N'00'
                   OR SQLCODE NOT = 0
                   OR LINK-COUNT OF P-LCTFM210 >= 20
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
           MOVE N'00' TO RETURNCODE OF P-LCTFM210
           MOVE N'00' TO REASONCODE OF P-LCTFM210
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM210
           MOVE 0 TO LINK-COUNT OF P-LCTFM210
           MOVE EVENTID OF P-LCTFM210 TO W-EVENTID
           MOVE CHALLENGEID OF P-LCTFM210 TO W-CHALLENGEID
           MOVE 'N' TO W-ALLOW-LOCKED
           MOVE LINKID-SINCE OF P-LCTFM210 TO W-LINK-SINCE
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R007-OPEN-CURSOR: Open the cursor                             *
      *===============================================================*
       R007-OPEN-CURSOR SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT LINKID,
                     LINKNAME,
                     LINKURL
                FROM TBCTF010
               WHERE CHALLENGEID = :W-CHALLENGEID
                 AND LINKID > :W-LINK-SINCE
               ORDER BY LINKID
               FETCH FIRST 20 ROWS ONLY
                 FOR FETCH ONLY
           END-EXEC

           EXEC SQL
              OPEN C1
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM210
              MOVE N'61' TO REASONCODE OF P-LCTFM210
              STRING N'OPEN CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM210
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
              MOVE N'08' TO RETURNCODE OF P-LCTFM210
              MOVE N'62' TO REASONCODE OF P-LCTFM210
              STRING N'CLOSE CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM210
              PERFORM R900-DSNTIAR
           END-IF
           .
       R190-CLOSE-CURSOR-END.
           EXIT.

      *===============================================================*
      * R210-FETCH-CURSOR: Fetch one link                             *
      *===============================================================*
       R210-FETCH-CURSOR SECTION.
           EXEC SQL
              FETCH C1
               INTO :DCLTBCTF010.LINKID,
                    :DCLTBCTF010.LINKNAME,
                    :DCLTBCTF010.LINKURL
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO LINK-COUNT OF P-LCTFM210
              MOVE LINK-COUNT OF P-LCTFM210 TO W-I
              PERFORM R220-COPY-ROW
           WHEN 100
              CONTINUE
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM210
              MOVE N'63' TO REASONCODE OF P-LCTFM210
              STRING N'FETCH CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM210
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R210-FETCH-CURSOR-END.
           EXIT.

      *===============================================================*
      * R220-COPY-ROW: Copy the fetched link                          *
      *===============================================================*
       R220-COPY-ROW SECTION.
           MOVE LINKID OF DCLTBCTF010 TO LINKID OF P-LCTFM210(W-I)
           MOVE LINKNAME OF DCLTBCTF010 TO LINKNAME OF P-LCTFM210(W-I)
           MOVE LINKURL OF DCLTBCTF010 TO LINKURL OF P-LCTFM210(W-I)
           .
       R220-COPY-ROW-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM210==.

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

       END PROGRAM CTFM210.
