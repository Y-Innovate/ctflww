       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM008.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * POST, PUT and DELETE /admin/flags: create, read, update or    *
      * delete a flag of a challenge, by OPCODE C, R, U or D. Changing*
      * a flag does not undo solves. The last flag of a challenge that*
      * is visible in an event cannot be deleted. The caller (the     *
      * admin wrapper) has checked CTF.ADMIN, and commits or rolls    *
      * back.                                                         *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Flag not found                                        *
      * 08 01 = Error: invalid OPCODE                                 *
      * 08 02 = Error: flag missing or too long                       *
      * 08 03 = Error: caseSensitive not Y or N                       *
      * 08 12/21/32/42 = Error: SQL error                             *
      * 08 13 = Error: challenge not found                            *
      * 08 31/41 = Error: update or delete of a missing flag          *
      * 08 53 = Error: the last flag of a visible challenge           *
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

           EXEC SQL INCLUDE TBCTF008 END-EXEC.

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
       01 P-LCTFM008.
           COPY LCTFM008.

       PROCEDURE DIVISION USING P-LCTFM008.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R002-CHECKPARM

           PERFORM R090-GET-USERID

           IF RETURNCODE OF P-LCTFM008 = N'00'
              EVALUATE OPCODE OF P-LCTFM008
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
           IF RETURNCODE OF P-LCTFM008 = N'00'
           AND (OPCODE OF P-LCTFM008 = N'C'
             OR OPCODE OF P-LCTFM008 = N'U')
              PERFORM R120-READ
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM008
           MOVE N'00' TO REASONCODE OF P-LCTFM008
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM008
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R002-CHECKPARM: Check the input                               *
      *===============================================================*
       R002-CHECKPARM SECTION.
           IF OPCODE OF P-LCTFM008 NOT = N'C'
             AND OPCODE OF P-LCTFM008 NOT = N'R'
             AND OPCODE OF P-LCTFM008 NOT = N'U'
             AND OPCODE OF P-LCTFM008 NOT = N'D'
              MOVE N'08' TO RETURNCODE OF P-LCTFM008
              MOVE N'01' TO REASONCODE OF P-LCTFM008
              MOVE N'Invalid OPCODE' TO
                   INFOMESSAGE OF P-LCTFM008
           END-IF

           IF RETURNCODE OF P-LCTFM008 = N'00'
           AND (OPCODE OF P-LCTFM008 = N'C'
             OR OPCODE OF P-LCTFM008 = N'U')
              PERFORM R020-CHECK-FIELDS
           END-IF
           .
       R002-CHECKPARM-END.
           EXIT.

      *===============================================================*
      * R020-CHECK-FIELDS: Check the fields of C and U                *
      *===============================================================*
       R020-CHECK-FIELDS SECTION.
           IF RETURNCODE OF P-LCTFM008 = N'00'
           AND (FLAGVALUE-LEN OF P-LCTFM008 < 1
             OR FLAGVALUE-LEN OF P-LCTFM008 > 255)
              MOVE N'08' TO RETURNCODE OF P-LCTFM008
              MOVE N'02' TO REASONCODE OF P-LCTFM008
              MOVE N'flagValue is required, up to 255 characters' TO
                   INFOMESSAGE OF P-LCTFM008
           END-IF

           INSPECT CASESENSITIVE OF P-LCTFM008
                   REPLACING ALL NX'0000' BY N' '
           IF RETURNCODE OF P-LCTFM008 = N'00'
           AND (CASESENSITIVE OF P-LCTFM008 NOT = N'Y'
             AND CASESENSITIVE OF P-LCTFM008 NOT = N'N')
              MOVE N'08' TO RETURNCODE OF P-LCTFM008
              MOVE N'03' TO REASONCODE OF P-LCTFM008
              MOVE N'caseSensitive must be Y or N' TO
                   INFOMESSAGE OF P-LCTFM008
           END-IF

           MOVE FLAGVALUE OF P-LCTFM008 TO FLAGVALUE OF DCLTBCTF008
           MOVE CASESENSITIVE OF P-LCTFM008 TO
                CASESENSITIVE OF DCLTBCTF008
           .
       R020-CHECK-FIELDS-END.
           EXIT.

      *===============================================================*
      * R110-CREATE: Insert the row                                   *
      *===============================================================*
       R110-CREATE SECTION.
           MOVE CHALLENGEID OF P-LCTFM008 TO CHALLENGEID OF DCLTBCTF008

           EXEC SQL
              SELECT FLAGID
                INTO :DCLTBCTF008.FLAGID
                FROM FINAL TABLE
                   (
              INSERT
                INTO TBCTF008
                     (CHALLENGEID,
                     FLAGVALUE,
                     CASESENSITIVE,
                      CREATEDBY,
                      CREATEDDATE,
                      UPDATEDBY,
                      UPDATEDDATE)
              VALUES(:DCLTBCTF008.CHALLENGEID,
                     :DCLTBCTF008.FLAGVALUE,
                     :DCLTBCTF008.CASESENSITIVE,
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
              MOVE N'08' TO RETURNCODE OF P-LCTFM008
              MOVE N'13' TO REASONCODE OF P-LCTFM008
              MOVE N'Challenge not found' TO
                   INFOMESSAGE OF P-LCTFM008
           WHEN -803
              MOVE N'08' TO RETURNCODE OF P-LCTFM008
              MOVE N'11' TO REASONCODE OF P-LCTFM008
              MOVE N'This row exists already' TO
                   INFOMESSAGE OF P-LCTFM008
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM008
              MOVE N'12' TO REASONCODE OF P-LCTFM008
              STRING N'INSERT gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM008
              PERFORM R900-DSNTIAR
           END-EVALUATE

           IF RETURNCODE OF P-LCTFM008 = N'00'
              MOVE FLAGID OF DCLTBCTF008 TO FLAGID OF P-LCTFM008
           END-IF
           .
       R110-CREATE-END.
           EXIT.

      *===============================================================*
      * R120-READ: Read the row                                       *
      *===============================================================*
       R120-READ SECTION.
           MOVE FLAGID OF P-LCTFM008 TO FLAGID OF DCLTBCTF008

           EXEC SQL
              SELECT FLAGID,
                     CHALLENGEID,
                     FLAGVALUE,
                     CASESENSITIVE,
                     CREATEDBY,
                     CREATEDDATE,
                     UPDATEDBY,
                     UPDATEDDATE
                INTO :DCLTBCTF008.FLAGID,
                     :DCLTBCTF008.CHALLENGEID,
                     :DCLTBCTF008.FLAGVALUE,
                     :DCLTBCTF008.CASESENSITIVE,
                     :DCLTBCTF008.CREATEDBY,
                     :DCLTBCTF008.CREATEDDATE,
                     :DCLTBCTF008.UPDATEDBY,
                     :DCLTBCTF008.UPDATEDDATE
                FROM TBCTF008
               WHERE FLAGID = :DCLTBCTF008.FLAGID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              PERFORM R121-COPY-ROW
           WHEN 100
              MOVE N'04' TO RETURNCODE OF P-LCTFM008
              MOVE N'01' TO REASONCODE OF P-LCTFM008
              MOVE N'Flag not found' TO
                   INFOMESSAGE OF P-LCTFM008
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM008
              MOVE N'21' TO REASONCODE OF P-LCTFM008
              STRING N'SELECT gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM008
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R120-READ-END.
           EXIT.

      *===============================================================*
      * R130-UPDATE: Update the row                                   *
      *===============================================================*
       R130-UPDATE SECTION.
           MOVE FLAGID OF P-LCTFM008 TO FLAGID OF DCLTBCTF008

           EXEC SQL
              UPDATE TBCTF008
                 SET FLAGVALUE     = :DCLTBCTF008.FLAGVALUE,
                     CASESENSITIVE = :DCLTBCTF008.CASESENSITIVE,
                     UPDATEDBY   = :W-USERID,
                     UPDATEDDATE = CURRENT TIMESTAMP
               WHERE FLAGID = :DCLTBCTF008.FLAGID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              CONTINUE
           WHEN 100
              MOVE N'08' TO RETURNCODE OF P-LCTFM008
              MOVE N'31' TO REASONCODE OF P-LCTFM008
              MOVE N'Flag not found' TO
                   INFOMESSAGE OF P-LCTFM008
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM008
              MOVE N'32' TO REASONCODE OF P-LCTFM008
              STRING N'UPDATE gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM008
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R130-UPDATE-END.
           EXIT.

      *===============================================================*
      * R140-DELETE: Delete the row                                   *
      *===============================================================*
       R140-DELETE SECTION.
           MOVE FLAGID OF P-LCTFM008 TO FLAGID OF DCLTBCTF008

           EXEC SQL
              SELECT CHALLENGEID
                INTO :DCLTBCTF008.CHALLENGEID
                FROM TBCTF008
               WHERE FLAGID = :DCLTBCTF008.FLAGID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              CONTINUE
           WHEN 100
              MOVE N'08' TO RETURNCODE OF P-LCTFM008
              MOVE N'41' TO REASONCODE OF P-LCTFM008
              MOVE N'Flag not found' TO
                   INFOMESSAGE OF P-LCTFM008
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM008
              MOVE N'21' TO REASONCODE OF P-LCTFM008
              STRING N'SELECT gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM008
              PERFORM R900-DSNTIAR
           END-EVALUATE

           IF RETURNCODE OF P-LCTFM008 = N'00'
              EXEC SQL
                 SELECT 1
                   INTO :W-ONE
                   FROM TBCTF011 EC
                  WHERE EC.CHALLENGEID = :DCLTBCTF008.CHALLENGEID
                    AND EC.ISVISIBLE = :C-Y
                    AND NOT EXISTS
                       (SELECT 1
                          FROM TBCTF008 F
                         WHERE F.CHALLENGEID = EC.CHALLENGEID
                           AND F.FLAGID <> :DCLTBCTF008.FLAGID)
                  FETCH FIRST 1 ROW ONLY
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 MOVE N'08' TO RETURNCODE OF P-LCTFM008
                 MOVE N'53' TO REASONCODE OF P-LCTFM008
                 STRING N'The last flag of a challenge visible in an '
                        N'event'
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM008
              WHEN 100
                 CONTINUE
              WHEN OTHER
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM008
                 MOVE N'21' TO REASONCODE OF P-LCTFM008
                 STRING N'SELECT gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM008
                 PERFORM R900-DSNTIAR
              END-EVALUATE
           END-IF

           IF RETURNCODE OF P-LCTFM008 = N'00'
              EXEC SQL
                 DELETE FROM TBCTF008
                  WHERE FLAGID = :DCLTBCTF008.FLAGID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 MOVE N'08' TO RETURNCODE OF P-LCTFM008
                 MOVE N'41' TO REASONCODE OF P-LCTFM008
                 MOVE N'Flag not found' TO
                      INFOMESSAGE OF P-LCTFM008
              WHEN -532
                 MOVE N'08' TO RETURNCODE OF P-LCTFM008
                 MOVE N'53' TO REASONCODE OF P-LCTFM008
                 MOVE N'Other rows still refer to this one' TO
                      INFOMESSAGE OF P-LCTFM008
              WHEN OTHER
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM008
                 MOVE N'42' TO REASONCODE OF P-LCTFM008
                 STRING N'DELETE gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM008
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
           MOVE FLAGID OF DCLTBCTF008 TO FLAGID OF P-LCTFM008
           MOVE CHALLENGEID OF DCLTBCTF008 TO CHALLENGEID OF P-LCTFM008
           MOVE FLAGVALUE OF DCLTBCTF008 TO FLAGVALUE OF P-LCTFM008
           MOVE CASESENSITIVE OF DCLTBCTF008 TO
                CASESENSITIVE OF P-LCTFM008
           MOVE CREATEDBY OF DCLTBCTF008 TO CREATEDBY OF P-LCTFM008
           MOVE CREATEDDATE OF DCLTBCTF008 TO CREATEDDATE OF P-LCTFM008
           MOVE UPDATEDBY OF DCLTBCTF008 TO UPDATEDBY OF P-LCTFM008
           MOVE UPDATEDDATE OF DCLTBCTF008 TO UPDATEDDATE OF P-LCTFM008
           .
       R121-COPY-ROW-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM008==.

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

       END PROGRAM CTFM008.
