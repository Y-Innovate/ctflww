       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM412.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * GET /admin/prerequisites: the prerequisites of an event, by   *
      * CHALLENGEID and REQCHALLENGEID. Filter, optional: one locked  *
      * challenge. Paging: CHALLENGEID-SINCE and REQCHALLENGEID-SINCE *
      * are the last row of the previous page. The caller (the admin  *
      * wrapper) has checked CTF.ADMIN.                               *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success, also when there are no rows                  *
      * 08 01 = Error: a required filter is missing                   *
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

           EXEC SQL INCLUDE TBCTF012 END-EXEC.

       01 WORK.
          05 W-SQLCODE    PIC -99999.
          05 W-EVENT      PIC S9(9) COMP-5.
          05 W-FILTER     PIC S9(9) COMP-5.
          05 W-SINCE      PIC S9(9) COMP-5.
          05 W-REQ-SINCE  PIC S9(9) COMP-5.
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
       01 P-LCTFM412.
           COPY LCTFM412.

       PROCEDURE DIVISION USING P-LCTFM412.
       MAIN SECTION.
           PERFORM R001-INIT

           IF EVENTID-FILTER OF P-LCTFM412 = 0
              MOVE N'08' TO RETURNCODE OF P-LCTFM412
              MOVE N'01' TO REASONCODE OF P-LCTFM412
              MOVE N'eventID is required' TO
                   INFOMESSAGE OF P-LCTFM412
           END-IF

           IF RETURNCODE OF P-LCTFM412 = N'00'
              PERFORM R007-OPEN-CURSOR
           END-IF

           IF RETURNCODE OF P-LCTFM412 = N'00'
              PERFORM R210-FETCH-CURSOR

              PERFORM WITH TEST BEFORE
                UNTIL RETURNCODE OF P-LCTFM412 NOT = N'00'
                   OR SQLCODE NOT = 0
                   OR PREREQ-COUNT OF P-LCTFM412 >= 20
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
           MOVE N'00' TO RETURNCODE OF P-LCTFM412
           MOVE N'00' TO REASONCODE OF P-LCTFM412
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM412
           MOVE 0 TO PREREQ-COUNT OF P-LCTFM412
           MOVE EVENTID-FILTER OF P-LCTFM412 TO W-EVENT
           MOVE CHALLENGEID-FILTER OF P-LCTFM412 TO W-FILTER
           MOVE CHALLENGEID-SINCE OF P-LCTFM412 TO W-SINCE
           MOVE REQCHALLENGEID-SINCE OF P-LCTFM412 TO W-REQ-SINCE
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R007-OPEN-CURSOR: Open the cursor                             *
      *===============================================================*
       R007-OPEN-CURSOR SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT EVENTID,
                     CHALLENGEID,
                     REQCHALLENGEID,
                     CREATEDBY,
                     CREATEDDATE,
                     UPDATEDBY,
                     UPDATEDDATE
                FROM TBCTF012
               WHERE EVENTID = :W-EVENT
                 AND (:W-FILTER = 0
                  OR  CHALLENGEID = :W-FILTER)
                 AND (CHALLENGEID > :W-SINCE
                  OR (CHALLENGEID = :W-SINCE
                 AND  REQCHALLENGEID > :W-REQ-SINCE))
               ORDER BY CHALLENGEID, REQCHALLENGEID
               FETCH FIRST 20 ROWS ONLY
                 FOR FETCH ONLY
           END-EXEC

           EXEC SQL
              OPEN C1
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM412
              MOVE N'61' TO REASONCODE OF P-LCTFM412
              STRING N'OPEN CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM412
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
              MOVE N'08' TO RETURNCODE OF P-LCTFM412
              MOVE N'62' TO REASONCODE OF P-LCTFM412
              STRING N'CLOSE CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM412
              PERFORM R900-DSNTIAR
           END-IF
           .
       R190-CLOSE-CURSOR-END.
           EXIT.

      *===============================================================*
      * R210-FETCH-CURSOR: Fetch one prerequisite                     *
      *===============================================================*
       R210-FETCH-CURSOR SECTION.
           EXEC SQL
              FETCH C1
               INTO :DCLTBCTF012.EVENTID,
                    :DCLTBCTF012.CHALLENGEID,
                    :DCLTBCTF012.REQCHALLENGEID,
                    :DCLTBCTF012.CREATEDBY,
                    :DCLTBCTF012.CREATEDDATE,
                    :DCLTBCTF012.UPDATEDBY,
                    :DCLTBCTF012.UPDATEDDATE
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO PREREQ-COUNT OF P-LCTFM412
              MOVE PREREQ-COUNT OF P-LCTFM412 TO W-I
              PERFORM R220-COPY-ROW
           WHEN 100
              CONTINUE
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM412
              MOVE N'63' TO REASONCODE OF P-LCTFM412
              STRING N'FETCH CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM412
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R210-FETCH-CURSOR-END.
           EXIT.

      *===============================================================*
      * R220-COPY-ROW: Copy the fetched prerequisite                  *
      *===============================================================*
       R220-COPY-ROW SECTION.
           MOVE EVENTID OF DCLTBCTF012 TO
                EVENTID OF P-LCTFM412(W-I)
           MOVE CHALLENGEID OF DCLTBCTF012 TO
                CHALLENGEID OF P-LCTFM412(W-I)
           MOVE REQCHALLENGEID OF DCLTBCTF012 TO
                REQCHALLENGEID OF P-LCTFM412(W-I)
           MOVE CREATEDBY OF DCLTBCTF012 TO
                CREATEDBY OF P-LCTFM412(W-I)
           MOVE CREATEDDATE OF DCLTBCTF012 TO
                CREATEDDATE OF P-LCTFM412(W-I)
           MOVE UPDATEDBY OF DCLTBCTF012 TO
                UPDATEDBY OF P-LCTFM412(W-I)
           MOVE UPDATEDDATE OF DCLTBCTF012 TO
                UPDATEDDATE OF P-LCTFM412(W-I)
           .
       R220-COPY-ROW-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM412==.

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

       END PROGRAM CTFM412.
