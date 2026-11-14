       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM010.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * POST, PUT and DELETE /admin/links: create, read, update or    *
      * delete a link of a challenge, by OPCODE C, R, U or D. The     *
      * caller (the admin wrapper) has checked CTF.ADMIN, and commits *
      * or rolls back.                                                *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Link not found                                        *
      * 08 01 = Error: invalid OPCODE                                 *
      * 08 02 = Error: name or URL missing or too long                *
      * 08 12/21/32/42 = Error: SQL error                             *
      * 08 13 = Error: challenge not found                            *
      * 08 31/41 = Error: update or delete of a missing link          *
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
          05 W-ONE        PIC S9(9) COMP-5.
          05 W-COUNT      PIC S9(9) COMP-5.
          05 C-RACFGRP    PIC N(8) VALUE N'RACFGRP'.
          05 W-BLANK8     PIC N(8) VALUE SPACES.

           COPY CTFCTXW.

       01 ERROR-MESSAGE.
          05 ERROR-LEN    PIC S9(4) COMP
                                     VALUE +720.
          05 ERROR-TEXT   PIC X(72) OCCURS 10 TIMES
                INDEXED BY ERROR-INDEX.
       77 ERROR-TEXT-LEN  PIC S9(9) COMP
                                     VALUE +72.

       LINKAGE SECTION.
       01 P-LCTFM010.
           COPY LCTFM010.

       PROCEDURE DIVISION USING P-LCTFM010.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R002-CHECKPARM

           PERFORM R090-GET-USERID

           IF RETURNCODE OF P-LCTFM010 = N'00'
              EVALUATE OPCODE OF P-LCTFM010
              WHEN N'C'
                 PERFORM R110-CREATE
              WHEN N'R'
                 PERFORM R120-READ
              WHEN N'U'
                 PERFORM R130-UPDATE
              WHEN N'D'
                 PERFORM R140-DELETE
              END-EVALUATE
           END-IF

      *    Answer with the row as it is now
           IF RETURNCODE OF P-LCTFM010 = N'00'
           AND (OPCODE OF P-LCTFM010 = N'C'
             OR OPCODE OF P-LCTFM010 = N'U')
              PERFORM R120-READ
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM010
           MOVE N'00' TO REASONCODE OF P-LCTFM010
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM010
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R002-CHECKPARM: Check the input                               *
      *===============================================================*
       R002-CHECKPARM SECTION.
           IF OPCODE OF P-LCTFM010 NOT = N'C'
             AND OPCODE OF P-LCTFM010 NOT = N'R'
             AND OPCODE OF P-LCTFM010 NOT = N'U'
             AND OPCODE OF P-LCTFM010 NOT = N'D'
              MOVE N'08' TO RETURNCODE OF P-LCTFM010
              MOVE N'01' TO REASONCODE OF P-LCTFM010
              MOVE N'Invalid OPCODE' TO
                   INFOMESSAGE OF P-LCTFM010
           END-IF

           IF RETURNCODE OF P-LCTFM010 = N'00'
           AND (OPCODE OF P-LCTFM010 = N'C'
             OR OPCODE OF P-LCTFM010 = N'U')
              PERFORM R020-CHECK-FIELDS
           END-IF
           .
       R002-CHECKPARM-END.
           EXIT.

      *===============================================================*
      * R020-CHECK-FIELDS: Check the fields of C and U                *
      *===============================================================*
       R020-CHECK-FIELDS SECTION.
           IF RETURNCODE OF P-LCTFM010 = N'00'
           AND (LINKNAME-LEN OF P-LCTFM010 < 1
             OR LINKNAME-LEN OF P-LCTFM010 > 60)
              MOVE N'08' TO RETURNCODE OF P-LCTFM010
              MOVE N'02' TO REASONCODE OF P-LCTFM010
              MOVE N'linkName is required, up to 60 characters' TO
                   INFOMESSAGE OF P-LCTFM010
           END-IF

           IF RETURNCODE OF P-LCTFM010 = N'00'
           AND (LINKURL-LEN OF P-LCTFM010 < 1
             OR LINKURL-LEN OF P-LCTFM010 > 500)
              MOVE N'08' TO RETURNCODE OF P-LCTFM010
              MOVE N'02' TO REASONCODE OF P-LCTFM010
              MOVE N'linkUrl is required, up to 500 characters' TO
                   INFOMESSAGE OF P-LCTFM010
           END-IF

           MOVE LINKNAME OF P-LCTFM010 TO LINKNAME OF DCLTBCTF010
           MOVE LINKURL OF P-LCTFM010 TO LINKURL OF DCLTBCTF010
           .
       R020-CHECK-FIELDS-END.
           EXIT.

      *===============================================================*
      * R110-CREATE: Insert the row                                   *
      *===============================================================*
       R110-CREATE SECTION.
           MOVE CHALLENGEID OF P-LCTFM010 TO CHALLENGEID OF DCLTBCTF010

           EXEC SQL
              SELECT LINKID
                INTO :DCLTBCTF010.LINKID
                FROM FINAL TABLE
                   (
              INSERT
                INTO TBCTF010
                     (CHALLENGEID,
                     LINKNAME,
                     LINKURL,
                      CREATEDBY,
                      CREATEDDATE,
                      UPDATEDBY,
                      UPDATEDDATE)
              VALUES(:DCLTBCTF010.CHALLENGEID,
                     :DCLTBCTF010.LINKNAME,
                     :DCLTBCTF010.LINKURL,
                     :W-USERID,
                     CURRENT TIMESTAMP,
                     :W-USERID,
                     CURRENT TIMESTAMP)
                     )
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              CONTINUE
           WHEN -530
              MOVE N'08' TO RETURNCODE OF P-LCTFM010
              MOVE N'13' TO REASONCODE OF P-LCTFM010
              MOVE N'Challenge not found' TO
                   INFOMESSAGE OF P-LCTFM010
           WHEN -803
              MOVE N'08' TO RETURNCODE OF P-LCTFM010
              MOVE N'11' TO REASONCODE OF P-LCTFM010
              MOVE N'This row exists already' TO
                   INFOMESSAGE OF P-LCTFM010
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM010
              MOVE N'12' TO REASONCODE OF P-LCTFM010
              STRING N'INSERT gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM010
              PERFORM R900-DSNTIAR
           END-EVALUATE

           IF RETURNCODE OF P-LCTFM010 = N'00'
              MOVE LINKID OF DCLTBCTF010 TO LINKID OF P-LCTFM010
           END-IF
           .
       R110-CREATE-END.
           EXIT.

      *===============================================================*
      * R120-READ: Read the row                                       *
      *===============================================================*
       R120-READ SECTION.
           MOVE LINKID OF P-LCTFM010 TO LINKID OF DCLTBCTF010

           EXEC SQL
              SELECT LINKID,
                     CHALLENGEID,
                     LINKNAME,
                     LINKURL,
                     CREATEDBY,
                     CREATEDDATE,
                     UPDATEDBY,
                     UPDATEDDATE
                INTO :DCLTBCTF010.LINKID,
                     :DCLTBCTF010.CHALLENGEID,
                     :DCLTBCTF010.LINKNAME,
                     :DCLTBCTF010.LINKURL,
                     :DCLTBCTF010.CREATEDBY,
                     :DCLTBCTF010.CREATEDDATE,
                     :DCLTBCTF010.UPDATEDBY,
                     :DCLTBCTF010.UPDATEDDATE
                FROM TBCTF010
               WHERE LINKID = :DCLTBCTF010.LINKID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              PERFORM R121-COPY-ROW
           WHEN 100
              MOVE N'04' TO RETURNCODE OF P-LCTFM010
              MOVE N'01' TO REASONCODE OF P-LCTFM010
              MOVE N'Link not found' TO
                   INFOMESSAGE OF P-LCTFM010
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM010
              MOVE N'21' TO REASONCODE OF P-LCTFM010
              STRING N'SELECT gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM010
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R120-READ-END.
           EXIT.

      *===============================================================*
      * R130-UPDATE: Update the row                                   *
      *===============================================================*
       R130-UPDATE SECTION.
           MOVE LINKID OF P-LCTFM010 TO LINKID OF DCLTBCTF010

           EXEC SQL
              UPDATE TBCTF010
                 SET LINKNAME      = :DCLTBCTF010.LINKNAME,
                     LINKURL       = :DCLTBCTF010.LINKURL,
                     UPDATEDBY   = :W-USERID,
                     UPDATEDDATE = CURRENT TIMESTAMP
               WHERE LINKID = :DCLTBCTF010.LINKID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              CONTINUE
           WHEN 100
              MOVE N'08' TO RETURNCODE OF P-LCTFM010
              MOVE N'31' TO REASONCODE OF P-LCTFM010
              MOVE N'Link not found' TO
                   INFOMESSAGE OF P-LCTFM010
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM010
              MOVE N'32' TO REASONCODE OF P-LCTFM010
              STRING N'UPDATE gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM010
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R130-UPDATE-END.
           EXIT.

      *===============================================================*
      * R140-DELETE: Delete the row                                   *
      *===============================================================*
       R140-DELETE SECTION.
           MOVE LINKID OF P-LCTFM010 TO LINKID OF DCLTBCTF010

      *    No rules for deleting a link

           IF RETURNCODE OF P-LCTFM010 = N'00'
              EXEC SQL
                 DELETE FROM TBCTF010
                  WHERE LINKID = :DCLTBCTF010.LINKID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 MOVE N'08' TO RETURNCODE OF P-LCTFM010
                 MOVE N'41' TO REASONCODE OF P-LCTFM010
                 MOVE N'Link not found' TO
                      INFOMESSAGE OF P-LCTFM010
              WHEN -532
                 MOVE N'08' TO RETURNCODE OF P-LCTFM010
                 MOVE N'53' TO REASONCODE OF P-LCTFM010
                 MOVE N'Other rows still refer to this one' TO
                      INFOMESSAGE OF P-LCTFM010
              WHEN OTHER
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM010
                 MOVE N'42' TO REASONCODE OF P-LCTFM010
                 STRING N'DELETE gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM010
                 PERFORM R900-DSNTIAR
              END-EVALUATE
           END-IF
           .
       R140-DELETE-END.
           EXIT.

      *===============================================================*
      * R121-COPY-ROW: Copy the row to the IO area                    *
      *===============================================================*
       R121-COPY-ROW SECTION.
           MOVE LINKID OF DCLTBCTF010 TO LINKID OF P-LCTFM010
           MOVE CHALLENGEID OF DCLTBCTF010 TO CHALLENGEID OF P-LCTFM010
           MOVE LINKNAME OF DCLTBCTF010 TO LINKNAME OF P-LCTFM010
           MOVE LINKURL OF DCLTBCTF010 TO LINKURL OF P-LCTFM010
           MOVE CREATEDBY OF DCLTBCTF010 TO CREATEDBY OF P-LCTFM010
           MOVE CREATEDDATE OF DCLTBCTF010 TO CREATEDDATE OF P-LCTFM010
           MOVE UPDATEDBY OF DCLTBCTF010 TO UPDATEDBY OF P-LCTFM010
           MOVE UPDATEDDATE OF DCLTBCTF010 TO UPDATEDDATE OF P-LCTFM010
           .
       R121-COPY-ROW-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM010==.

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

       END PROGRAM CTFM010.
