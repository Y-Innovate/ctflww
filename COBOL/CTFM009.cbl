       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM009.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * POST, PUT and DELETE /admin/hints: create, read, update or    *
      * delete a hint of a challenge, by OPCODE C, R, U or D. Unlocks *
      * keep the cost they were charged, so the cost may change; a    *
      * hint with unlocks cannot be deleted. The caller (the admin    *
      * wrapper) has checked CTF.ADMIN, and commits or rolls back.    *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Hint not found                                        *
      * 08 01 = Error: invalid OPCODE                                 *
      * 08 02 = Error: text missing or too long                       *
      * 08 04 = Error: cost below 0                                   *
      * 08 12/21/32/42 = Error: SQL error                             *
      * 08 13 = Error: challenge not found                            *
      * 08 31/41 = Error: update or delete of a missing hint          *
      * 08 53 = Error: the hint has unlocks                           *
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

           EXEC SQL INCLUDE TBCTF009 END-EXEC.

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
       01 P-LCTFM009.
           COPY LCTFM009.

       PROCEDURE DIVISION USING P-LCTFM009.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R002-CHECKPARM

           PERFORM R090-GET-USERID

           IF RETURNCODE OF P-LCTFM009 = N'00'
              EVALUATE OPCODE OF P-LCTFM009
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
           IF RETURNCODE OF P-LCTFM009 = N'00'
           AND (OPCODE OF P-LCTFM009 = N'C'
             OR OPCODE OF P-LCTFM009 = N'U')
              PERFORM R120-READ
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM009
           MOVE N'00' TO REASONCODE OF P-LCTFM009
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM009
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R002-CHECKPARM: Check the input                               *
      *===============================================================*
       R002-CHECKPARM SECTION.
           IF OPCODE OF P-LCTFM009 NOT = N'C'
             AND OPCODE OF P-LCTFM009 NOT = N'R'
             AND OPCODE OF P-LCTFM009 NOT = N'U'
             AND OPCODE OF P-LCTFM009 NOT = N'D'
              MOVE N'08' TO RETURNCODE OF P-LCTFM009
              MOVE N'01' TO REASONCODE OF P-LCTFM009
              MOVE N'Invalid OPCODE' TO
                   INFOMESSAGE OF P-LCTFM009
           END-IF

           IF RETURNCODE OF P-LCTFM009 = N'00'
           AND (OPCODE OF P-LCTFM009 = N'C'
             OR OPCODE OF P-LCTFM009 = N'U')
              PERFORM R020-CHECK-FIELDS
           END-IF
           .
       R002-CHECKPARM-END.
           EXIT.

      *===============================================================*
      * R020-CHECK-FIELDS: Check the fields of C and U                *
      *===============================================================*
       R020-CHECK-FIELDS SECTION.
           IF RETURNCODE OF P-LCTFM009 = N'00'
           AND (HINTTEXT-LEN OF P-LCTFM009 < 1
             OR HINTTEXT-LEN OF P-LCTFM009 > 1000)
              MOVE N'08' TO RETURNCODE OF P-LCTFM009
              MOVE N'02' TO REASONCODE OF P-LCTFM009
              MOVE N'hintText is required, up to 1000 characters' TO
                   INFOMESSAGE OF P-LCTFM009
           END-IF

           IF RETURNCODE OF P-LCTFM009 = N'00'
           AND COST OF P-LCTFM009 < 0
              MOVE N'08' TO RETURNCODE OF P-LCTFM009
              MOVE N'04' TO REASONCODE OF P-LCTFM009
              MOVE N'cost must be 0 or more' TO
                   INFOMESSAGE OF P-LCTFM009
           END-IF

           MOVE SORTORDER OF P-LCTFM009 TO SORTORDER OF DCLTBCTF009
           MOVE HINTTEXT OF P-LCTFM009 TO HINTTEXT OF DCLTBCTF009
           MOVE COST OF P-LCTFM009 TO COST OF DCLTBCTF009
           .
       R020-CHECK-FIELDS-END.
           EXIT.

      *===============================================================*
      * R110-CREATE: Insert the row                                   *
      *===============================================================*
       R110-CREATE SECTION.
           MOVE CHALLENGEID OF P-LCTFM009 TO CHALLENGEID OF DCLTBCTF009

           EXEC SQL
              SELECT HINTID
                INTO :DCLTBCTF009.HINTID
                FROM FINAL TABLE
                   (
              INSERT
                INTO TBCTF009
                     (CHALLENGEID,
                     SORTORDER,
                     HINTTEXT,
                     COST,
                      CREATEDBY,
                      CREATEDDATE,
                      UPDATEDBY,
                      UPDATEDDATE)
              VALUES(:DCLTBCTF009.CHALLENGEID,
                     :DCLTBCTF009.SORTORDER,
                     :DCLTBCTF009.HINTTEXT,
                     :DCLTBCTF009.COST,
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
              MOVE N'08' TO RETURNCODE OF P-LCTFM009
              MOVE N'13' TO REASONCODE OF P-LCTFM009
              MOVE N'Challenge not found' TO
                   INFOMESSAGE OF P-LCTFM009
           WHEN -803
              MOVE N'08' TO RETURNCODE OF P-LCTFM009
              MOVE N'11' TO REASONCODE OF P-LCTFM009
              MOVE N'This row exists already' TO
                   INFOMESSAGE OF P-LCTFM009
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM009
              MOVE N'12' TO REASONCODE OF P-LCTFM009
              STRING N'INSERT gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM009
              PERFORM R900-DSNTIAR
           END-EVALUATE

           IF RETURNCODE OF P-LCTFM009 = N'00'
              MOVE HINTID OF DCLTBCTF009 TO HINTID OF P-LCTFM009
           END-IF
           .
       R110-CREATE-END.
           EXIT.

      *===============================================================*
      * R120-READ: Read the row                                       *
      *===============================================================*
       R120-READ SECTION.
           MOVE HINTID OF P-LCTFM009 TO HINTID OF DCLTBCTF009

           EXEC SQL
              SELECT HINTID,
                     CHALLENGEID,
                     SORTORDER,
                     HINTTEXT,
                     COST,
                     CREATEDBY,
                     CREATEDDATE,
                     UPDATEDBY,
                     UPDATEDDATE
                INTO :DCLTBCTF009.HINTID,
                     :DCLTBCTF009.CHALLENGEID,
                     :DCLTBCTF009.SORTORDER,
                     :DCLTBCTF009.HINTTEXT,
                     :DCLTBCTF009.COST,
                     :DCLTBCTF009.CREATEDBY,
                     :DCLTBCTF009.CREATEDDATE,
                     :DCLTBCTF009.UPDATEDBY,
                     :DCLTBCTF009.UPDATEDDATE
                FROM TBCTF009
               WHERE HINTID = :DCLTBCTF009.HINTID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              PERFORM R121-COPY-ROW
           WHEN 100
              MOVE N'04' TO RETURNCODE OF P-LCTFM009
              MOVE N'01' TO REASONCODE OF P-LCTFM009
              MOVE N'Hint not found' TO
                   INFOMESSAGE OF P-LCTFM009
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM009
              MOVE N'21' TO REASONCODE OF P-LCTFM009
              STRING N'SELECT gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM009
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R120-READ-END.
           EXIT.

      *===============================================================*
      * R130-UPDATE: Update the row                                   *
      *===============================================================*
       R130-UPDATE SECTION.
           MOVE HINTID OF P-LCTFM009 TO HINTID OF DCLTBCTF009

           EXEC SQL
              UPDATE TBCTF009
                 SET SORTORDER     = :DCLTBCTF009.SORTORDER,
                     HINTTEXT      = :DCLTBCTF009.HINTTEXT,
                     COST          = :DCLTBCTF009.COST,
                     UPDATEDBY   = :W-USERID,
                     UPDATEDDATE = CURRENT TIMESTAMP
               WHERE HINTID = :DCLTBCTF009.HINTID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              CONTINUE
           WHEN 100
              MOVE N'08' TO RETURNCODE OF P-LCTFM009
              MOVE N'31' TO REASONCODE OF P-LCTFM009
              MOVE N'Hint not found' TO
                   INFOMESSAGE OF P-LCTFM009
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM009
              MOVE N'32' TO REASONCODE OF P-LCTFM009
              STRING N'UPDATE gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM009
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R130-UPDATE-END.
           EXIT.

      *===============================================================*
      * R140-DELETE: Delete the row                                   *
      *===============================================================*
       R140-DELETE SECTION.
           MOVE HINTID OF P-LCTFM009 TO HINTID OF DCLTBCTF009

           EXEC SQL
              SELECT 1
                INTO :W-ONE
                FROM TBCTF015
               WHERE HINTID = :DCLTBCTF009.HINTID
               FETCH FIRST 1 ROW ONLY
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              MOVE N'08' TO RETURNCODE OF P-LCTFM009
              MOVE N'53' TO REASONCODE OF P-LCTFM009
              MOVE N'Teams have unlocked this hint' TO
                   INFOMESSAGE OF P-LCTFM009
           WHEN 100
              CONTINUE
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM009
              MOVE N'21' TO REASONCODE OF P-LCTFM009
              STRING N'SELECT gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM009
              PERFORM R900-DSNTIAR
           END-EVALUATE

           IF RETURNCODE OF P-LCTFM009 = N'00'
              EXEC SQL
                 DELETE FROM TBCTF009
                  WHERE HINTID = :DCLTBCTF009.HINTID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 MOVE N'08' TO RETURNCODE OF P-LCTFM009
                 MOVE N'41' TO REASONCODE OF P-LCTFM009
                 MOVE N'Hint not found' TO
                      INFOMESSAGE OF P-LCTFM009
              WHEN -532
                 MOVE N'08' TO RETURNCODE OF P-LCTFM009
                 MOVE N'53' TO REASONCODE OF P-LCTFM009
                 MOVE N'Other rows still refer to this one' TO
                      INFOMESSAGE OF P-LCTFM009
              WHEN OTHER
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM009
                 MOVE N'42' TO REASONCODE OF P-LCTFM009
                 STRING N'DELETE gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM009
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
           MOVE HINTID OF DCLTBCTF009 TO HINTID OF P-LCTFM009
           MOVE CHALLENGEID OF DCLTBCTF009 TO CHALLENGEID OF P-LCTFM009
           MOVE SORTORDER OF DCLTBCTF009 TO SORTORDER OF P-LCTFM009
           MOVE HINTTEXT OF DCLTBCTF009 TO HINTTEXT OF P-LCTFM009
           MOVE COST OF DCLTBCTF009 TO COST OF P-LCTFM009
           MOVE CREATEDBY OF DCLTBCTF009 TO CREATEDBY OF P-LCTFM009
           MOVE CREATEDDATE OF DCLTBCTF009 TO CREATEDDATE OF P-LCTFM009
           MOVE UPDATEDBY OF DCLTBCTF009 TO UPDATEDBY OF P-LCTFM009
           MOVE UPDATEDDATE OF DCLTBCTF009 TO UPDATEDDATE OF P-LCTFM009
           .
       R121-COPY-ROW-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM009==.

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

       END PROGRAM CTFM009.
