       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM401.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * GET /admin/refTables: reference entries by table ID and key.  *
      * Filter, optional: table ID from the start. Paging: TABLEID-   *
      * SINCE and TABKEY-SINCE are the last entry of the previous     *
      * page. The caller (the admin wrapper) has checked CTF.ADMIN.   *
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

           EXEC SQL INCLUDE TBCTF001 END-EXEC.

       01 WORK.
          05 W-SQLCODE    PIC -99999.
          05 W-TABLE-PAT.
             49 W-TABLE-PAT-LEN  PIC S9(4) COMP-5.
             49 W-TABLE-PAT-TEXT PIC N(9).
          05 W-TABLE-SINCE PIC N(8).
          05 W-KEY-SINCE  PIC N(8).
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
       01 P-LCTFM401.
           COPY LCTFM401.

       PROCEDURE DIVISION USING P-LCTFM401.
       MAIN SECTION.
           PERFORM R001-INIT



           IF RETURNCODE OF P-LCTFM401 = N'00'
              PERFORM R007-OPEN-CURSOR
           END-IF

           IF RETURNCODE OF P-LCTFM401 = N'00'
              PERFORM R210-FETCH-CURSOR

              PERFORM WITH TEST BEFORE
                UNTIL RETURNCODE OF P-LCTFM401 NOT = N'00'
                   OR SQLCODE NOT = 0
                   OR REFTABLE-COUNT OF P-LCTFM401 >= 20
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
           MOVE N'00' TO RETURNCODE OF P-LCTFM401
           MOVE N'00' TO REASONCODE OF P-LCTFM401
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM401
           MOVE 0 TO REFTABLE-COUNT OF P-LCTFM401
           MOVE 1 TO W-TABLE-PAT-LEN
           MOVE N'%' TO W-TABLE-PAT-TEXT
           INSPECT TABLEID-FILTER OF P-LCTFM401
                   REPLACING ALL NX'0000' BY N' '
           IF TABLEID-FILTER OF P-LCTFM401 NOT = SPACES
              STRING FUNCTION UPPER-CASE(
                        TABLEID-FILTER OF P-LCTFM401)
                        DELIMITED BY SPACE
                     N'%' DELIMITED BY SIZE
                INTO W-TABLE-PAT-TEXT
                WITH POINTER W-TABLE-PAT-LEN
              SUBTRACT 1 FROM W-TABLE-PAT-LEN
           END-IF
           INSPECT TABLEID-SINCE OF P-LCTFM401
                   REPLACING ALL NX'0000' BY N' '
           INSPECT TABKEY-SINCE OF P-LCTFM401
                   REPLACING ALL NX'0000' BY N' '
           MOVE TABLEID-SINCE OF P-LCTFM401 TO W-TABLE-SINCE
           MOVE TABKEY-SINCE OF P-LCTFM401 TO W-KEY-SINCE
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R007-OPEN-CURSOR: Open the cursor                             *
      *===============================================================*
       R007-OPEN-CURSOR SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT TABLEID,
                     TABKEY,
                     TABVALUE,
                     CREATEDBY,
                     CREATEDDATE,
                     UPDATEDBY,
                     UPDATEDDATE
                FROM TBCTF001
               WHERE TABLEID LIKE :W-TABLE-PAT
                 AND (TABLEID > :W-TABLE-SINCE
                  OR (TABLEID = :W-TABLE-SINCE
                 AND  TABKEY > :W-KEY-SINCE))
               ORDER BY TABLEID, TABKEY
               FETCH FIRST 20 ROWS ONLY
                 FOR FETCH ONLY
           END-EXEC

           EXEC SQL
              OPEN C1
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM401
              MOVE N'61' TO REASONCODE OF P-LCTFM401
              STRING N'OPEN CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM401
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
              MOVE N'08' TO RETURNCODE OF P-LCTFM401
              MOVE N'62' TO REASONCODE OF P-LCTFM401
              STRING N'CLOSE CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM401
              PERFORM R900-DSNTIAR
           END-IF
           .
       R190-CLOSE-CURSOR-END.
           EXIT.

      *===============================================================*
      * R210-FETCH-CURSOR: Fetch one entry                            *
      *===============================================================*
       R210-FETCH-CURSOR SECTION.
           EXEC SQL
              FETCH C1
               INTO :DCLTBCTF001.TABLEID,
                    :DCLTBCTF001.TABKEY,
                    :DCLTBCTF001.TABVALUE :DCLTBCTF001.TABVALUE-IND,
                    :DCLTBCTF001.CREATEDBY,
                    :DCLTBCTF001.CREATEDDATE,
                    :DCLTBCTF001.UPDATEDBY,
                    :DCLTBCTF001.UPDATEDDATE
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO REFTABLE-COUNT OF P-LCTFM401
              MOVE REFTABLE-COUNT OF P-LCTFM401 TO W-I
              PERFORM R220-COPY-ROW
           WHEN 100
              CONTINUE
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM401
              MOVE N'63' TO REASONCODE OF P-LCTFM401
              STRING N'FETCH CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM401
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R210-FETCH-CURSOR-END.
           EXIT.

      *===============================================================*
      * R220-COPY-ROW: Copy the fetched entry                         *
      *===============================================================*
       R220-COPY-ROW SECTION.
           MOVE TABLEID OF DCLTBCTF001 TO
                TABLEID OF P-LCTFM401(W-I)
           MOVE TABKEY OF DCLTBCTF001 TO
                TABKEY OF P-LCTFM401(W-I)
           IF TABVALUE-IND OF DCLTBCTF001 < 0
              MOVE 0 TO TABVALUE-LEN OF P-LCTFM401(W-I)
           ELSE
              MOVE TABVALUE OF DCLTBCTF001 TO
                   TABVALUE OF P-LCTFM401(W-I)
           END-IF
           MOVE CREATEDBY OF DCLTBCTF001 TO
                CREATEDBY OF P-LCTFM401(W-I)
           MOVE CREATEDDATE OF DCLTBCTF001 TO
                CREATEDDATE OF P-LCTFM401(W-I)
           MOVE UPDATEDBY OF DCLTBCTF001 TO
                UPDATEDBY OF P-LCTFM401(W-I)
           MOVE UPDATEDDATE OF DCLTBCTF001 TO
                UPDATEDDATE OF P-LCTFM401(W-I)
           .
       R220-COPY-ROW-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM401==.

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

       END PROGRAM CTFM401.
