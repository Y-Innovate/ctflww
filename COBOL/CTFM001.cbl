       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM001.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * POST, PUT and DELETE /admin/refTables: create, read, update or*
      * delete a reference entry, by OPCODE C, R, U or D. Table ID and*
      * key are upper case. A SETTINGS value is required and must fit *
      * the field CTFM910 reads it into; CLAIMHRS and JOBMINS must be *
      * numbers. SETTINGS keys cannot be deleted; nor can a CATEGORY  *
      * key a challenge uses or a RACFGRP key an event uses. The      *
      * caller (the admin wrapper) has checked CTF.ADMIN, and commits *
      * or rolls back.                                                *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Entry not found                                       *
      * 08 01 = Error: invalid OPCODE                                 *
      * 08 02 = Error: table ID, key or value missing or too long, or *
      *         a SETTINGS value missing or too long for its field    *
      * 08 03 = Error: CLAIMHRS or JOBMINS is not a number            *
      * 08 11 = Error: the entry exists already                       *
      * 08 12/21/32/42 = Error: SQL error                             *
      * 08 31/41 = Error: update or delete of a missing entry         *
      * 08 53 = Error: in use, or a SETTINGS key                      *
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

           EXEC SQL INCLUDE TBCTF001 END-EXEC.

       01 WORK.
          05 W-SQLCODE    PIC -99999.
          05 W-ONE        PIC S9(9) COMP-5.
          05 W-COUNT      PIC S9(9) COMP-5.
          05 C-RACFGRP    PIC N(8) VALUE N'RACFGRP'.
          05 W-BLANK8     PIC N(8) VALUE SPACES.
          05 W-MAXLEN     PIC S9(4) COMP-5.
          05 W-MAXLEN-D   PIC ZZ9.

           COPY CTFCTXW.

       01 ERROR-MESSAGE.
          05 ERROR-LEN    PIC S9(4) COMP
                                     VALUE +720.
          05 ERROR-TEXT   PIC X(72) OCCURS 10 TIMES
                INDEXED BY ERROR-INDEX.
       77 ERROR-TEXT-LEN  PIC S9(9) COMP
                                     VALUE +72.

       LINKAGE SECTION.
       01 P-LCTFM001.
           COPY LCTFM001.

       PROCEDURE DIVISION USING P-LCTFM001.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R002-CHECKPARM

           PERFORM R090-GET-USERID

           IF RETURNCODE OF P-LCTFM001 = N'00'
              EVALUATE OPCODE OF P-LCTFM001
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
           IF RETURNCODE OF P-LCTFM001 = N'00'
           AND (OPCODE OF P-LCTFM001 = N'C'
             OR OPCODE OF P-LCTFM001 = N'U')
              PERFORM R120-READ
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM001
           MOVE N'00' TO REASONCODE OF P-LCTFM001
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM001
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R002-CHECKPARM: Check the input                               *
      *===============================================================*
       R002-CHECKPARM SECTION.
           IF OPCODE OF P-LCTFM001 NOT = N'C'
             AND OPCODE OF P-LCTFM001 NOT = N'R'
             AND OPCODE OF P-LCTFM001 NOT = N'U'
             AND OPCODE OF P-LCTFM001 NOT = N'D'
              MOVE N'08' TO RETURNCODE OF P-LCTFM001
              MOVE N'01' TO REASONCODE OF P-LCTFM001
              MOVE N'Invalid OPCODE' TO
                   INFOMESSAGE OF P-LCTFM001
           END-IF

           INSPECT TABLEID OF P-LCTFM001
                   REPLACING ALL NX'0000' BY N' '
           MOVE FUNCTION UPPER-CASE(TABLEID OF P-LCTFM001)
             TO TABLEID OF P-LCTFM001
           INSPECT TABKEY OF P-LCTFM001
                   REPLACING ALL NX'0000' BY N' '
           MOVE FUNCTION UPPER-CASE(TABKEY OF P-LCTFM001)
             TO TABKEY OF P-LCTFM001

           IF RETURNCODE OF P-LCTFM001 = N'00'
           AND (TABLEID OF P-LCTFM001 = SPACES
             OR TABKEY OF P-LCTFM001 = SPACES)
              MOVE N'08' TO RETURNCODE OF P-LCTFM001
              MOVE N'02' TO REASONCODE OF P-LCTFM001
              MOVE N'tableID and tabKey are required' TO
                   INFOMESSAGE OF P-LCTFM001
           END-IF

           IF RETURNCODE OF P-LCTFM001 = N'00'
           AND (OPCODE OF P-LCTFM001 = N'C'
             OR OPCODE OF P-LCTFM001 = N'U')
              PERFORM R020-CHECK-FIELDS
           END-IF
           .
       R002-CHECKPARM-END.
           EXIT.

      *===============================================================*
      * R020-CHECK-FIELDS: Check the fields of C and U                *
      *===============================================================*
       R020-CHECK-FIELDS SECTION.
           IF RETURNCODE OF P-LCTFM001 = N'00'
           AND (TABVALUE-LEN OF P-LCTFM001 < 0
             OR TABVALUE-LEN OF P-LCTFM001 > 255)
              MOVE N'08' TO RETURNCODE OF P-LCTFM001
              MOVE N'02' TO REASONCODE OF P-LCTFM001
              MOVE N'tabValue has up to 255 characters' TO
                   INFOMESSAGE OF P-LCTFM001
           END-IF

           IF RETURNCODE OF P-LCTFM001 = N'00'
           AND TABLEID OF P-LCTFM001 = C-SETTINGS
              PERFORM R025-CHECK-SETTING
           END-IF
           .
       R020-CHECK-FIELDS-END.
           EXIT.

      *===============================================================*
      * R025-CHECK-SETTING: A SETTINGS value is required and must fit *
      * the field CTFM910 reads it into (LCTFC910); CLAIMHRS and      *
      * JOBMINS are numbers. Other keys take up to 255 characters.    *
      *===============================================================*
       R025-CHECK-SETTING SECTION.
           EVALUATE TABKEY OF P-LCTFM001
           WHEN N'JOBCLASS'
           WHEN N'MSGCLASS'
              MOVE 1 TO W-MAXLEN
           WHEN N'DB2SSID '
           WHEN N'SUBMTXN '
           WHEN N'CLAIMHRS'
              MOVE 4 TO W-MAXLEN
           WHEN N'BATCHUSR'
           WHEN N'PLAYGRP '
           WHEN N'CTFPLAN '
           WHEN N'SUBMUSR '
              MOVE 8 TO W-MAXLEN
           WHEN N'DB2HLQ  '
           WHEN N'DB2SSHLQ'
              MOVE 20 TO W-MAXLEN
           WHEN N'LOADLIB '
              MOVE 44 TO W-MAXLEN
           WHEN OTHER
              MOVE 255 TO W-MAXLEN
           END-EVALUATE

           IF TABVALUE-LEN OF P-LCTFM001 = 0
              MOVE N'08' TO RETURNCODE OF P-LCTFM001
              MOVE N'02' TO REASONCODE OF P-LCTFM001
              MOVE N'A setting needs a value' TO
                   INFOMESSAGE OF P-LCTFM001
           ELSE
              IF TABVALUE-TEXT OF P-LCTFM001
                    (1:TABVALUE-LEN OF P-LCTFM001) = SPACES
                 MOVE N'08' TO RETURNCODE OF P-LCTFM001
                 MOVE N'02' TO REASONCODE OF P-LCTFM001
                 MOVE N'A setting needs a value' TO
                      INFOMESSAGE OF P-LCTFM001
              END-IF
           END-IF

           IF RETURNCODE OF P-LCTFM001 = N'00'
           AND TABVALUE-LEN OF P-LCTFM001 > W-MAXLEN
              MOVE W-MAXLEN TO W-MAXLEN-D
              MOVE N'08' TO RETURNCODE OF P-LCTFM001
              MOVE N'02' TO REASONCODE OF P-LCTFM001
              MOVE SPACES TO INFOMESSAGE OF P-LCTFM001
              STRING N'This setting has up to '
                     FUNCTION NATIONAL-OF(FUNCTION TRIM(W-MAXLEN-D))
                     N' characters'
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM001
           END-IF

           IF RETURNCODE OF P-LCTFM001 = N'00'
           AND (TABKEY OF P-LCTFM001 = N'CLAIMHRS'
             OR TABKEY OF P-LCTFM001 = N'JOBMINS ')
              IF FUNCTION TEST-NUMVAL(TABVALUE-TEXT OF P-LCTFM001
                    (1:TABVALUE-LEN OF P-LCTFM001)) NOT = 0
                 MOVE N'08' TO RETURNCODE OF P-LCTFM001
                 MOVE N'03' TO REASONCODE OF P-LCTFM001
                 MOVE N'This setting needs a number as its value' TO
                      INFOMESSAGE OF P-LCTFM001
              END-IF
           END-IF
           .
       R025-CHECK-SETTING-END.
           EXIT.

      *===============================================================*
      * R110-CREATE: Insert the row                                   *
      *===============================================================*
       R110-CREATE SECTION.
           MOVE TABLEID OF P-LCTFM001 TO TABLEID OF DCLTBCTF001
           MOVE TABKEY OF P-LCTFM001 TO TABKEY OF DCLTBCTF001
           MOVE TABVALUE OF P-LCTFM001 TO TABVALUE OF DCLTBCTF001
           IF TABVALUE-LEN OF P-LCTFM001 = 0
              MOVE -1 TO TABVALUE-IND OF DCLTBCTF001
           ELSE
              MOVE 0 TO TABVALUE-IND OF DCLTBCTF001
           END-IF

           EXEC SQL
              INSERT
                INTO TBCTF001
                     (TABLEID,
                      TABKEY,
                      TABVALUE,
                      CREATEDBY,
                      CREATEDDATE,
                      UPDATEDBY,
                      UPDATEDDATE)
              VALUES(:DCLTBCTF001.TABLEID,
                     :DCLTBCTF001.TABKEY,
                     :DCLTBCTF001.TABVALUE :DCLTBCTF001.TABVALUE-IND,
                     :W-USERID,
                     CURRENT TIMESTAMP,
                     :W-USERID,
                     CURRENT TIMESTAMP)
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              CONTINUE
           WHEN -803
              MOVE N'08' TO RETURNCODE OF P-LCTFM001
              MOVE N'11' TO REASONCODE OF P-LCTFM001
              MOVE N'This row exists already' TO
                   INFOMESSAGE OF P-LCTFM001
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM001
              MOVE N'12' TO REASONCODE OF P-LCTFM001
              STRING N'INSERT gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM001
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R110-CREATE-END.
           EXIT.

      *===============================================================*
      * R120-READ: Read the row                                       *
      *===============================================================*
       R120-READ SECTION.
           MOVE TABLEID OF P-LCTFM001 TO TABLEID OF DCLTBCTF001
           MOVE TABKEY OF P-LCTFM001 TO TABKEY OF DCLTBCTF001

           EXEC SQL
              SELECT TABLEID,
                     TABKEY,
                     TABVALUE,
                     CREATEDBY,
                     CREATEDDATE,
                     UPDATEDBY,
                     UPDATEDDATE
                INTO :DCLTBCTF001.TABLEID,
                     :DCLTBCTF001.TABKEY,
                     :DCLTBCTF001.TABVALUE :DCLTBCTF001.TABVALUE-IND,
                     :DCLTBCTF001.CREATEDBY,
                     :DCLTBCTF001.CREATEDDATE,
                     :DCLTBCTF001.UPDATEDBY,
                     :DCLTBCTF001.UPDATEDDATE
                FROM TBCTF001
               WHERE TABLEID = :DCLTBCTF001.TABLEID
                 AND TABKEY  = :DCLTBCTF001.TABKEY
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              PERFORM R121-COPY-ROW
           WHEN 100
              MOVE N'04' TO RETURNCODE OF P-LCTFM001
              MOVE N'01' TO REASONCODE OF P-LCTFM001
              MOVE N'Entry not found' TO
                   INFOMESSAGE OF P-LCTFM001
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM001
              MOVE N'21' TO REASONCODE OF P-LCTFM001
              STRING N'SELECT gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM001
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R120-READ-END.
           EXIT.

      *===============================================================*
      * R130-UPDATE: Update the row                                   *
      *===============================================================*
       R130-UPDATE SECTION.
           MOVE TABLEID OF P-LCTFM001 TO TABLEID OF DCLTBCTF001
           MOVE TABKEY OF P-LCTFM001 TO TABKEY OF DCLTBCTF001
           MOVE TABVALUE OF P-LCTFM001 TO TABVALUE OF DCLTBCTF001
           IF TABVALUE-LEN OF P-LCTFM001 = 0
              MOVE -1 TO TABVALUE-IND OF DCLTBCTF001
           ELSE
              MOVE 0 TO TABVALUE-IND OF DCLTBCTF001
           END-IF

           EXEC SQL
              UPDATE TBCTF001
                 SET TABVALUE    = :DCLTBCTF001.TABVALUE
                    :DCLTBCTF001.TABVALUE-IND,
                     UPDATEDBY   = :W-USERID,
                     UPDATEDDATE = CURRENT TIMESTAMP
               WHERE TABLEID = :DCLTBCTF001.TABLEID
                 AND TABKEY  = :DCLTBCTF001.TABKEY
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              CONTINUE
           WHEN 100
              MOVE N'08' TO RETURNCODE OF P-LCTFM001
              MOVE N'31' TO REASONCODE OF P-LCTFM001
              MOVE N'Entry not found' TO
                   INFOMESSAGE OF P-LCTFM001
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM001
              MOVE N'32' TO REASONCODE OF P-LCTFM001
              STRING N'UPDATE gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM001
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R130-UPDATE-END.
           EXIT.

      *===============================================================*
      * R140-DELETE: Delete the row                                   *
      *===============================================================*
       R140-DELETE SECTION.
           MOVE TABLEID OF P-LCTFM001 TO TABLEID OF DCLTBCTF001
           MOVE TABKEY OF P-LCTFM001 TO TABKEY OF DCLTBCTF001

           IF TABLEID OF P-LCTFM001 = C-SETTINGS
              MOVE N'08' TO RETURNCODE OF P-LCTFM001
              MOVE N'53' TO REASONCODE OF P-LCTFM001
              MOVE N'The programs need every SETTINGS key' TO
                   INFOMESSAGE OF P-LCTFM001
           END-IF

           IF RETURNCODE OF P-LCTFM001 = N'00'
           AND TABLEID OF P-LCTFM001 = C-CATEGORY
              EXEC SQL
                 SELECT 1
                   INTO :W-ONE
                   FROM TBCTF007
                  WHERE CATEGORY = :DCLTBCTF001.TABKEY
                  FETCH FIRST 1 ROW ONLY
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 MOVE N'08' TO RETURNCODE OF P-LCTFM001
                 MOVE N'53' TO REASONCODE OF P-LCTFM001
                 MOVE N'A challenge uses this category' TO
                      INFOMESSAGE OF P-LCTFM001
              WHEN 100
                 CONTINUE
              WHEN OTHER
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM001
                 MOVE N'21' TO REASONCODE OF P-LCTFM001
                 STRING N'SELECT gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM001
                 PERFORM R900-DSNTIAR
              END-EVALUATE
           END-IF

           IF RETURNCODE OF P-LCTFM001 = N'00'
           AND TABLEID OF P-LCTFM001 = C-RACFGRP
              EXEC SQL
                 SELECT 1
                   INTO :W-ONE
                   FROM TBCTF002
                  WHERE RACFGROUP = :DCLTBCTF001.TABKEY
                  FETCH FIRST 1 ROW ONLY
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 MOVE N'08' TO RETURNCODE OF P-LCTFM001
                 MOVE N'53' TO REASONCODE OF P-LCTFM001
                 MOVE N'An event uses this RACF group' TO
                      INFOMESSAGE OF P-LCTFM001
              WHEN 100
                 CONTINUE
              WHEN OTHER
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM001
                 MOVE N'21' TO REASONCODE OF P-LCTFM001
                 STRING N'SELECT gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM001
                 PERFORM R900-DSNTIAR
              END-EVALUATE
           END-IF

           IF RETURNCODE OF P-LCTFM001 = N'00'
              EXEC SQL
                 DELETE FROM TBCTF001
                  WHERE TABLEID = :DCLTBCTF001.TABLEID
                    AND TABKEY  = :DCLTBCTF001.TABKEY
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 MOVE N'08' TO RETURNCODE OF P-LCTFM001
                 MOVE N'41' TO REASONCODE OF P-LCTFM001
                 MOVE N'Entry not found' TO
                      INFOMESSAGE OF P-LCTFM001
              WHEN -532
                 MOVE N'08' TO RETURNCODE OF P-LCTFM001
                 MOVE N'53' TO REASONCODE OF P-LCTFM001
                 MOVE N'Other rows still refer to this one' TO
                      INFOMESSAGE OF P-LCTFM001
              WHEN OTHER
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM001
                 MOVE N'42' TO REASONCODE OF P-LCTFM001
                 STRING N'DELETE gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM001
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
           MOVE TABLEID OF DCLTBCTF001 TO TABLEID OF P-LCTFM001
           MOVE TABKEY OF DCLTBCTF001 TO TABKEY OF P-LCTFM001
           IF TABVALUE-IND OF DCLTBCTF001 < 0
              MOVE 0 TO TABVALUE-LEN OF P-LCTFM001
           ELSE
              MOVE TABVALUE OF DCLTBCTF001 TO TABVALUE OF P-LCTFM001
           END-IF
           MOVE CREATEDBY OF DCLTBCTF001 TO CREATEDBY OF P-LCTFM001
           MOVE CREATEDDATE OF DCLTBCTF001 TO CREATEDDATE OF P-LCTFM001
           MOVE UPDATEDBY OF DCLTBCTF001 TO UPDATEDBY OF P-LCTFM001
           MOVE UPDATEDDATE OF DCLTBCTF001 TO UPDATEDDATE OF P-LCTFM001
           .
       R121-COPY-ROW-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM001==.

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

       END PROGRAM CTFM001.
