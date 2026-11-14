       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM409.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * GET /admin/hints: the hints of a challenge with their text, by*
      * HINTID. The caller (the admin wrapper) has checked CTF.ADMIN. *
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

           EXEC SQL INCLUDE TBCTF009 END-EXEC.

       01 WORK.
          05 W-SQLCODE    PIC -99999.
          05 W-CHALLENGE  PIC S9(9) COMP-5.
          05 W-SINCE      PIC S9(9) COMP-5.
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
       01 P-LCTFM409.
           COPY LCTFM409.

       PROCEDURE DIVISION USING P-LCTFM409.
       MAIN SECTION.
           PERFORM R001-INIT

           IF CHALLENGEID-FILTER OF P-LCTFM409 = 0
              MOVE N'08' TO RETURNCODE OF P-LCTFM409
              MOVE N'01' TO REASONCODE OF P-LCTFM409
              MOVE N'challengeID is required' TO
                   INFOMESSAGE OF P-LCTFM409
           END-IF

           IF RETURNCODE OF P-LCTFM409 = N'00'
              PERFORM R007-OPEN-CURSOR
           END-IF

           IF RETURNCODE OF P-LCTFM409 = N'00'
              PERFORM R210-FETCH-CURSOR

              PERFORM WITH TEST BEFORE
                UNTIL RETURNCODE OF P-LCTFM409 NOT = N'00'
                   OR SQLCODE NOT = 0
                   OR HINT-COUNT OF P-LCTFM409 >= 20
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
           MOVE N'00' TO RETURNCODE OF P-LCTFM409
           MOVE N'00' TO REASONCODE OF P-LCTFM409
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM409
           MOVE 0 TO HINT-COUNT OF P-LCTFM409
           MOVE CHALLENGEID-FILTER OF P-LCTFM409 TO W-CHALLENGE
           MOVE HINTID-SINCE OF P-LCTFM409 TO W-SINCE
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R007-OPEN-CURSOR: Open the cursor                             *
      *===============================================================*
       R007-OPEN-CURSOR SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT HINTID,
                     CHALLENGEID,
                     SORTORDER,
                     HINTTEXT,
                     COST,
                     CREATEDBY,
                     CREATEDDATE,
                     UPDATEDBY,
                     UPDATEDDATE
                FROM TBCTF009
               WHERE CHALLENGEID = :W-CHALLENGE
                 AND HINTID > :W-SINCE
               ORDER BY HINTID
               FETCH FIRST 20 ROWS ONLY
                 FOR FETCH ONLY
           END-EXEC

           EXEC SQL
              OPEN C1
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM409
              MOVE N'61' TO REASONCODE OF P-LCTFM409
              STRING N'OPEN CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM409
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
              MOVE N'08' TO RETURNCODE OF P-LCTFM409
              MOVE N'62' TO REASONCODE OF P-LCTFM409
              STRING N'CLOSE CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM409
              PERFORM R900-DSNTIAR
           END-IF
           .
       R190-CLOSE-CURSOR-END.
           EXIT.

      *===============================================================*
      * R210-FETCH-CURSOR: Fetch one hint                             *
      *===============================================================*
       R210-FETCH-CURSOR SECTION.
           EXEC SQL
              FETCH C1
               INTO :DCLTBCTF009.HINTID,
                    :DCLTBCTF009.CHALLENGEID,
                    :DCLTBCTF009.SORTORDER,
                    :DCLTBCTF009.HINTTEXT,
                    :DCLTBCTF009.COST,
                    :DCLTBCTF009.CREATEDBY,
                    :DCLTBCTF009.CREATEDDATE,
                    :DCLTBCTF009.UPDATEDBY,
                    :DCLTBCTF009.UPDATEDDATE
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO HINT-COUNT OF P-LCTFM409
              MOVE HINT-COUNT OF P-LCTFM409 TO W-I
              PERFORM R220-COPY-ROW
           WHEN 100
              CONTINUE
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM409
              MOVE N'63' TO REASONCODE OF P-LCTFM409
              STRING N'FETCH CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM409
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R210-FETCH-CURSOR-END.
           EXIT.

      *===============================================================*
      * R220-COPY-ROW: Copy the fetched hint                          *
      *===============================================================*
       R220-COPY-ROW SECTION.
           MOVE HINTID OF DCLTBCTF009 TO
                HINTID OF P-LCTFM409(W-I)
           MOVE CHALLENGEID OF DCLTBCTF009 TO
                CHALLENGEID OF P-LCTFM409(W-I)
           MOVE SORTORDER OF DCLTBCTF009 TO
                SORTORDER OF P-LCTFM409(W-I)
           MOVE HINTTEXT OF DCLTBCTF009 TO
                HINTTEXT OF P-LCTFM409(W-I)
           MOVE COST OF DCLTBCTF009 TO
                COST OF P-LCTFM409(W-I)
           MOVE CREATEDBY OF DCLTBCTF009 TO
                CREATEDBY OF P-LCTFM409(W-I)
           MOVE CREATEDDATE OF DCLTBCTF009 TO
                CREATEDDATE OF P-LCTFM409(W-I)
           MOVE UPDATEDBY OF DCLTBCTF009 TO
                UPDATEDBY OF P-LCTFM409(W-I)
           MOVE UPDATEDDATE OF DCLTBCTF009 TO
                UPDATEDDATE OF P-LCTFM409(W-I)
           .
       R220-COPY-ROW-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM409==.

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

       END PROGRAM CTFM409.
