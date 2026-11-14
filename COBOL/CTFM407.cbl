       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM407.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * GET /admin/challenges: the challenge library, by CHALLENGEID, *
      * without descriptions. Filter, optional: category from the     *
      * start. The caller (the admin wrapper) has checked CTF.ADMIN.  *
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

           EXEC SQL INCLUDE TBCTF007 END-EXEC.

       01 WORK.
          05 W-SQLCODE    PIC -99999.
          05 W-CAT-PAT.
             49 W-CAT-PAT-LEN  PIC S9(4) COMP-5.
             49 W-CAT-PAT-TEXT PIC N(9).
          05 W-CHALL-SINCE PIC S9(9) COMP-5.
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
       01 P-LCTFM407.
           COPY LCTFM407.

       PROCEDURE DIVISION USING P-LCTFM407.
       MAIN SECTION.
           PERFORM R001-INIT



           IF RETURNCODE OF P-LCTFM407 = N'00'
              PERFORM R007-OPEN-CURSOR
           END-IF

           IF RETURNCODE OF P-LCTFM407 = N'00'
              PERFORM R210-FETCH-CURSOR

              PERFORM WITH TEST BEFORE
                UNTIL RETURNCODE OF P-LCTFM407 NOT = N'00'
                   OR SQLCODE NOT = 0
                   OR CHALLENGE-COUNT OF P-LCTFM407 >= 20
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
           MOVE N'00' TO RETURNCODE OF P-LCTFM407
           MOVE N'00' TO REASONCODE OF P-LCTFM407
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM407
           MOVE 0 TO CHALLENGE-COUNT OF P-LCTFM407
           MOVE 1 TO W-CAT-PAT-LEN
           MOVE N'%' TO W-CAT-PAT-TEXT
           INSPECT CATEGORY-FILTER OF P-LCTFM407
                   REPLACING ALL NX'0000' BY N' '
           IF CATEGORY-FILTER OF P-LCTFM407 NOT = SPACES
              STRING FUNCTION UPPER-CASE(
                        CATEGORY-FILTER OF P-LCTFM407)
                        DELIMITED BY SPACE
                     N'%' DELIMITED BY SIZE
                INTO W-CAT-PAT-TEXT
                WITH POINTER W-CAT-PAT-LEN
              SUBTRACT 1 FROM W-CAT-PAT-LEN
           END-IF
           MOVE CHALLENGEID-SINCE OF P-LCTFM407 TO W-CHALL-SINCE
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
                     CHALLENGETITLE,
                     CATEGORY,
                     CHALLENGETYPE,
                     CREATEDBY,
                     CREATEDDATE,
                     UPDATEDBY,
                     UPDATEDDATE
                FROM TBCTF007
               WHERE CATEGORY LIKE :W-CAT-PAT
                 AND CHALLENGEID > :W-CHALL-SINCE
               ORDER BY CHALLENGEID
               FETCH FIRST 20 ROWS ONLY
                 FOR FETCH ONLY
           END-EXEC

           EXEC SQL
              OPEN C1
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM407
              MOVE N'61' TO REASONCODE OF P-LCTFM407
              STRING N'OPEN CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM407
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
              MOVE N'08' TO RETURNCODE OF P-LCTFM407
              MOVE N'62' TO REASONCODE OF P-LCTFM407
              STRING N'CLOSE CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM407
              PERFORM R900-DSNTIAR
           END-IF
           .
       R190-CLOSE-CURSOR-END.
           EXIT.

      *===============================================================*
      * R210-FETCH-CURSOR: Fetch one challenge                        *
      *===============================================================*
       R210-FETCH-CURSOR SECTION.
           EXEC SQL
              FETCH C1
               INTO :DCLTBCTF007.CHALLENGEID,
                    :DCLTBCTF007.CHALLENGETITLE,
                    :DCLTBCTF007.CATEGORY,
                    :DCLTBCTF007.CHALLENGETYPE,
                    :DCLTBCTF007.CREATEDBY,
                    :DCLTBCTF007.CREATEDDATE,
                    :DCLTBCTF007.UPDATEDBY,
                    :DCLTBCTF007.UPDATEDDATE
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO CHALLENGE-COUNT OF P-LCTFM407
              MOVE CHALLENGE-COUNT OF P-LCTFM407 TO W-I
              PERFORM R220-COPY-ROW
           WHEN 100
              CONTINUE
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM407
              MOVE N'63' TO REASONCODE OF P-LCTFM407
              STRING N'FETCH CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM407
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R210-FETCH-CURSOR-END.
           EXIT.

      *===============================================================*
      * R220-COPY-ROW: Copy the fetched challenge                     *
      *===============================================================*
       R220-COPY-ROW SECTION.
           MOVE CHALLENGEID OF DCLTBCTF007 TO
                CHALLENGEID OF P-LCTFM407(W-I)
           MOVE CHALLENGETITLE OF DCLTBCTF007 TO
                CHALLENGETITLE OF P-LCTFM407(W-I)
           MOVE CATEGORY OF DCLTBCTF007 TO
                CATEGORY OF P-LCTFM407(W-I)
           MOVE CHALLENGETYPE OF DCLTBCTF007 TO
                CHALLENGETYPE OF P-LCTFM407(W-I)
           MOVE CREATEDBY OF DCLTBCTF007 TO
                CREATEDBY OF P-LCTFM407(W-I)
           MOVE CREATEDDATE OF DCLTBCTF007 TO
                CREATEDDATE OF P-LCTFM407(W-I)
           MOVE UPDATEDBY OF DCLTBCTF007 TO
                UPDATEDBY OF P-LCTFM407(W-I)
           MOVE UPDATEDDATE OF DCLTBCTF007 TO
                UPDATEDDATE OF P-LCTFM407(W-I)
           .
       R220-COPY-ROW-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM407==.

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

       END PROGRAM CTFM407.
