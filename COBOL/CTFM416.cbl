       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM416.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * GET /admin/awards: the awards and penalties of an event, by   *
      * AWARDID. Filter, optional: team. The caller (the admin wrapper)*
      * has checked CTF.ADMIN.                                        *
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

           EXEC SQL INCLUDE TBCTF016 END-EXEC.

       01 WORK.
          05 W-SQLCODE    PIC -99999.
          05 W-TEAM-FILTER PIC S9(9) COMP-5.
          05 W-AWARD-SINCE PIC S9(9) COMP-5.
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
       01 P-LCTFM416.
           COPY LCTFM416.

       PROCEDURE DIVISION USING P-LCTFM416.
       MAIN SECTION.
           PERFORM R001-INIT

      *    The admin wrapper has checked CTF.ADMIN already

           IF RETURNCODE OF P-LCTFM416 = N'00'
              PERFORM R007-OPEN-CURSOR
           END-IF

           IF RETURNCODE OF P-LCTFM416 = N'00'
              PERFORM R210-FETCH-CURSOR

              PERFORM WITH TEST BEFORE
                UNTIL RETURNCODE OF P-LCTFM416 NOT = N'00'
                   OR SQLCODE NOT = 0
                   OR AWARD-COUNT OF P-LCTFM416 >= 20
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
           MOVE N'00' TO RETURNCODE OF P-LCTFM416
           MOVE N'00' TO REASONCODE OF P-LCTFM416
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM416
           MOVE 0 TO AWARD-COUNT OF P-LCTFM416
           MOVE EVENTID-FILTER OF P-LCTFM416 TO W-EVENTID
           MOVE TEAMID-FILTER OF P-LCTFM416 TO W-TEAM-FILTER
           MOVE AWARDID-SINCE OF P-LCTFM416 TO W-AWARD-SINCE
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R007-OPEN-CURSOR: Open the cursor                             *
      *===============================================================*
       R007-OPEN-CURSOR SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT AWARDID,
                     EVENTID,
                     TEAMID,
                     POINTS,
                     REASON,
                     CREATEDBY,
                     CREATEDDATE,
                     UPDATEDBY,
                     UPDATEDDATE
                FROM TBCTF016
               WHERE EVENTID = :W-EVENTID
                 AND (:W-TEAM-FILTER = 0
                  OR  TEAMID = :W-TEAM-FILTER)
                 AND AWARDID > :W-AWARD-SINCE
               ORDER BY AWARDID
               FETCH FIRST 20 ROWS ONLY
                 FOR FETCH ONLY
           END-EXEC

           EXEC SQL
              OPEN C1
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM416
              MOVE N'61' TO REASONCODE OF P-LCTFM416
              STRING N'OPEN CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM416
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
              MOVE N'08' TO RETURNCODE OF P-LCTFM416
              MOVE N'62' TO REASONCODE OF P-LCTFM416
              STRING N'CLOSE CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM416
              PERFORM R900-DSNTIAR
           END-IF
           .
       R190-CLOSE-CURSOR-END.
           EXIT.

      *===============================================================*
      * R210-FETCH-CURSOR: Fetch one award                            *
      *===============================================================*
       R210-FETCH-CURSOR SECTION.
           EXEC SQL
              FETCH C1
               INTO :DCLTBCTF016.AWARDID,
                    :DCLTBCTF016.EVENTID,
                    :DCLTBCTF016.TEAMID,
                    :DCLTBCTF016.POINTS,
                    :DCLTBCTF016.REASON,
                    :DCLTBCTF016.CREATEDBY,
                    :DCLTBCTF016.CREATEDDATE,
                    :DCLTBCTF016.UPDATEDBY,
                    :DCLTBCTF016.UPDATEDDATE
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO AWARD-COUNT OF P-LCTFM416
              MOVE AWARD-COUNT OF P-LCTFM416 TO W-I
              PERFORM R220-COPY-ROW
           WHEN 100
              CONTINUE
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM416
              MOVE N'63' TO REASONCODE OF P-LCTFM416
              STRING N'FETCH CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM416
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R210-FETCH-CURSOR-END.
           EXIT.

      *===============================================================*
      * R220-COPY-ROW: Copy the fetched award                         *
      *===============================================================*
       R220-COPY-ROW SECTION.
           MOVE AWARDID OF DCLTBCTF016 TO AWARDID OF P-LCTFM416(W-I)
           MOVE EVENTID OF DCLTBCTF016 TO EVENTID OF P-LCTFM416(W-I)
           MOVE TEAMID OF DCLTBCTF016 TO TEAMID OF P-LCTFM416(W-I)
           MOVE POINTS OF DCLTBCTF016 TO POINTS OF P-LCTFM416(W-I)
           MOVE REASON OF DCLTBCTF016 TO REASON OF P-LCTFM416(W-I)
           MOVE CREATEDBY OF DCLTBCTF016 TO CREATEDBY OF P-LCTFM416(W-I)
           MOVE CREATEDDATE OF DCLTBCTF016 TO
                CREATEDDATE OF P-LCTFM416(W-I)
           MOVE UPDATEDBY OF DCLTBCTF016 TO UPDATEDBY OF P-LCTFM416(W-I)
           MOVE UPDATEDDATE OF DCLTBCTF016 TO
                UPDATEDDATE OF P-LCTFM416(W-I)
           .
       R220-COPY-ROW-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM416==.

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

       END PROGRAM CTFM416.
